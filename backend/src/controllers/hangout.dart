import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';
import '../../../lib/services/distance_scoring.dart';
import '../../../lib/services/geocoding_service.dart';
import '../../../lib/services/itinerary_ai_service.dart';
import '../../../lib/services/location_utils.dart';
import '../../../lib/services/places_service.dart';
import '../../../lib/services/plan_builder.dart';

/// Handles everything related to planning a hangout:
///   - Creating a hangout plan for a group
///   - Submitting / updating your preferences (incl. starting location)
///   - Viewing everyone's preferences
///   - Generating 3 ranked AI plans, and letting the organizer pick one
class HangoutController {
  final _db = SupabaseClient.admin;
  final _uuid = const Uuid();
  final _geocoder = GeocodingService();
  final _placesService = PlacesService();
  late final _aiService = ItineraryAiService(
    apiKey: Env.geminiApiKey,
    models: Env.geminiModels,
  );

  Router get router {
    final router = Router();
    final auth = requireAuth();

    // ── Hangout plans ──
    router.post('/', Pipeline().addMiddleware(auth).addHandler(_createHangout));
    router.get('/group/<groupId>', Pipeline().addMiddleware(auth).addHandler(_getGroupHangouts));
    router.get('/<hangoutId>', Pipeline().addMiddleware(auth).addHandler(_getHangout));
    router.patch('/<hangoutId>/status', Pipeline().addMiddleware(auth).addHandler(_updateStatus));
    router.delete('/<hangoutId>', Pipeline().addMiddleware(auth).addHandler(_deleteHangout));

    // ── Preferences ──
    router.put('/<hangoutId>/preferences', Pipeline().addMiddleware(auth).addHandler(_submitPreferences));
    router.get('/<hangoutId>/preferences', Pipeline().addMiddleware(auth).addHandler(_getAllPreferences));

    // ── Itinerary (3 plans) ──
    router.get('/<hangoutId>/itinerary', Pipeline().addMiddleware(auth).addHandler(_getItinerary));
    router.post('/<hangoutId>/itinerary/generate', Pipeline().addMiddleware(auth).addHandler(_regenerateItinerary));
    router.post('/<hangoutId>/itinerary/select', Pipeline().addMiddleware(auth).addHandler(_selectPlan));

    return router;
  }

  // ─────────────────────────────────────────
  // POST /
  // ─────────────────────────────────────────

