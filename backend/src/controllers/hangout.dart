import 'dart:convert';
import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';
import '../../../lib/services/itinerary_ai_service.dart';
import '../../../lib/services/location_utils.dart';
import '../../../lib/services/places_service.dart';
import '../../../lib/services/distance_scoring.dart';

/// Handles everything related to planning a hangout:
///   - Creating a hangout plan for a group
///   - Submitting / updating your preferences for that hangout
///   - Viewing everyone's preferences
///   - Generating an AI itinerary
///   - Advancing the plan through its status flow
class HangoutController {
  final _db = SupabaseClient.admin;
  final _uuid = const Uuid();
  final _aiService = ItineraryAiService();
  final _placesService = PlacesService();

  Router get router {
    final router = Router();
    final auth = requireAuth();

    // ── Hangout plans ──────────────────────────────────────────────────

    router.post(
      '/',
      Pipeline().addMiddleware(auth).addHandler(_createHangout),
    );

    router.get(
      '/group/<groupId>',
      Pipeline().addMiddleware(auth).addHandler(_getGroupHangouts),
    );

    router.get(
      '/<hangoutId>',
      Pipeline().addMiddleware(auth).addHandler(_getHangout),
    );

    router.patch(
      '/<hangoutId>/status',
      Pipeline().addMiddleware(auth).addHandler(_updateStatus),
    );

    router.delete(
      '/<hangoutId>',
      Pipeline().addMiddleware(auth).addHandler(_deleteHangout),
    );

    // ── Preferences ────────────────────────────────────────────────────

    router.put(
      '/<hangoutId>/preferences',
      Pipeline().addMiddleware(auth).addHandler(_submitPreferences),
    );

    router.get(
      '/<hangoutId>/preferences',
      Pipeline().addMiddleware(auth).addHandler(_getAllPreferences),
    );

    // ── Itinerary ──────────────────────────────────────────────────────

    router.get(
      '/<hangoutId>/itinerary',
      Pipeline().addMiddleware(auth).addHandler(_getItinerary),
    );

    return router;
  }

  // ─────────────────────────────────────────
  // POST /
  // Creates a new hangout plan.
  // ─────────────────────────────────────────

