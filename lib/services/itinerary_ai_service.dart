import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'distance_scoring.dart';

class ItineraryAiService {
  static const _model = 'gemini-3.7-flash';

  Future<Map<String, dynamic>> generate({
    required String hangoutTitle,
    required List<Map<String, dynamic>> memberConstraints,
    required List<ScoredPlace> candidatePlaces,
  }) async {
    final prompt = _buildPrompt(
      hangoutTitle,
      memberConstraints,
      candidatePlaces,
    );

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'
      '?key=${AppConfig.geminiApiKey}',
    );

    const maxRetries = 3;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final res = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
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
                  'temperature': 0.6,
                  'responseMimeType': 'application/json',
                  'responseSchema': _responseSchema,
                },
              }),
            )
            .timeout(
              const Duration(seconds: 60),
            );

        // ----------------------------------------------------------
        // SUCCESS
        // ----------------------------------------------------------

        if (res.statusCode < 400) {
          final decoded =
              jsonDecode(res.body) as Map<String, dynamic>;

          final candidates =
              decoded['candidates'] as List?;

          if (candidates == null || candidates.isEmpty) {
            throw ItineraryAiException(
              'Gemini returned no candidates',
            );
          }

          final firstCandidate =
              candidates.first as Map<String, dynamic>;

          final content =
              firstCandidate['content']
                  as Map<String, dynamic>?;

          final parts =
              content?['parts'] as List? ?? [];

          final text = parts.isNotEmpty
              ? (parts.first as Map<String, dynamic>)['text']
                  as String?
              : null;

          if (text == null || text.trim().isEmpty) {
            throw ItineraryAiException(
              'Gemini response had no text content',
            );
          }

          final result = jsonDecode(text);

          if (result is! Map<String, dynamic>) {
            throw ItineraryAiException(
              'Gemini returned an unexpected JSON format',
            );
          }

          // --------------------------------------------------------
          // VALIDATE GENERATED STOPS
          // --------------------------------------------------------

          final stops = result['stops'];

          if (stops is! List) {
            throw ItineraryAiException(
              'Gemini response did not contain a valid stops list',
            );
          }

          if (stops.isEmpty) {
            throw ItineraryAiException(
              'Gemini generated an itinerary with no stops',
            );
          }

          // --------------------------------------------------------
          // PRINT GENERATED ITINERARY
          // --------------------------------------------------------

          print('');
          print('========== GENERATED ITINERARY ==========');
          print('Summary: ${result['summary']}');
          print('');

          for (var i = 0; i < stops.length; i++) {
            final stop = stops[i];

            if (stop is! Map<String, dynamic>) {
              print('Stop ${i + 1}: invalid stop data');
              continue;
            }

            print('Stop ${i + 1}:');
            print('  Type: ${stop['type']}');
            print('  Name: ${stop['name']}');
            print('  Address: ${stop['address']}');
            print(
              '  Suggested time: '
              '${stop['suggested_time']}',
            );
            print('  Reason: ${stop['reason']}');
            print('');
          }

          print('==========================================');
          print('');

          // IMPORTANT:
          // Return the complete result.
          //
          // This keeps:
          // result['summary']
          // result['stops']
          //
          // available for HangoutController and the Flutter UI.
          return result;
        }

        // ----------------------------------------------------------
        // RETRY TEMPORARY HTTP ERRORS
        // ----------------------------------------------------------

        final shouldRetry =
            res.statusCode == 429 ||
            res.statusCode == 503 ||
            res.statusCode == 504;

        if (!shouldRetry || attempt == maxRetries) {
          throw ItineraryAiException(
            'Gemini request failed '
            '(${res.statusCode}): ${res.body}',
          );
        }

        final delaySeconds = 2 << attempt;

        print(
          'Gemini returned ${res.statusCode}. '
          'Retrying in ${delaySeconds}s '
          '(attempt ${attempt + 1}/$maxRetries)...',
        );

        await Future.delayed(
          Duration(seconds: delaySeconds),
        );
      } on TimeoutException catch (e) {
        if (attempt == maxRetries) {
          throw ItineraryAiException(
            'Gemini request timed out after '
            '${maxRetries + 1} attempts: $e',
          );
        }

        final delaySeconds = 2 << attempt;

        print(
          'Gemini request timed out. '
          'Retrying in ${delaySeconds}s '
          '(attempt ${attempt + 1}/$maxRetries)...',
        );

        await Future.delayed(
          Duration(seconds: delaySeconds),
        );
      }
    }

    throw ItineraryAiException(
      'Gemini request failed after all retry attempts',
    );
  }

  // ------------------------------------------------------------
  // PROMPT
  // ------------------------------------------------------------

  String _buildPrompt(
    String title,
    List<Map<String, dynamic>> constraints,
    List<ScoredPlace> places,
  ) {
    final buf = StringBuffer();

    buf.writeln(
      'You are planning a realistic group hangout called "$title".',
    );

    buf.writeln();

    buf.writeln(
      'Your job is to choose a small number of places from the '
      'verified candidate list and turn them into a coherent outing.',
    );

    buf.writeln();

    // ------------------------------------------------------------
    // MEMBERS
    // ------------------------------------------------------------

    buf.writeln('GROUP MEMBERS AND PREFERENCES:');

    for (final p in constraints) {
      final name =
          p['display_name'] ?? 'A member';

      final budget =
          p['budget_range'];

      final activities =
          (p['activity_types'] as List?)
              ?.join(', ');

      final foods =
          (p['food_preferences'] as List?)
              ?.join(', ');

      final hardConstraints =
          (p['all_dietary_constraints'] as List?)
              ?.join(', ');

      final maxTravel =
          p['max_travel_distance_km'];

      final notes =
          p['notes'];

      buf.writeln('- $name:');

      buf.writeln(
        '  budget per person: '
        '${budget != null ? '\$$budget' : 'not specified'}',
      );

      buf.writeln(
        '  activity preferences: '
        '${activities?.isNotEmpty == true ? activities : 'none specified'}',
      );

      buf.writeln(
        '  food preferences: '
        '${foods?.isNotEmpty == true ? foods : 'none specified'}',
      );

      buf.writeln(
        '  HARD dietary constraints: '
        '${hardConstraints?.isNotEmpty == true ? hardConstraints : 'none'}',
      );

      buf.writeln(
        '  preferred maximum travel distance: '
        '${maxTravel != null ? '$maxTravel km' : 'not specified'}',
      );

      if (notes is String &&
          notes.trim().isNotEmpty) {
        buf.writeln(
          '  notes: $notes',
        );
      }
    }

    buf.writeln();

    // ------------------------------------------------------------
    // REAL PLACES
    // ------------------------------------------------------------

    buf.writeln(
      'VERIFIED REAL PLACES:',
    );

    buf.writeln(
      'You may ONLY choose places from the JSON list below.',
    );

    buf.writeln(
      'Do NOT invent a restaurant, activity, business, address, '
      'or place that is not in this list.',
    );

    buf.writeln();

    buf.writeln(
      'Each place contains:',
    );

    buf.writeln('- name');
    buf.writeln('- category');
    buf.writeln('- budget_hint');
    buf.writeln('- exact address');
    buf.writeln('- exact latitude and longitude');
    buf.writeln('- distance_km_by_member');
    buf.writeln('- group_distance_score');

    buf.writeln();

    buf.writeln(
      'Use distance_km_by_member together with each member\'s '
      'preferred maximum travel distance.',
    );

    buf.writeln(
      'Prefer places that are within or close to everyone\'s '
      'preferred travel distance.',
    );

    buf.writeln(
      'If no place satisfies everyone perfectly, choose the '
      'best reasonable compromise.',
    );

    buf.writeln();

    buf.writeln(
      'Available places:',
    );

    buf.writeln(
      jsonEncode(
        places
            .map((p) => p.toPromptJson())
            .toList(),
      ),
    );

    buf.writeln();

    // ------------------------------------------------------------
    // BUDGET LOGIC
    // ------------------------------------------------------------

    buf.writeln(
      'BUDGET RULES:',
    );

    buf.writeln(
      '1. Consider the lowest practical budget among the group.',
    );

    buf.writeln(
      '2. Do not create an itinerary that requires the lowest-budget '
      'member to spend most of their budget on one stop.',
    );

    buf.writeln(
      '3. If the group has a LOW budget, prefer places with '
      'budget_hint "low", "low_to_medium", or "free_or_low".',
    );

    buf.writeln(
      '4. If the group wants MANY activities, keep food and dessert '
      'relatively inexpensive so more of the budget remains available '
      'for activities.',
    );

    buf.writeln(
      '5. Fast food, cafes, bakeries, ice cream, parks, beaches, '
      'and other inexpensive options are appropriate for '
      'low-budget or activity-heavy outings.',
    );

    buf.writeln(
      '6. If the budget is higher, more expensive restaurant or '
      'activity options may be considered when they match the '
      'group preferences.',
    );

    buf.writeln(
      '7. Do not assume that a place is expensive or cheap unless '
      'the provided budget_hint supports that assumption.',
    );

    buf.writeln(
      '8. The budget_hint is only a general signal because OSM '
      'does not provide reliable prices for every business.',
    );

    buf.writeln();

    // ------------------------------------------------------------
    // ACTIVITY LOGIC
    // ------------------------------------------------------------

    buf.writeln(
      'ACTIVITY RULES:',
    );

    buf.writeln(
      'Respect the activities requested by the group.',
    );

    buf.writeln(
      'If members request MANY activities, prioritize multiple '
      'appropriate activities and keep food inexpensive.',
    );

    buf.writeln(
      'If members request FEWER activities, the itinerary can '
      'spend more time on a meal or one larger activity.',
    );

    buf.writeln(
      'Do not add activities that clearly conflict with the '
      'members\' preferences.',
    );

    buf.writeln();

    // ------------------------------------------------------------
    // GEOGRAPHIC LOGIC
    // ------------------------------------------------------------

    buf.writeln(
      'LOCATION RULES:',
    );

    buf.writeln(
      'The search radius may be large because one member may have '
      'a large maximum travel distance.',
    );

    buf.writeln(
      'DO NOT interpret the large search radius as permission to '
      'spread the itinerary across the entire area.',
    );

    buf.writeln(
      'Keep all selected stops geographically close together.',
    );

    buf.writeln(
      'Minimize travel between consecutive stops.',
    );

    buf.writeln(
      'Ideally create a sequence such as:',
    );

    buf.writeln(
      'food -> nearby dessert/coffee -> nearby activity',
    );

    buf.writeln(
      'when those categories match the group preferences.',
    );

    buf.writeln(
      'Do not choose individually appealing places that are far '
      'apart if a reasonable nearby combination exists.',
    );

    buf.writeln();

    // ------------------------------------------------------------
    // DIETARY RULES
    // ------------------------------------------------------------

    buf.writeln(
      'DIETARY RULES:',
    );

    buf.writeln(
      'Every HARD dietary constraint must be respected.',
    );

    buf.writeln(
      'Do not knowingly recommend a place that conflicts with '
      'a member\'s hard dietary restriction.',
    );

    buf.writeln();

    // ------------------------------------------------------------
    // OUTPUT
    // ------------------------------------------------------------

    buf.writeln(
      'OUTPUT:',
    );

    buf.writeln(
      'Produce 1 to 4 stops.',
    );

    buf.writeln(
      'Every stop MUST be a real place from the verified '
      'candidate list.',
    );

    buf.writeln(
      'Use the EXACT name from the candidate list.',
    );

    buf.writeln(
      'Use the EXACT address from the candidate list.',
    );

    buf.writeln(
      'Do not modify business names or addresses.',
    );

    buf.writeln(
      'Do not invent names, addresses, businesses, or locations.',
    );

    buf.writeln(
      'Give each stop a short reason explaining why it fits the '
      'group and how its location works with the other stops.',
    );

    buf.writeln(
      'Use the "type" field to identify whether each stop is '
      'food, dessert, activity, or another appropriate category.',
    );

    buf.writeln(
      'Include a suggested time for each stop.',
    );

    buf.writeln();

    buf.writeln(
      'The final JSON must contain:',
    );

    buf.writeln('- summary');
    buf.writeln('- stops');

    buf.writeln(
      'Each stop must contain:',
    );

    buf.writeln('- type');
    buf.writeln('- name');
    buf.writeln('- address');
    buf.writeln('- suggested_time');
    buf.writeln('- reason');

    buf.writeln();

    buf.writeln(
      'Return JSON only.',
    );

    return buf.toString();
  }

  // ------------------------------------------------------------
  // GEMINI RESPONSE SCHEMA
  // ------------------------------------------------------------

  static final Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'summary': {
        'type': 'STRING',
      },
      'stops': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'type': {
              'type': 'STRING',
            },
            'name': {
              'type': 'STRING',
            },
            'address': {
              'type': 'STRING',
            },
            'suggested_time': {
              'type': 'STRING',
            },
            'reason': {
              'type': 'STRING',
            },
          },
          'required': [
            'type',
            'name',
            'address',
            'suggested_time',
            'reason',
          ],
        },
      },
    },
    'required': [
      'summary',
      'stops',
    ],
  };
}

class ItineraryAiException implements Exception {
  final String message;

  ItineraryAiException(this.message);

  @override
  String toString() => message;
}

