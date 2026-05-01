import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

/// Handles everything related to planning a hangout:
///   - Creating a hangout plan for a group
///   - Submitting / updating your preferences for that hangout
///   - Viewing everyone's preferences (to find overlap)
///   - Advancing the plan through its status flow
class HangoutController {
  final _db = SupabaseClient.admin;
  final _uuid = const Uuid();

  Router get router {
    final router = Router();
    final auth = requireAuth();

    // ── Hangout plans ──────────────────────────────────────────────────
    // POST   /api/hangouts                         create a new hangout plan
    // GET    /api/hangouts/group/<groupId>          list all hangouts for a group
    // GET    /api/hangouts/<hangoutId>              get one plan + response status
    // PATCH  /api/hangouts/<hangoutId>/status       advance the plan status

    router.post('/', Pipeline().addMiddleware(auth).addHandler(_createHangout));
    router.get('/group/<groupId>', Pipeline().addMiddleware(auth).addHandler(_getGroupHangouts));
    router.get('/<hangoutId>', Pipeline().addMiddleware(auth).addHandler(_getHangout));
    router.patch('/<hangoutId>/status', Pipeline().addMiddleware(auth).addHandler(_updateStatus));

    // ── Preferences ────────────────────────────────────────────────────
    // PUT    /api/hangouts/<hangoutId>/preferences  submit or update my preferences
    // GET    /api/hangouts/<hangoutId>/preferences  get all members' preferences

    router.put('/<hangoutId>/preferences', Pipeline().addMiddleware(auth).addHandler(_submitPreferences));
    router.get('/<hangoutId>/preferences', Pipeline().addMiddleware(auth).addHandler(_getAllPreferences));

    return router;
  }

