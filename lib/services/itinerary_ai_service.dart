import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'distance_scoring.dart';

/// Asks Gemini for up to 3 different plans built ONLY from verified places.
/// The API key and model are injected (the backend passes Env values), so this
/// file no longer depends on the Flutter app's AppConfig.
class ItineraryAiService {
  static const _defaultModels = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
  ];

  final String apiKey;

  /// Tried in order. On a bad model name (404), quota (429), overload (503)
  /// or timeout we move to the next model immediately.
  final List<String> models;

  ItineraryAiService({
    required this.apiKey,
    List<String>? models,
  }) : models = models ?? _defaultModels;

  /// Returns the RAW plans from Gemini. They are NOT trusted yet —
  /// run them through buildValidatedPlans().
  Future<List<Map<String, dynamic>>> generatePlans({
    required String hangoutTitle,
    String? plannedFor,
    required List<Map<String, dynamic>> memberConstraints,
    required List<CandidateArea> areas,
    String? retryFeedback,
  }) async {
    final prompt = _buildPrompt(
      title: hangoutTitle,
      plannedFor: plannedFor,
      constraints: memberConstraints,
      areas: areas,
      retryFeedback: retryFeedback,
    );

    final errors = <String>[];

    for (final model in models) {
      // Key goes in a header so it never ends up in URLs or exception text.
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );

      for (var attempt = 0; attempt <= 1; attempt++) {
        try {
          final res = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': apiKey,
                },
                body: jsonEncode({
                  'contents': [
                    {
                      'role': 'user',
                      'parts': [
                        {'text': prompt},
                      ],
                    },
                  ],
                  'generationConfig': {
                    'temperature': retryFeedback == null ? 0.7 : 0.4,
                    'responseMimeType': 'application/json',
                    'responseSchema': _responseSchema,
                  },
                }),
              )
              .timeout(const Duration(seconds: 45));

          if (res.statusCode < 400) {
            print('Gemini model used: $model');
            return _parsePlans(res.body);
          }

          if (res.statusCode == 404 || res.statusCode == 429 || res.statusCode == 503) {
            final msg = '$model rejected (${res.statusCode}); trying next model';
            print(msg);
            errors.add(msg);
            break;
          }

          if (attempt == 1) {
            final msg = '$model failed (${res.statusCode}): ${res.body}';
            print(msg);
            errors.add(msg);
            break;
          }
          await Future.delayed(const Duration(seconds: 2));
        } on TimeoutException {
          final msg = '$model timed out; trying next model';
          print(msg);
          errors.add(msg);
          break;
        } catch (e) {
          final msg = '$model error: $e; trying next model';
          print(msg);
          errors.add(msg);
          break;
        }
      }
    }

    throw ItineraryAiException('All Gemini models failed:\n${errors.join('\n')}');
  }

  List<Map<String, dynamic>> _parsePlans(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw ItineraryAiException('Gemini returned no candidates');
    }

    final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List? ?? [];
    final text = parts.isNotEmpty ? (parts.first as Map<String, dynamic>)['text'] as String? : null;

    if (text == null || text.trim().isEmpty) {
      throw ItineraryAiException('Gemini response had no text content');
    }

    final result = jsonDecode(text);
    if (result is! Map<String, dynamic>) {
      throw ItineraryAiException('Gemini returned an unexpected JSON format');
    }

    final plans = result['plans'];
    if (plans is! List || plans.isEmpty) {
      throw ItineraryAiException('Gemini response did not contain any plans');
    }

    final out = plans.whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList();

    print('Gemini returned ${out.length} plan(s): '
        '${out.map((p) => '"${p['title']}"').join(', ')}');

    return out;
  }

  // ------------------------------------------------------------
  // PROMPT
  // ------------------------------------------------------------

  Map<String, String> _memberNames(List<Map<String, dynamic>> constraints) {
    final names = <String, String>{};
    final used = <String, int>{};
    for (final c in constraints) {
      final id = c['user_id'] as String;
      var name = (c['display_name'] as String?)?.trim();
      if (name == null || name.isEmpty) name = 'Member';
      final n = used[name] = (used[name] ?? 0) + 1;
      names[id] = n == 1 ? name : '$name ($n)';
    }
    return names;
  }

  String _buildPrompt({
    required String title,
    required String? plannedFor,
    required List<Map<String, dynamic>> constraints,
    required List<CandidateArea> areas,
    required String? retryFeedback,
  }) {
    final names = _memberNames(constraints);
    final buf = StringBuffer();

    buf.writeln('You are planning a realistic group hangout called "$title".');
    if (plannedFor != null) {
      buf.writeln('Planned start (local clock time): $plannedFor. '
          'Start the first stop around then and space later stops realistically.');
    }
    buf.writeln();
    buf.writeln('TASK: Build 3 DIFFERENT outing plans for this group, using ONLY the '
        'verified places listed below.');
    buf.writeln();

    // ── Members ──
    buf.writeln('GROUP MEMBERS AND PREFERENCES:');

    final budgets = <double>[];
    for (final p in constraints) {
      final budget = p['budget_range'];
      if (budget is num) budgets.add(budget.toDouble());

      final activities = (p['activity_types'] as List?)?.join(', ');
      final foods = (p['food_preferences'] as List?)?.join(', ');
      final hard = (p['all_dietary_constraints'] as List?)?.join(', ');
      final maxTravel = p['max_travel_distance_km'];
      final notes = p['notes'];
      final start = p['location_source'] ?? 'home';

      buf.writeln('- ${names[p['user_id']]}:');
      buf.writeln('  starting from: $start');
      buf.writeln('  budget per person for the whole outing: '
          '${budget != null ? '\$$budget' : 'not specified'}');
      buf.writeln('  activity preferences: '
          '${activities?.isNotEmpty == true ? activities : 'none specified'}');
      buf.writeln('  food preferences: ${foods?.isNotEmpty == true ? foods : 'none specified'}');
      buf.writeln('  HARD dietary constraints: ${hard?.isNotEmpty == true ? hard : 'none'}');
      buf.writeln('  preferred max travel distance: '
          '${maxTravel != null ? '$maxTravel km' : 'not specified'}');
      if (notes is String && notes.trim().isNotEmpty) buf.writeln('  notes: $notes');
    }

    if (budgets.isNotEmpty) {
      budgets.sort();
      buf.writeln();
      buf.writeln('LOWEST BUDGET IN THE GROUP: \$${budgets.first.toStringAsFixed(0)} per person.');
    }
    buf.writeln();

    // ── Places ──
    buf.writeln('VERIFIED PLACES, GROUPED BY AREA:');
    buf.writeln('Every plan must use ONLY places from this JSON, referenced by their '
        '"place_id". Never invent a place, address or id.');
    buf.writeln('"km_from_each_member" is the distance from each member\'s starting point.');
    buf.writeln();
    buf.writeln(jsonEncode({
      'areas': areas
          .map((a) => {
                'area_id': a.id,
                'places': a.places.map((p) => p.toPromptJson(names: names)).toList(),
              })
          .toList(),
    }));
    buf.writeln();

    // ── Rules ──
    buf.writeln('PLAN RULES:');
    buf.writeln('1. Produce exactly 3 plans (fewer only if truly impossible).');
    buf.writeln('2. Each plan has 2 to 4 stops, ALL from the SAME area_id.');
    buf.writeln('3. Consecutive stops must be close together; avoid back-and-forth travel. '
        'A typical order is food -> dessert/coffee -> activity when those match the group.');
    buf.writeln('4. The plans must be meaningfully different. If there are several areas, '
        'prefer using a different area for each plan. Two plans may share at most ONE stop.');
    buf.writeln('5. Give each plan one "theme" from: best_fit, budget_friendly, '
        'activity_packed, closest. Plan 1 should be best_fit, plan 2 budget_friendly, '
        'and plan 3 activity_packed if the group asked for several activities, '
        'otherwise closest. Do not reuse a theme.');
    buf.writeln('6. Use "km_from_each_member" with each member\'s preferred max distance. '
        'Prefer places within or near everyone\'s range; if impossible, pick the best compromise.');
    buf.writeln();

    // Activities the group asked for besides eating.
    final wanted = <String>{};
    for (final p in constraints) {
      for (final a in (p['activity_types'] as List? ?? const [])) {
        wanted.add(a.toString());
      }
    }
    final doChips = wanted
        .where(const {'Entertainment', 'Outdoors', 'Arts & Culture', 'Shopping'}.contains)
        .toList();

    buf.writeln('MATCHING EVERYONE\'S PICKS:');
    buf.writeln('- Each place lists "activities" (which activity picks it satisfies) and "cuisine".');
    if (doChips.isNotEmpty) {
      buf.writeln('- The group asked for things to DO: ${doChips.join(', ')}. '
          'EVERY plan MUST include at least one stop whose "activities" matches one of these. '
          'Do NOT make food-only or dessert-only plans.');
      buf.writeln('- Across the 3 plans, cover as many of those activities as the places allow.');
    } else {
      buf.writeln('- The group did not ask for non-food activities, so food and dessert plans are fine.');
    }
    buf.writeln('- Serve EVERY member: each plan should include at least one stop matching '
        'each member\'s own activity picks, and where possible one of their cuisines. '
        'If one plan cannot serve everyone, rotate so every member is served by at least one plan.');
    buf.writeln();

    buf.writeln('BUDGET RULES:');
    buf.writeln('- "est_cost_per_person" is your realistic USD estimate for the whole plan.');
    buf.writeln('- Keep it at or under the lowest budget whenever possible, and never make '
        'the lowest-budget member spend most of their budget on one stop.');
    buf.writeln('- "budget_hint" is only a rough signal (OSM has no reliable prices). '
        'Do not assume a place is cheap or expensive beyond what the hint supports.');
    buf.writeln('- The budget_friendly plan should lean on low / free_or_low / low_to_medium places.');
    buf.writeln('- If members want MANY activities, keep food and dessert inexpensive.');
    buf.writeln();

    buf.writeln('ACTIVITY AND DIET RULES:');
    buf.writeln('- Respect the activities and cuisines the group requested; do not add '
        'activities that clearly conflict with their preferences.');
    buf.writeln('- Every HARD dietary constraint must be respected. Do not knowingly pick a '
        'place that conflicts with one.');
    buf.writeln();

    buf.writeln('OUTPUT:');
    buf.writeln('Return JSON only: { "plans": [ { "title", "theme", "summary", "area_id", '
        '"est_cost_per_person", "stops": [ { "type", "place_id", "name", "suggested_time", '
        '"reason" } ] } ] }');
    buf.writeln('- "title": short and fun (e.g. "Slow Brunch + Park Stroll").');
    buf.writeln('- "summary": 1-2 sentences on why this plan fits the group.');
    buf.writeln('- "type": food, dessert, activity, or another fitting category.');
    buf.writeln('- "place_id" and "name" must exactly match the list.');
    buf.writeln('- "suggested_time": a clock time like "6:00 PM".');
    buf.writeln('- "reason": one short sentence on why this stop fits and how it connects '
        'to the neighbouring stops.');

    if (retryFeedback != null && retryFeedback.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('YOUR PREVIOUS ATTEMPT HAD PROBLEMS — FIX THEM:');
      buf.writeln(retryFeedback);
    }

    return buf.toString();
  }

  // ------------------------------------------------------------
  // GEMINI RESPONSE SCHEMA
  // ------------------------------------------------------------

  static final Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'plans': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'theme': {'type': 'STRING'},
            'summary': {'type': 'STRING'},
            'area_id': {'type': 'STRING'},
            'est_cost_per_person': {'type': 'NUMBER'},
            'stops': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'type': {'type': 'STRING'},
                  'place_id': {'type': 'STRING'},
                  'name': {'type': 'STRING'},
                  'suggested_time': {'type': 'STRING'},
                  'reason': {'type': 'STRING'},
                },
                'required': ['type', 'place_id', 'name', 'suggested_time', 'reason'],
              },
            },
          },
          'required': ['title', 'theme', 'summary', 'area_id', 'est_cost_per_person', 'stops'],
        },
      },
    },
    'required': ['plans'],
  };
}

class ItineraryAiException implements Exception {
  final String message;

  ItineraryAiException(this.message);

  @override
  String toString() => message;
}