  Future<Response> _createHangout(Request req) async {
    final userId = req.userId;
    final body =
        jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final groupId = body['group_id'] as String?;

    if (groupId == null) {
      return _badRequest('group_id is required');
    }

    final membership = await _getMembership(groupId, userId);

    if (membership == null || membership['status'] != 'active') {
      return _forbidden(
        'You must be a group member to create a hangout',
      );
    }

    try {
      final hangout = await _db.insert(
        'hangout_plans',
        {
          'id': _uuid.v4(),
          'group_id': groupId,
          'created_by': userId,
          'title': body['title'] ?? 'Hangout',
          'status': 'collecting_preferences',
          if (body['planned_for'] != null)
            'planned_for': body['planned_for'],
        },
      );

      return Response(
        201,
        body: jsonEncode(hangout),
        headers: _jsonHeader,
      );
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /group/<groupId>
  // ─────────────────────────────────────────

  Future<Response> _getGroupHangouts(Request req) async {
    final groupId = req.params['groupId']!;
    final userId = req.userId;

    final membership = await _getMembership(groupId, userId);

    if (membership == null || membership['status'] != 'active') {
      return _forbidden('Not a group member');
    }

    try {
      final hangouts = await _db.select(
        'hangout_plans',
        filters: {
          'group_id': 'eq.$groupId',
          'order': 'created_at.desc',
        },
        columns:
            'id,title,status,planned_for,created_by,created_at',
      );

      return _ok(hangouts);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<hangoutId>
  // ─────────────────────────────────────────

  Future<Response> _getHangout(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );

      if (plans.isEmpty) {
        return _notFound('Hangout not found');
      }

      final plan = plans.first;

      final membership = await _getMembership(
        plan['group_id'] as String,
        userId,
      );

      if (membership == null || membership['status'] != 'active') {
        return _forbidden('Not a group member');
      }

      final responseStatus = await _db.select(
        'hangout_response_status',
        filters: {
          'hangout_plan_id': 'eq.$hangoutId',
        },
        columns:
            'user_id,display_name,avatar_url,has_submitted',
      );

      final submitted = responseStatus
          .where((r) => r['has_submitted'] == true)
          .length;

      final total = responseStatus.length;

      return _ok({
        ...plan,
        'members': responseStatus,
        'response_summary': {
          'submitted': submitted,
          'total': total,
          'waiting_on': total - submitted,
          'all_responded':
              total > 0 && submitted == total,
        },
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<hangoutId>/itinerary
  // ─────────────────────────────────────────

  Future<Response> _getItinerary(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );

      if (plans.isEmpty) {
        return _notFound('Hangout not found');
      }

      final membership = await _getMembership(
        plans.first['group_id'] as String,
        userId,
      );

      if (membership == null || membership['status'] != 'active') {
        return _forbidden('Not a group member');
      }

      final itineraries = await _db.select(
        'hangout_itineraries',
        filters: {
          'hangout_plan_id': 'eq.$hangoutId',
          'order': 'generated_at.desc',
        },
      );

      if (itineraries.isEmpty) {
        return _notFound('No itinerary generated yet');
      }

      return _ok(itineraries.first);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // PATCH /<hangoutId>/status
  // ─────────────────────────────────────────

  Future<Response> _updateStatus(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    final body =
        jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final newStatus = body['status'] as String?;

    const validStatuses = [
      'collecting_preferences',
      'planning',
      'confirmed',
      'completed',
    ];

    if (newStatus == null ||
        !validStatuses.contains(newStatus)) {
      return _badRequest(
        'status must be one of: ${validStatuses.join(", ")}',
      );
    }

    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );

      if (plans.isEmpty) {
        return _notFound('Hangout not found');
      }

      final plan = plans.first;

      if (plan['created_by'] != userId) {
        return _forbidden(
          'Only the organizer can update the hangout status',
        );
      }

      final updated = await _db.update(
        'hangout_plans',
        {
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': 'eq.$hangoutId'},
      );

      return _ok(
        updated.isNotEmpty
            ? updated.first
            : {'status': newStatus},
      );
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // AI ITINERARY GENERATION
  // ─────────────────────────────────────────

  Future<void> _generateItinerary(String hangoutId) async {
    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );

      if (plans.isEmpty) {
        print('Cannot generate itinerary: hangout not found.');
        return;
      }

      final plan = plans.first;

      if (plan['status'] != 'collecting_preferences') {
        print(
          'Skipping itinerary generation for $hangoutId: '
          'status is ${plan['status']}',
        );
        return;
      }

      // ── Get all member constraints ──

      final constraints = await _db.select(
        'hangout_member_constraints',
        filters: {
          'hangout_plan_id': 'eq.$hangoutId',
        },
      );

      if (constraints.isEmpty) {
        print(
          'No member constraints found for $hangoutId',
        );
        return;
      }

      // ── Build member travel information ──

      final members = <MemberTravel>[];

      for (final c in constraints) {
        if (c['home_lat'] == null ||
            c['home_lng'] == null) {
          continue;
        }

        members.add(
          MemberTravel(
            userId: c['user_id'] as String,
            displayName:
                c['display_name'] as String? ?? 'Member',
            home: LatLng(
              (c['home_lat'] as num).toDouble(),
              (c['home_lng'] as num).toDouble(),
            ),
            maxKm:
                (c['max_travel_distance_km'] as num?)
                        ?.toDouble() ??
                    10.0,
          ),
        );
      }

      if (members.isEmpty) {
        print(
          'No member has home coordinates for hangout '
          '$hangoutId. Have members re-save their profile '
          'zipcode.',
        );
        return;
      }

      // ── Calculate group center ──

      final center = centroidOf(
        members.map((m) => m.home).toList(),
      );

      // ── Determine search radius ──
      //
      // Use the largest member travel preference so that
      // someone with a larger allowed radius is not ignored.
      //
      // The radius is capped at 40 km because very large
      // Overpass searches become expensive.

      final widestPreference = members
          .map((m) => m.maxKm)
          .reduce(
            (a, b) => a > b ? a : b,
          );

      final radiusKm =
          (widestPreference * 1.5).clamp(3.0, 40.0);

      print(
        'Searching for places for $hangoutId '
        'within ${radiusKm.toStringAsFixed(1)} km '
        'of group center ${center.lat},${center.lng}',
      );

      // ── Collect activity preferences ──

      final activityTypes = <String>[];
      final foodPreferences = <String>[];

      for (final c in constraints) {
        for (final a
            in (c['activity_types'] as List? ?? [])) {
          final value = a.toString();

          if (!activityTypes.contains(value)) {
            activityTypes.add(value);
          }
        }

        for (final f
            in (c['food_preferences'] as List? ?? [])) {
          final value = f.toString();

          if (value != 'No Preference' &&
              !foodPreferences.contains(value)) {
            foodPreferences.add(value);
          }
        }
      }

      print(
        'Activity preferences: $activityTypes',
      );

      print(
        'Food preferences: $foodPreferences',
      );

      // ── Search real places through Overpass ──

      var rawPlaces = await _placesService.searchArea(
        center: center,
        radiusKm: radiusKm,
        activityTypes: activityTypes,
        foodPreferences: foodPreferences,
      );

      print(
        'Overpass returned ${rawPlaces.length} named places '
        'for $hangoutId '
        '(center ${center.lat},${center.lng}, '
        'radius ${radiusKm.toStringAsFixed(1)}km)',
      );

      // ── If the search failed at a smaller radius,
      // try a wider radius. ──

      if (rawPlaces.isEmpty && radiusKm < 40) {
        final widerKm =
            (radiusKm * 2).clamp(3.0, 40.0);

        print(
          'No places found. Retrying with wider '
          '${widerKm.toStringAsFixed(1)} km radius...',
        );

        rawPlaces = await _placesService.searchArea(
          center: center,
          radiusKm: widerKm,
          activityTypes: activityTypes,
          foodPreferences: foodPreferences,
        );

        print(
          'Wider Overpass search returned '
          '${rawPlaces.length} named places.',
        );
      }

      if (rawPlaces.isEmpty) {
        print(
          'No real places found for hangout $hangoutId. '
          'Skipping AI generation.',
        );
        return;
      }

      // ── Score every place based on member travel distance ──

      final scoredPlaces = scorePlaces(
        places: rawPlaces,
        members: members,
      );

      print(
        'Scored ${scoredPlaces.length} places',
      );

      // ── Select a geographically compact candidate pool ──
      //
      // This gives Gemini a larger set of real places while
      // keeping the candidates concentrated in one area.
      //
      // Target:
      //   20 food
      //   15 dessert
      //   15 activities
      //   = up to 50 candidates

      final topCandidates = selectItineraryCandidates(
        scoredPlaces: scoredPlaces,
        maxCandidates: 50,
      );

      print(
        'Selected ${topCandidates.length} itinerary '
        'candidates from ${scoredPlaces.length} places',
      );

      if (topCandidates.isEmpty) {
        print(
          'No itinerary candidates available for $hangoutId',
        );
        return;
      }

      // ── Ask Gemini to build the itinerary ──

      print(
        'Sending ${topCandidates.length} candidates '
        'to Gemini for $hangoutId...',
      );

      final aiResult = await _aiService.generate(
        hangoutTitle:
            plan['title'] as String? ?? 'Hangout',
        memberConstraints: constraints,
        candidatePlaces: topCandidates,
      );

      // ── Drop anything Gemini invented ──
      //
      // Gemini must choose from the real candidate list.
      // We verify the returned name against the candidate
      // list before saving anything.

      final byName = {
        for (final s in topCandidates)
          s.place.name: s,
      };

      final rawStops =
          (aiResult['stops'] as List? ?? [])
              .whereType<Map>()
              .map(
                (s) => Map<String, dynamic>.from(s),
              )
              .toList();

      final stops = <Map<String, dynamic>>[];

      for (final s in rawStops) {
        final name = s['name']?.toString();

        if (name == null) {
          continue;
        }

        final match = byName[name];

        if (match == null) {
          print(
            'Ignoring Gemini-invented place: $name',
          );
          continue;
        }

        stops.add({
          ...s,
          'name': match.place.name,
          'address': match.place.address,
          'lat': match.place.location.lat,
          'lng': match.place.location.lng,
          'category': match.category,
          'distance_km_by_member':
              match.distanceByMember,
          'group_distance_score': match.score,
        });
      }

      if (stops.isEmpty) {
        print(
          'Gemini returned no valid stops for $hangoutId',
        );
        return;
      }

      // ── Save itinerary ──

      await _db.insert(
        'hangout_itineraries',
        {
          'id': _uuid.v4(),
          'hangout_plan_id': hangoutId,
          'stops': stops,
          'summary': aiResult['summary'],
        },
      );

      // ── Move hangout into planning state ──

      await _db.update(
        'hangout_plans',
        {
          'status': 'planning',
          'updated_at':
              DateTime.now().toIso8601String(),
        },
        filters: {
          'id': 'eq.$hangoutId',
        },
      );

      print(
        'Itinerary generated for $hangoutId: '
        '${aiResult['summary']}',
      );
    } catch (e, stackTrace) {
      print(
        'Error generating itinerary for $hangoutId: $e',
      );
      print(stackTrace);
    }
  }

  // ─────────────────────────────────────────
  // DELETE /<hangoutId>
  // ─────────────────────────────────────────

  Future<Response> _deleteHangout(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );

      if (plans.isEmpty) {
        return _notFound('Hangout not found');
      }

      if (plans.first['created_by'] != userId) {
        return _forbidden(
          'Only the creator can delete this hangout',
        );
      }

      await _db.delete(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
      );

      return _ok({
        'message': 'Hangout deleted',
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // PUT /<hangoutId>/preferences
  // ─────────────────────────────────────────

  Future<Response> _submitPreferences(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    final body =
        jsonDecode(await req.readAsString())
            as Map<String, dynamic>;

    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );

      if (plans.isEmpty) {
        return _notFound('Hangout not found');
      }

      final membership = await _getMembership(
        plans.first['group_id'] as String,
        userId,
      );

      if (membership == null ||
          membership['status'] != 'active') {
        return _forbidden('Not a group member');
      }

      if (plans.first['status'] == 'completed') {
        return _badRequest(
          'Cannot update preferences for a completed hangout',
        );
      }
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }

    final prefData = <String, dynamic>{
      'hangout_plan_id': hangoutId,
      'user_id': userId,
      'updated_at':
          DateTime.now().toIso8601String(),
    };

    const allowedFields = [
      'budget_range',
      'activity_types',
      'food_preferences',
      'available_from',
      'available_until',
      'max_travel_distance_km',
      'notes',
    ];

    for (final field in allowedFields) {
      if (body.containsKey(field)) {
        prefData[field] = body[field];
      }
    }

    try {
      final result = await _db.insert(
        'hangout_preferences',
        prefData,
        upsert: true,
        onConflict: 'hangout_plan_id,user_id',
      );

      // ── Trigger AI once everyone has submitted ──

      final responseStatus = await _db.select(
        'hangout_response_status',
        filters: {
          'hangout_plan_id': 'eq.$hangoutId',
        },
        columns: 'has_submitted',
      );

      final allResponded =
          responseStatus.isNotEmpty &&
          responseStatus.every(
            (r) => r['has_submitted'] == true,
          );

      if (allResponded) {
        print(
          'Everyone has submitted preferences '
          'for $hangoutId. Starting AI generation...',
        );

        unawaited(
          _generateItinerary(hangoutId),
        );
      }

      return _ok(result);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<hangoutId>/preferences
  // ─────────────────────────────────────────

  Future<Response> _getAllPreferences(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );

      if (plans.isEmpty) {
        return _notFound('Hangout not found');
      }

      final membership = await _getMembership(
        plans.first['group_id'] as String,
        userId,
      );

      if (membership == null ||
          membership['status'] != 'active') {
        return _forbidden('Not a group member');
      }

      final preferences = await _db.select(
        'hangout_member_constraints',
        filters: {
          'hangout_plan_id': 'eq.$hangoutId',
        },
      );

      final conflicts =
          _findConflicts(preferences);

      return _ok({
        'preferences': preferences,
        'conflicts': conflicts,
        'budget_summary':
            _budgetSummary(preferences),
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  Future<Map<String, dynamic>?> _getMembership(
    String groupId,
    String userId,
  ) async {
    try {
      final rows = await _db.select(
        'group_members',
        filters: {
          'group_id': 'eq.$groupId',
          'user_id': 'eq.$userId',
        },
        single: true,
      );

      if (rows.isEmpty) {
        return null;
      }

      return rows.first;
    } on SupabaseException {
      return null;
    }
  }

  /// Scans all submitted preferences and flags obvious conflicts.
  Map<String, dynamic> _findConflicts(
    List<Map<String, dynamic>> prefs,
  ) {
    final conflicts = <String, dynamic>{};

    // ── Budget conflict ──

    final budgets = prefs
        .where(
          (p) => p['budget_range'] != null,
        )
        .map(
          (p) => (p['budget_range'] as num)
              .toDouble(),
        )
        .toList();

    if (budgets.length >= 2) {
      final lowest = budgets.reduce(
        (a, b) => a < b ? a : b,
      );

      final highest = budgets.reduce(
        (a, b) => a > b ? a : b,
      );

      if (highest - lowest >= 50) {
        final lowBudgetPeople = prefs
            .where(
              (p) =>
                  p['budget_range'] != null &&
                  (p['budget_range'] as num)
                          .toDouble() ==
                      lowest,
            )
            .map(
              (p) => p['display_name'],
            )
            .toList();

        final highBudgetPeople = prefs
            .where(
              (p) =>
                  p['budget_range'] != null &&
                  (p['budget_range'] as num)
                          .toDouble() ==
                      highest,
            )
            .map(
              (p) => p['display_name'],
            )
            .toList();

        conflicts['budget'] = {
          'has_conflict': true,
          'message':
              'Budget mismatch in the group',
          'low_budget': lowBudgetPeople,
          'high_budget': highBudgetPeople,
          'lowest_budget': lowest,
          'highest_budget': highest,
        };
      }
    }

    // ── Dietary constraints ──

    final allRestrictions = prefs
        .expand(
          (p) =>
              (p['dietary_restrictions'] as List? ??
                      [])
                  .cast<String>(),
        )
        .toSet()
        .toList();

    if (allRestrictions.isNotEmpty) {
      conflicts['dietary'] = {
        'has_conflict': false,
        'restrictions': allRestrictions,
        'message':
            'Venue must accommodate: '
            '${allRestrictions.join(", ")}',
      };
    }

    // ── Availability ──

    final availabilities = prefs
        .where(
          (p) =>
              p['available_from'] != null &&
              p['available_until'] != null,
        )
        .map(
          (p) => (
            from: DateTime.parse(
              p['available_from'] as String,
            ),
            until: DateTime.parse(
              p['available_until'] as String,
            ),
            name:
                p['display_name'] as String,
          ),
        )
        .toList();

    if (availabilities.length > 1) {
      final latestStart =
          availabilities
              .map((a) => a.from)
              .reduce(
                (a, b) =>
                    a.isAfter(b) ? a : b,
              );

      final earliestEnd =
          availabilities
              .map((a) => a.until)
              .reduce(
                (a, b) =>
                    a.isBefore(b) ? a : b,
              );

      if (latestStart.isAfter(earliestEnd)) {
        conflicts['availability'] = {
          'has_conflict': true,
          'message':
              'No common availability window found',
          'suggestion':
              'Ask members to update their available times.',
        };
      } else {
        conflicts['availability'] = {
          'has_conflict': false,
          'overlap_from':
              latestStart.toIso8601String(),
          'overlap_until':
              earliestEnd.toIso8601String(),
        };
      }
    }

    return conflicts;
  }

  /// Summarizes budget values across all submitted preferences.
  Map<String, dynamic> _budgetSummary(
    List<Map<String, dynamic>> prefs,
  ) {
    final values = prefs
        .where(
          (p) => p['budget_range'] != null,
        )
        .map(
          (p) => (p['budget_range'] as num)
              .toDouble(),
        )
        .toList();

    if (values.isEmpty) {
      return {
        'average': null,
        'min': null,
        'max': null,
      };
    }

    final avg =
        values.reduce((a, b) => a + b) /
            values.length;

    return {
      'average':
          double.parse(avg.toStringAsFixed(2)),
      'min': values.reduce(
        (a, b) => a < b ? a : b,
      ),
      'max': values.reduce(
        (a, b) => a > b ? a : b,
      ),
    };
  }
}

// ─────────────────────────────────────────
// Response helpers
// ─────────────────────────────────────────

const _jsonHeader = {
  'Content-Type': 'application/json',
};

Response _ok(dynamic data) {
  return Response.ok(
    jsonEncode(data),
    headers: _jsonHeader,
  );
}

Response _badRequest(String msg) {
  return Response(
    400,
    body: jsonEncode({'error': msg}),
    headers: _jsonHeader,
  );
}

Response _forbidden(String msg) {
  return Response.forbidden(
    jsonEncode({'error': msg}),
    headers: _jsonHeader,
  );
}

Response _notFound(String msg) {
  return Response.notFound(
    jsonEncode({'error': msg}),
    headers: _jsonHeader,
  );
}

Response _serverError(String msg) {
  return Response.internalServerError(
    body: jsonEncode({'error': msg}),
    headers: _jsonHeader,
  );
}