  // ─────────────────────────────────────────
  // POST /
  // Creates a new hangout plan and notifies group members.
  //
  // Body:
  // {
  //   "group_id": "uuid",
  //   "title": "Friday Night Out",       (optional, defaults to "Hangout")
  //   "planned_for": "2025-11-15T19:00"  (optional, can decide later)
  // }
  // ─────────────────────────────────────────
  Future<Response> _createHangout(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final groupId = body['group_id'] as String?;

    if (groupId == null) return _badRequest('group_id is required');

    // Verify user is active member of this group
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

      // TODO: broadcast 'new_hangout' via WebSocket to group members here
      // WebSocketHandler.broadcastToGroup(groupId, 'new_hangout', hangout);

      return Response(201, body: jsonEncode(hangout), headers: _jsonHeader);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /group/<groupId>
  // Lists all hangout plans for a group (most recent first).
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
        columns: 'id,title,status,planned_for,created_by,created_at',
      );
      return _ok(hangouts);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<hangoutId>
  // Returns the hangout plan + who has/hasn't submitted preferences.
  // Uses the hangout_response_status view from the schema.
  // ─────────────────────────────────────────
  Future<Response> _getHangout(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;

    try {
      // Get the plan
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );
      if (plans.isEmpty) return _notFound('Hangout not found');
      final plan = plans.first;

      // Verify membership
      final membership = await _getMembership(plan['group_id'] as String, userId);
      if (membership == null || membership['status'] != 'active') {
        return _forbidden('Not a group member');
      }

      // Get response status (who has/hasn't submitted yet)
      final responseStatus = await _db.select(
        'hangout_response_status',
        filters: {'hangout_plan_id': 'eq.$hangoutId'},
        columns: 'user_id,display_name,avatar_url,has_submitted',
      );

      final submitted = responseStatus.where((r) => r['has_submitted'] == true).length;
      final total = responseStatus.length;

      return _ok({
        ...plan,
        'members': responseStatus,
        'response_summary': {
          'submitted': submitted,
          'total': total,
          'waiting_on': total - submitted,
          'all_responded': submitted == total,
        },
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // PATCH /<hangoutId>/status
  // Advances the hangout through its lifecycle. Only the organizer can do this.
  //
  // Valid transitions:
  //   collecting_preferences → planning
  //   planning               → confirmed
  //   confirmed              → completed
  //
  // Body: { "status": "planning" }
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
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );
      if (plans.isEmpty) return _notFound('Hangout not found');
      final plan = plans.first;

      if (plan['created_by'] != userId) {
        return _forbidden('Only the organizer can update the hangout status');
      }

      final updated = await _db.update(
        'hangout_plans',
        {'status': newStatus, 'updated_at': DateTime.now().toIso8601String()},
        filters: {'id': 'eq.$hangoutId'},
      );

      // TODO: broadcast status change to group via WebSocket
      // WebSocketHandler.broadcastToGroup(plan['group_id'], 'hangout_status_changed', {...});

      return _ok(updated.isNotEmpty ? updated.first : {'status': newStatus});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // PUT /<hangoutId>/preferences
  // Submit or update your preferences for this hangout.
  // Can be called multiple times — last write wins.
  //
  // Body (all optional except the hangout needs to exist):
  // {
  //   "budget_range": "$$",
  //   "activity_types": ["food", "dessert"],
  //   "food_preferences": ["Korean", "Mexican"],
  //   "available_from": "2025-11-15T17:00:00Z",
  //   "available_until": "2025-11-15T23:00:00Z",
  //   "max_travel_distance_km": 3,
  //   "notes": "Anywhere but that Thai place please"
  // }
  // ─────────────────────────────────────────
  Future<Response> _submitPreferences(Request req) async {
    final hangoutId = req.params['hangoutId']!;
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    // Verify the hangout exists and user is a member
    try {
      final plans = await _db.select(
        'hangout_plans',
        filters: {'id': 'eq.$hangoutId'},
        single: true,
      );
      if (plans.isEmpty) return _notFound('Hangout not found');

      final membership = await _getMembership(plans.first['group_id'] as String, userId);
      if (membership == null || membership['status'] != 'active') {
        return _forbidden('Not a group member');
      }

      if (plans.first['status'] == 'completed') {
        return _badRequest('Cannot update preferences for a completed hangout');
      }
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }

    final prefData = <String, dynamic>{
      'hangout_plan_id': hangoutId,
      'user_id': userId,
      'updated_at': DateTime.now().toIso8601String(),
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
      if (body.containsKey(field)) prefData[field] = body[field];
    }

    try {
      final result = await _db.insert(
        'hangout_preferences',
        prefData,
        upsert: true,
        onConflict: 'hangout_plan_id,user_id',
      );

      // TODO: notify group via WebSocket that this person submitted
      // WebSocketHandler.broadcastToGroup(groupId, 'preference_submitted', {'user_id': userId});

      return _ok(result);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<hangoutId>/preferences
  // Returns all submitted preferences for the hangout, merged with
  // each member's permanent dietary restrictions from their profile.
  //
  // The frontend uses this to:
  //   1. Show what everyone is feeling
  //   2. Highlight conflicts (e.g. budget mismatch, dietary clash)
  //   3. Pass to a recommendation API to find matching spots
  //
  // Uses the hangout_member_constraints view from the schema.
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
      if (plans.isEmpty) return _notFound('Hangout not found');

      final membership = await _getMembership(plans.first['group_id'] as String, userId);
      if (membership == null || membership['status'] != 'active') {
        return _forbidden('Not a group member');
      }

      // Query the view that merges per-hangout prefs + permanent dietary restrictions
      final preferences = await _db.select(
        'hangout_member_constraints',
        filters: {'hangout_plan_id': 'eq.$hangoutId'},
      );

      // Build a conflict summary the frontend can display
      final conflicts = _findConflicts(preferences);

      return _ok({
        'preferences': preferences,
        'conflicts': conflicts,
        // Budget breakdown — useful for showing who's on what tier
        'budget_summary': _budgetSummary(preferences),
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  Future<Map<String, dynamic>?> _getMembership(String groupId, String userId) async {
    try {
      final rows = await _db.select(
        'group_members',
        filters: {'group_id': 'eq.$groupId', 'user_id': 'eq.$userId'},
        single: true,
      );
      return rows.firstOrNull;
    } on SupabaseException {
      return null;
    }
  }

  /// Scans all submitted preferences and flags obvious conflicts.
  /// This feeds the "Smart Conflict Resolution" reach feature.
  Map<String, dynamic> _findConflicts(List<Map<String, dynamic>> prefs) {
    final conflicts = <String, dynamic>{};

    // Budget conflict: check if people are on very different tiers
    final budgets = prefs
        .where((p) => p['budget_range'] != null)
        .map((p) => p['budget_range'] as String)
        .toSet();

    if (budgets.contains('\$') && budgets.contains('\$\$\$')) {
      final cheapPeople = prefs
          .where((p) => p['budget_range'] == '\$')
          .map((p) => p['display_name'])
          .toList();
      final spendy = prefs
          .where((p) => p['budget_range'] == '\$\$\$')
          .map((p) => p['display_name'])
          .toList();
      conflicts['budget'] = {
        'has_conflict': true,
        'message': 'Budget mismatch in the group',
        'low_budget': cheapPeople,
        'high_budget': spendy,
        'suggestion': 'Consider a "\$\$" spot that works for everyone, or split the plan.',
      };
    }

    // Dietary conflicts: collect all restrictions so venue search can filter
    final allRestrictions = prefs
        .expand((p) => (p['dietary_restrictions'] as List? ?? []).cast<String>())
        .toSet()
        .toList();

    if (allRestrictions.isNotEmpty) {
      conflicts['dietary'] = {
        'has_conflict': false, // Not a conflict, just a constraint
        'restrictions': allRestrictions,
        'message': 'Venue must accommodate: ${allRestrictions.join(", ")}',
      };
    }

    // Availability conflict: check if there's any time overlap
    final availabilities = prefs
        .where((p) => p['available_from'] != null && p['available_until'] != null)
        .map((p) => (
              from: DateTime.parse(p['available_from'] as String),
              until: DateTime.parse(p['available_until'] as String),
              name: p['display_name'] as String,
            ))
        .toList();

    if (availabilities.length > 1) {
      final latestStart = availabilities.map((a) => a.from).reduce((a, b) => a.isAfter(b) ? a : b);
      final earliestEnd = availabilities.map((a) => a.until).reduce((a, b) => a.isBefore(b) ? a : b);

      if (latestStart.isAfter(earliestEnd)) {
        conflicts['availability'] = {
          'has_conflict': true,
          'message': 'No common availability window found',
          'suggestion': 'Ask members to update their available times.',
        };
      } else {
        conflicts['availability'] = {
          'has_conflict': false,
          'overlap_from': latestStart.toIso8601String(),
          'overlap_until': earliestEnd.toIso8601String(),
        };
      }
    }

    return conflicts;
  }

  /// Summarizes the budget tiers across all submitted preferences.
  Map<String, dynamic> _budgetSummary(List<Map<String, dynamic>> prefs) {
    final counts = <String, int>{'\$': 0, '\$\$': 0, '\$\$\$': 0, 'not_set': 0};
    for (final p in prefs) {
      final budget = p['budget_range'] as String?;
      if (budget == null || !counts.containsKey(budget)) {
        counts['not_set'] = (counts['not_set'] ?? 0) + 1;
      } else {
        counts[budget] = (counts[budget] ?? 0) + 1;
      }
    }
    // The "consensus" budget is the most conservative (lowest) tier submitted
    String? consensus;
    if ((counts['\$'] ?? 0) > 0) consensus = '\$';
    else if ((counts['\$\$'] ?? 0) > 0) consensus = '\$\$';
    else if ((counts['\$\$\$'] ?? 0) > 0) consensus = '\$\$\$';

    return {'breakdown': counts, 'consensus_budget': consensus};
  }
}

// ─── Response helpers ──────────────────────────────────────────────────────────
const _jsonHeader = {'Content-Type': 'application/json'};
Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);
Response _badRequest(String msg) => Response(400, body: jsonEncode({'error': msg}), headers: _jsonHeader);
Response _forbidden(String msg) => Response.forbidden(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _serverError(String msg) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);