  Future<Response> _createHangout(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final groupId = body['group_id'] as String?;
    if (groupId == null) return _badRequest('group_id is required');

    final membership = await _getMembership(groupId, userId);
    if (membership == null || membership['status'] != 'active') {
      return _forbidden('You must be a group member to create a hangout');
    }

    try {
      final hangout = await _db.insert('hangout_plans', {
        'id': _uuid.v4(),
        'group_id': groupId,
        'created_by': userId,
        'title': body['title'] ?? 'Hangout',
        'status': 'collecting_preferences',
        if (body['planned_for'] != null) 'planned_for': body['planned_for'],
      });

      return Response(201, body: jsonEncode(hangout), headers: _jsonHeader);
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
        filters: {'group_id': 'eq.$groupId', 'order': 'created_at.desc'},
        columns: 'id,title,status,itinerary_status,planned_for,created_by,created_at',
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

    final auth = await _authorizedPlan(hangoutId, userId);
    if (auth.error != null) return auth.error!;
    final plan = auth.plan!;

    try {
      final responseStatus = await _db.select(
        'hangout_response_status',
        filters: {'hangout_plan_id': 'eq.$hangoutId'},
        columns: 'user_id,display_name,avatar_url,has_submitted',
      );

      final submitted = responseStatus.where((r) => r['has_submitted'] == true).length;
      final total = responseStatus.length;

      return _ok({
        ...plan, // includes status + itinerary_status
        'members': responseStatus,
        'response_summary': {
          'submitted': submitted,
          'total': total,
          'waiting_on': total - submitted,
          'all_responded': total > 0 && submitted == total,
        },
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<hangoutId>/itinerary
  //
  // Always 200 for members, so the app can poll:
  // {
  //   "itinerary_status": "idle|generating|ready|failed",
  //   "status": "<hangout status>", "created_by": "...",
  //   "id", "plans": [...], "selected_plan_index": 0|null, ...
  // }
  // ─────────────────────────────────────────

  Future<Response> _getItinerary(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    final auth = await _authorizedPlan(hangoutId, userId);
    if (auth.error != null) return auth.error!;
    final plan = auth.plan!;

    try {
      var itStatus = plan['itinerary_status'] as String? ?? 'idle';

      // A server restart mid-generation would leave "generating" forever.
      if (itStatus == 'generating') {
        final started = DateTime.tryParse(plan['updated_at']?.toString() ?? '');
        if (started != null &&
            DateTime.now().toUtc().difference(started.toUtc()) > const Duration(minutes: 10)) {
          itStatus = 'failed';
          await _setItineraryStatus(hangoutId, 'failed');
        }
      }

      final rows = await _db.select(
        'hangout_itineraries',
        filters: {
          'hangout_plan_id': 'eq.$hangoutId',
          'order': 'generated_at.desc',
          'limit': '1',
        },
      );

      final base = <String, dynamic>{
        'itinerary_status': itStatus,
        'status': plan['status'],
        'created_by': plan['created_by'],
      };

      if (rows.isEmpty) {
        return _ok({...base, 'plans': <dynamic>[], 'selected_plan_index': null});
      }

      final it = rows.first;
      var plans = (it['plans'] as List?) ?? <dynamic>[];

      // Itineraries generated before the 3-plan rework only have stops/summary.
      if (plans.isEmpty && it['stops'] is List) {
        plans = [
          {
            'rank': 1,
            'title': 'Itinerary',
            'theme': 'best_fit',
            'summary': it['summary'] ?? '',
            'stops': it['stops'],
          },
        ];
      }

      return _ok({
        ...base,
        'id': it['id'],
        'plans': plans,
        'selected_plan_index': it['selected_plan_index'],
        'selected_by': it['selected_by'],
        'selected_at': it['selected_at'],
        'generated_at': it['generated_at'],
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // POST /<hangoutId>/itinerary/generate   (organizer only)
  // Re-runs plan generation (retry after a failure, or "give me new plans").
  // ─────────────────────────────────────────

  Future<Response> _regenerateItinerary(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    final auth = await _authorizedPlan(hangoutId, userId);
    if (auth.error != null) return auth.error!;
    final plan = auth.plan!;

    if (plan['created_by'] != userId) {
      return _forbidden('Only the organizer can regenerate plans');
    }

    final status = plan['status'];
    if (status != 'collecting_preferences' && status != 'planning') {
      return _badRequest('Plans can only be regenerated before the hangout is confirmed');
    }

    try {
      final started = await _startGeneration(hangoutId, regenerate: true);
      if (!started) return _conflict('Plans are already being generated');
      return Response(
        202,
        body: jsonEncode({'itinerary_status': 'generating'}),
        headers: _jsonHeader,
      );
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // POST /<hangoutId>/itinerary/select   (organizer only)
  // Body: { "plan_index": 0 }
  // ─────────────────────────────────────────

  Future<Response> _selectPlan(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final index = body['plan_index'];
    if (index is! int) return _badRequest('plan_index must be an integer');

    final auth = await _authorizedPlan(hangoutId, userId);
    if (auth.error != null) return auth.error!;
    final plan = auth.plan!;

    if (plan['created_by'] != userId) {
      return _forbidden('Only the organizer can choose the plan');
    }
    if (plan['status'] == 'completed') {
      return _badRequest('This hangout is already completed');
    }
    if (plan['itinerary_status'] == 'generating') {
      return _conflict('Plans are still being generated');
    }

    try {
      final rows = await _db.select(
        'hangout_itineraries',
        filters: {
          'hangout_plan_id': 'eq.$hangoutId',
          'order': 'generated_at.desc',
          'limit': '1',
        },
      );
      if (rows.isEmpty) return _notFound('No plans generated yet');

      final it = rows.first;
      final plans = it['plans'] as List?;
      if (plans == null || plans.isEmpty) {
        return _badRequest('This itinerary has no selectable plans. Regenerate it first.');
      }
      if (index < 0 || index >= plans.length) {
        return _badRequest('plan_index must be between 0 and ${plans.length - 1}');
      }

      await _db.update(
        'hangout_itineraries',
        {
          'selected_plan_index': index,
          'selected_by': userId,
          'selected_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': 'eq.${it['id']}'},
      );

      await _db.update(
        'hangout_plans',
        {'status': 'confirmed', 'updated_at': DateTime.now().toIso8601String()},
        filters: {'id': 'eq.$hangoutId'},
      );

      return _ok({'status': 'confirmed', 'selected_plan_index': index});
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
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final newStatus = body['status'] as String?;
    const validStatuses = ['collecting_preferences', 'planning', 'confirmed', 'completed'];

    if (newStatus == null || !validStatuses.contains(newStatus)) {
      return _badRequest('status must be one of: ${validStatuses.join(", ")}');
    }

    try {
      final plans = await _db.select('hangout_plans', filters: {'id': 'eq.$hangoutId'}, single: true);
      if (plans.isEmpty) return _notFound('Hangout not found');

      if (plans.first['created_by'] != userId) {
        return _forbidden('Only the organizer can update the hangout status');
      }

      final updated = await _db.update(
        'hangout_plans',
        {'status': newStatus, 'updated_at': DateTime.now().toIso8601String()},
        filters: {'id': 'eq.$hangoutId'},
      );

      return _ok(updated.isNotEmpty ? updated.first : {'status': newStatus});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // DELETE /<hangoutId>
  // ─────────────────────────────────────────

  Future<Response> _deleteHangout(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    try {
      final plans = await _db.select('hangout_plans', filters: {'id': 'eq.$hangoutId'}, single: true);
      if (plans.isEmpty) return _notFound('Hangout not found');

      if (plans.first['created_by'] != userId) {
        return _forbidden('Only the creator can delete this hangout');
      }

      await _db.delete('hangout_plans', filters: {'id': 'eq.$hangoutId'});
      return _ok({'message': 'Hangout deleted'});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // PUT /<hangoutId>/preferences
  //
  // Body:
  // {
  //   "budget_range": 40,
  //   "activity_types": [...], "food_preferences": [...], "notes": "...",
  //   "location_source": "home|school|work|current|manual",
  //   "location_zip": "10001",            // manual only
  //   "location_lat": 40.7, "location_lng": -74.0   // current only
  // }
  // ─────────────────────────────────────────

  Future<Response> _submitPreferences(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final auth = await _authorizedPlan(hangoutId, userId);
    if (auth.error != null) return auth.error!;

    if (auth.plan!['status'] != 'collecting_preferences') {
      return _badRequest('Preferences are locked once planning begins');
    }

    // Resolve where this member is starting from.
    final loc = await _resolveStartLocation(userId, body);
    if (loc.error != null) return _badRequest(loc.error!);

    final prefData = <String, dynamic>{
      'hangout_plan_id': hangoutId,
      'user_id': userId,
      'updated_at': DateTime.now().toIso8601String(),
      'location_source': loc.source,
      'location_zip': loc.zip,
      'location_lat': loc.lat,
      'location_lng': loc.lng,
    };

    const allowedFields = [
      'budget_range',
      'activity_types',
      'food_preferences',
      'max_travel_distance_km',
      'notes',
    ];
    for (final field in allowedFields) {
      if (body.containsKey(field)) prefData[field] = body[field];
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
        filters: {'hangout_plan_id': 'eq.$hangoutId'},
        columns: 'has_submitted',
      );

      final allResponded =
          responseStatus.isNotEmpty && responseStatus.every((r) => r['has_submitted'] == true);

      if (allResponded) {
        final started = await _startGeneration(hangoutId, regenerate: false);
        print(started
            ? 'Everyone submitted for $hangoutId. Plan generation started.'
            : 'Everyone submitted for $hangoutId, but generation was already claimed.');
      }

      return _ok(result);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  /// Turns the client's location choice into coordinates, or an error message.
  Future<_ResolvedLocation> _resolveStartLocation(String userId, Map<String, dynamic> body) async {
    final source = (body['location_source'] as String?) ?? 'home';

    try {
      switch (source) {
        case 'home':
        case 'school':
        case 'work':
          final rows = await _db.select(
            'profile_locations',
            filters: {'user_id': 'eq.$userId', 'label': 'eq.$source'},
            columns: 'zipcode,lat,lng',
          );
          if (rows.isNotEmpty) {
            return _ResolvedLocation.ok(
              source: source,
              zip: rows.first['zipcode'] as String?,
              lat: (rows.first['lat'] as num).toDouble(),
              lng: (rows.first['lng'] as num).toDouble(),
            );
          }

          // Legacy: home ZIP saved on the profile row before profile_locations.
          if (source == 'home') {
            final prof = await _db.select(
              'profiles',
              filters: {'id': 'eq.$userId'},
              columns: 'zipcode,home_lat,home_lng',
            );
            if (prof.isNotEmpty && prof.first['home_lat'] != null && prof.first['home_lng'] != null) {
              return _ResolvedLocation.ok(
                source: 'home',
                zip: prof.first['zipcode'] as String?,
                lat: (prof.first['home_lat'] as num).toDouble(),
                lng: (prof.first['home_lng'] as num).toDouble(),
              );
            }
          }

          return _ResolvedLocation.error(
              "You haven't saved a $source ZIP code yet. Add it in your profile or pick another starting point.");

        case 'manual':
          final zip = GeocodingService.normalizeZip(body['location_zip']?.toString() ?? '');
          if (zip == null) return _ResolvedLocation.error('Enter a valid 5-digit ZIP code.');
          final point = await _geocoder.geocodeZip(zip);
          if (point == null) return _ResolvedLocation.error('Could not find ZIP code $zip.');
          return _ResolvedLocation.ok(source: 'manual', zip: zip, lat: point.lat, lng: point.lng);

        case 'current':
          final lat = body['location_lat'];
          final lng = body['location_lng'];
          if (lat is! num || lng is! num) {
            return _ResolvedLocation.error('Current location was not received. Try again.');
          }
          if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            return _ResolvedLocation.error('Current location looks invalid. Try again.');
          }
          return _ResolvedLocation.ok(
            source: 'current',
            zip: null,
            lat: lat.toDouble(),
            lng: lng.toDouble(),
          );

        default:
          return _ResolvedLocation.error('Unknown location_source "$source".');
      }
    } on SupabaseException catch (e) {
      return _ResolvedLocation.error('Could not look up your location: ${e.body}');
    }
  }

  // ─────────────────────────────────────────
  // GET /<hangoutId>/preferences
  // ─────────────────────────────────────────

  Future<Response> _getAllPreferences(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    final auth = await _authorizedPlan(hangoutId, userId);
    if (auth.error != null) return auth.error!;

    try {
      final preferences = await _db.select(
        'hangout_member_constraints',
        filters: {'hangout_plan_id': 'eq.$hangoutId'},
      );

      return _ok({
        'preferences': preferences,
        'conflicts': _findConflicts(preferences),
        'budget_summary': _budgetSummary(preferences),
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // AI PLAN GENERATION
  // ─────────────────────────────────────────

  /// Atomically claims generation (so two requests can't run it twice) and
  /// kicks it off in the background. Returns false if someone else holds it.
  Future<bool> _startGeneration(String hangoutId, {required bool regenerate}) async {
    final claimed = await _db.update(
      'hangout_plans',
      {
        'itinerary_status': 'generating',
        'updated_at': DateTime.now().toIso8601String(),
      },
      filters: {
        'id': 'eq.$hangoutId',
        'status': regenerate ? 'in.(collecting_preferences,planning)' : 'eq.collecting_preferences',
        'itinerary_status': regenerate ? 'in.(idle,ready,failed)' : 'in.(idle,failed)',
      },
    );

    if (claimed.isEmpty) return false;

    unawaited(_runGeneration(hangoutId));
    return true;
  }

  Future<void> _runGeneration(String hangoutId) async {
    try {
      final planRows = await _db.select('hangout_plans', filters: {'id': 'eq.$hangoutId'}, single: true);
      final plan = planRows.first;

      // ── Member constraints (view exposes resolved_lat/lng) ──
      final constraints = await _db.select(
        'hangout_member_constraints',
        filters: {'hangout_plan_id': 'eq.$hangoutId'},
      );
      if (constraints.isEmpty) throw StateError('No member preferences submitted yet');

      // ── Where is everyone starting from? ──
      final members = <MemberTravel>[];
      for (final c in constraints) {
        final lat = (c['resolved_lat'] ?? c['home_lat']) as num?;
        final lng = (c['resolved_lng'] ?? c['home_lng']) as num?;
        final name = c['display_name'] as String? ?? 'Member';

        if (lat == null || lng == null) {
          print('Skipping $name for $hangoutId: no starting location.');
          continue;
        }

        final source = c['location_source'] as String?;
        if (source == null) {
          print('$name has no chosen start for $hangoutId; falling back to home.');
        }

        members.add(
          MemberTravel(
            userId: c['user_id'] as String,
            displayName: name,
            home: LatLng(lat.toDouble(), lng.toDouble()),
            maxKm: (c['max_travel_distance_km'] as num?)?.toDouble() ?? 10.0,
            source: source ?? 'home',
          ),
        );
      }
      if (members.isEmpty) throw StateError('No member has a usable starting location');

      final center = centroidOf(members.map((m) => m.home).toList());

      // Plans stay inside one ~1.5 km neighbourhood, so there is no need to
      // search a whole metro area. Cover the spread of the group plus a margin,
      // never more than a member's travel limit, and cap it (Overpass gets very
      // slow in dense cities: 27 km took ~8 minutes).
      final spreadKm = members.map((m) => haversineKm(center, m.home)).reduce(math.max);
      final widest = members.map((m) => m.maxKm).reduce(math.max);
      final radiusKm = math.max(4.0, math.min(10.0, math.min(widest, spreadKm + 4.0)));

      // ── Collect activity + food preferences ──
      final activityTypes = <String>[];
      final foodPreferences = <String>[];
      for (final c in constraints) {
        for (final a in (c['activity_types'] as List? ?? [])) {
          final v = a.toString();
          if (!activityTypes.contains(v)) activityTypes.add(v);
        }
        for (final f in (c['food_preferences'] as List? ?? [])) {
          final v = f.toString();
          if (v != 'No Preference' && !foodPreferences.contains(v)) foodPreferences.add(v);
        }
      }

      print('[$hangoutId] searching ${radiusKm.toStringAsFixed(1)} km around '
          '${center.lat},${center.lng} | activities: $activityTypes | food: $foodPreferences');

      // ── Real places via Overpass ──
      // A tighter first pass (2 km, widening only if it came up short) was
      // tried and reverted: Overpass time turned out to be queue wait on the
      // shared public endpoint rather than area scanning, so 2 km cost the same
      // ~40s as 4 km and merely added a second wait whenever it had to widen.
      Future<List<PlaceCandidate>> search(double km) => _placesService.searchArea(
            center: center,
            radiusKm: km,
            activityTypes: activityTypes,
            foodPreferences: foodPreferences,
          );

      var rawPlaces = await search(radiusKm);

      if (rawPlaces.isEmpty && radiusKm < 20) {
        final widerKm = math.min(20.0, radiusKm * 2);
        print('[$hangoutId] no places; retrying at ${widerKm.toStringAsFixed(1)} km');
        rawPlaces = await search(widerKm);
      }
      if (rawPlaces.isEmpty) throw StateError('No real places found near the group');
      print('[$hangoutId] using ${rawPlaces.length} place(s)');

      // ── Score + pick up to 3 neighbourhoods ──
      final scored = scorePlaces(places: rawPlaces, members: members);
      // Keep Gemini's input focused: up to 20 verified places per area
      // (food, dessert, and activities), instead of the default 30.
      // With up to 3 areas, Gemini receives at most 60 candidate places.
      final areas = selectCandidateAreas(
        scoredPlaces: scored,
        foodPerArea: 8,
        dessertPerArea: 6,
        activityPerArea: 6,
      );
      if (areas.isEmpty) throw StateError('No candidate areas available');

      print('[$hangoutId] ${scored.length} places scored -> ${areas.length} area(s): '
          '${areas.map((a) => '${a.id}(${a.places.length})').join(', ')}');

      final budgets = constraints
          .map((c) => c['budget_range'])
          .whereType<num>()
          .map((n) => n.toDouble())
          .toList();
      final lowestBudget = budgets.isEmpty ? null : budgets.reduce(math.min);
      final plannedFor = _clockString(plan['planned_for']);

      // ── Ask Gemini, validate server-side, retry once if < 3 survive ──
      var rawPlans = await _aiService.generatePlans(
        hangoutTitle: plan['title'] as String? ?? 'Hangout',
        plannedFor: plannedFor,
        memberConstraints: constraints,
        areas: areas,
      );

      var built = buildValidatedPlans(
        rawPlans: rawPlans,
        areas: areas,
        members: members,
        lowestBudget: lowestBudget,
      );

      if (built.plans.length < 3) {
        print('[$hangoutId] only ${built.plans.length} valid plan(s); retrying once.');
        try {
          final feedback = [
            'Only ${built.plans.length} of your plans were valid. I need 3 different plans.',
            ...built.problems.take(8),
          ].join('\n');

          final retryPlans = await _aiService.generatePlans(
            hangoutTitle: plan['title'] as String? ?? 'Hangout',
            plannedFor: plannedFor,
            memberConstraints: constraints,
            areas: areas,
            retryFeedback: feedback,
          );

          rawPlans = [...rawPlans, ...retryPlans];
          built = buildValidatedPlans(
            rawPlans: rawPlans,
            areas: areas,
            members: members,
            lowestBudget: lowestBudget,
          );
        } catch (e) {
          print('[$hangoutId] retry failed: $e (keeping first-pass plans)');
        }
      }

      if (built.plans.isEmpty) {
        throw StateError('No valid plans after validation: ${built.problems.join(' | ')}');
      }

      // ── Save ──
      // stops/summary mirror plan #1 so older clients still render something.
      final best = built.plans.first;
      await _db.insert('hangout_itineraries', {
        'id': _uuid.v4(),
        'hangout_plan_id': hangoutId,
        'plans': built.plans,
        'summary': best['summary'],
        'stops': best['stops'],
      });

      await _db.update(
        'hangout_plans',
        {
          // Regeneration keeps the current status; first run moves on to planning.
          'status': plan['status'] == 'collecting_preferences' ? 'planning' : plan['status'],
          'itinerary_status': 'ready',
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': 'eq.$hangoutId'},
      );


      print('[$hangoutId] saved ${built.plans.length} plan(s): '
          '${built.plans.map((p) => '"${p['title']}"').join(', ')}');
    } catch (e, stackTrace) {
      print('Error generating plans for $hangoutId: $e');
      print(stackTrace);
      await _setItineraryStatus(hangoutId, 'failed');
    }
  }

  Future<void> _setItineraryStatus(String hangoutId, String status) async {
    try {
      await _db.update(
        'hangout_plans',
        {'itinerary_status': status, 'updated_at': DateTime.now().toIso8601String()},
        filters: {'id': 'eq.$hangoutId'},
      );
    } catch (e) {
      print('Could not set itinerary_status=$status for $hangoutId: $e');
    }
  }

  /// "2026-11-02 18:00". The app sends the picked local time without a UTC
  /// offset and Postgres stores it as-is, so we read the clock time in UTC.
  /// (If you later make the app send real UTC offsets, switch to local here.)
  String? _clockString(Object? iso) {
    final dt = DateTime.tryParse(iso?.toString() ?? '');
    if (dt == null) return null;
    final u = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)}';
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  /// Loads the hangout and verifies the requester is an active group member.
  Future<({Map<String, dynamic>? plan, Response? error})> _authorizedPlan(
    String hangoutId,
    String userId,
  ) async {
    try {
      final plans = await _db.select('hangout_plans', filters: {'id': 'eq.$hangoutId'}, single: true);
      if (plans.isEmpty) return (plan: null, error: _notFound('Hangout not found'));

      final plan = plans.first;
      final membership = await _getMembership(plan['group_id'] as String, userId);
      if (membership == null || membership['status'] != 'active') {
        return (plan: null, error: _forbidden('Not a group member'));
      }
      return (plan: plan, error: null);
    } on SupabaseException catch (e) {
      return (plan: null, error: _serverError(e.body));
    }
  }

  Future<Map<String, dynamic>?> _getMembership(String groupId, String userId) async {
    try {
      final rows = await _db.select(
        'group_members',
        filters: {'group_id': 'eq.$groupId', 'user_id': 'eq.$userId'},
        single: true,
      );
      if (rows.isEmpty) return null;
      return rows.first;
    } on SupabaseException {
      return null;
    }
  }

  /// Flags obvious conflicts in submitted preferences.
  /// (The old availability check was removed: hangout_preferences has no
  /// available_from / available_until columns, so it could never trigger.)
  Map<String, dynamic> _findConflicts(List<Map<String, dynamic>> prefs) {
    final conflicts = <String, dynamic>{};

    final budgets = prefs
        .where((p) => p['budget_range'] != null)
        .map((p) => (p['budget_range'] as num).toDouble())
        .toList();

    if (budgets.length >= 2) {
      final lowest = budgets.reduce(math.min);
      final highest = budgets.reduce(math.max);

      if (highest - lowest >= 50) {
        List<dynamic> namesAt(double v) => prefs
            .where((p) => p['budget_range'] != null && (p['budget_range'] as num).toDouble() == v)
            .map((p) => p['display_name'])
            .toList();

        conflicts['budget'] = {
          'has_conflict': true,
          'message': 'Budget mismatch in the group',
          'low_budget': namesAt(lowest),
          'high_budget': namesAt(highest),
          'lowest_budget': lowest,
          'highest_budget': highest,
        };
      }
    }

    final allRestrictions = prefs
        .expand((p) => (p['dietary_restrictions'] as List? ?? []).cast<String>())
        .toSet()
        .toList();

    if (allRestrictions.isNotEmpty) {
      conflicts['dietary'] = {
        'has_conflict': false,
        'restrictions': allRestrictions,
        'message': 'Venue must accommodate: ${allRestrictions.join(", ")}',
      };
    }

    return conflicts;
  }

  Map<String, dynamic> _budgetSummary(List<Map<String, dynamic>> prefs) {
    final values = prefs
        .where((p) => p['budget_range'] != null)
        .map((p) => (p['budget_range'] as num).toDouble())
        .toList();

    if (values.isEmpty) return {'average': null, 'min': null, 'max': null};

    final avg = values.reduce((a, b) => a + b) / values.length;
    return {
      'average': double.parse(avg.toStringAsFixed(2)),
      'min': values.reduce(math.min),
      'max': values.reduce(math.max),
    };
  }
}

class _ResolvedLocation {
  final String? error;
  final String? source;
  final String? zip;
  final double? lat;
  final double? lng;

  _ResolvedLocation.error(this.error)
      : source = null,
        zip = null,
        lat = null,
        lng = null;

  _ResolvedLocation.ok({
    required this.source,
    required this.zip,
    required this.lat,
    required this.lng,
  }) : error = null;
}

// ─────────────────────────────────────────
// Response helpers
// ─────────────────────────────────────────

const _jsonHeader = {'Content-Type': 'application/json'};

Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);

Response _badRequest(String msg) =>
    Response(400, body: jsonEncode({'error': msg}), headers: _jsonHeader);

Response _forbidden(String msg) =>
    Response.forbidden(jsonEncode({'error': msg}), headers: _jsonHeader);

Response _notFound(String msg) =>
    Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);

Response _conflict(String msg) =>
    Response(409, body: jsonEncode({'error': msg}), headers: _jsonHeader);

Response _serverError(String msg) =>
    Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);