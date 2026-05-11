import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

class GroupsController {
  final _db = SupabaseClient.admin;
  final _uuid = const Uuid();

  Router get router {
    final router = Router();
    final auth = requireAuth();

    /// POST   /api/groups              — create a group
    /// GET    /api/groups              — list my groups
    /// GET    /api/groups/<id>         — get group + members
    /// POST   /api/groups/<id>/invite  — invite by email
    /// DELETE /api/groups/<id>/leave   — leave group
    router.post('/', Pipeline().addMiddleware(auth).addHandler(_createGroup));
    router.get('/', Pipeline().addMiddleware(auth).addHandler(_getMyGroups));
    router.get('/<groupId>', Pipeline().addMiddleware(auth).addHandler(_getGroup));
    router.post('/<groupId>/invite', Pipeline().addMiddleware(auth).addHandler(_inviteMember));
    router.delete('/<groupId>/leave', Pipeline().addMiddleware(auth).addHandler(_leaveGroup));
    router.delete('/<groupId>', Pipeline().addMiddleware(auth).addHandler(_deleteGroup));

    return router;
  }

  // ─────────────────────────────────────────
  // POST /
  // Body: { "name": "Friday Crew", "description": "...", "emoji": "🍕" }
  // ─────────────────────────────────────────
  Future<Response> _createGroup(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final name = (body['name'] as String?)?.trim() ?? '';

    if (name.isEmpty) {
      return _badRequest('Group name is required');
    }

    final groupId = _uuid.v4();

    try {
      // 1. Create the group
      final group = await _db.insert('groups', {
        'id': groupId,
        'name': name,
        'description': body['description'],
        'emoji': body['emoji'] ?? '🎉',
        'created_by': userId,
      });

      // 2. Add creator as admin member
      await _db.insert('group_members', {
        'group_id': groupId,
        'user_id': userId,
        'role': 'admin',
        'status': 'active',
      });

      return Response(201, body: jsonEncode(group), headers: _jsonHeader);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /
  // Returns all groups the user is an active member of.
  // ─────────────────────────────────────────
  Future<Response> _getMyGroups(Request req) async {
    final userId = req.userId;
    try {
      // Get memberships with embedded group data
      final memberships = await _db.select(
        'group_members',
        filters: {'user_id': 'eq.$userId', 'status': 'eq.active'},
        columns: 'role,joined_at,groups(id,name,description,emoji,created_at,created_by)',
      );

      final groups = memberships.map((row) {
        final group = row['groups'] as Map<String, dynamic>;
        return {
          ...group,
          'my_role': row['role'],
          'joined_at': row['joined_at'],
        };
      }).toList();

      return _ok(groups);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<groupId>
  // Returns group details + full member list.
  // ─────────────────────────────────────────
  Future<Response> _getGroup(Request req) async {
    final groupId = req.params['groupId']!;
    final userId = req.userId;

    // Verify requester is active member
    final membership = await _getMembership(groupId, userId);
    if (membership == null || membership['status'] != 'active') {
      return _forbidden('You are not a member of this group');
    }

    try {
      final groups = await _db.select('groups', filters: {'id': 'eq.$groupId'}, single: true);
      if (groups.isEmpty) return _notFound('Group not found');

      final members = await _db.select(
        'group_members',
        filters: {'group_id': 'eq.$groupId', 'status': 'eq.active'},
        columns: 'user_id,role,status,joined_at,profiles(id,display_name,avatar_url,food_preferences,dietary_restrictions,budget_range)',
      );

      return _ok({...groups.first, 'members': members});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // POST /<groupId>/invite
  // Body: { "email": "friend@example.com" }
  // ─────────────────────────────────────────
  Future<Response> _inviteMember(Request req) async {
    final groupId = req.params['groupId']!;
    final inviterId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final email = (body['email'] as String?)?.toLowerCase() ?? '';

    if (email.isEmpty) return _badRequest('Email is required');

    // Check inviter is an active member
    final inviterMembership = await _getMembership(groupId, inviterId);
    if (inviterMembership == null || inviterMembership['status'] != 'active') {
      return _forbidden('Only group members can invite others');
    }

    try {
      // Find the user by email (admin-only endpoint)
      final users = await _db.listUsers();
      final invitee = users.where((u) => u['email'] == email).firstOrNull;
      if (invitee == null) {
        return _notFound('No user found with that email. They must sign up first.');
      }

      final inviteeId = invitee['id'] as String;

      // Check not already a member or invited
      final existing = await _getMembership(groupId, inviteeId);
      if (existing != null) {
        if (existing['status'] == 'active') return _conflict('User is already a member');
      }

      // Check for existing pending invite
      final existingInvites = await _db.select(
        'group_invites',
        filters: {'group_id': 'eq.$groupId', 'invited_user_id': 'eq.$inviteeId', 'status': 'eq.pending'},
      );
      if (existingInvites.isNotEmpty) return _conflict('User already has a pending invite');

      // Create the invite (expires in 7 days)
      final inviteId = _uuid.v4();
      final expiresAt = DateTime.now().add(const Duration(days: 7)).toIso8601String();

      await _db.insert('group_invites', {
        'id': inviteId,
        'group_id': groupId,
        'invited_user_id': inviteeId,
        'invited_by': inviterId,
        'status': 'pending',
        'expires_at': expiresAt,
      });

      // TODO: send push notification to invitee here
      // For now, client polls GET /api/invites/pending

      return Response(201,
          body: jsonEncode({'message': 'Invite sent to $email', 'invite_id': inviteId}),
          headers: _jsonHeader);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // DELETE /<groupId>/leave
  // ─────────────────────────────────────────
  Future<Response> _leaveGroup(Request req) async {
    final groupId = req.params['groupId']!;
    final userId = req.userId;

    try {
      await _db.update(
        'group_members',
        {'status': 'left'},
        filters: {'group_id': 'eq.$groupId', 'user_id': 'eq.$userId'},
      );
      return _ok({'message': 'You have left the group'});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // DELETE /<groupId>
  // Only the group admin (creator) can delete the group.
  // ─────────────────────────────────────────
  Future<Response> _deleteGroup(Request req) async {
    final groupId = req.params['groupId']!;
    final userId = req.userId;

    final membership = await _getMembership(groupId, userId);
    if (membership == null || membership['role'] != 'admin') {
      return _forbidden('Only the group admin can delete this group');
    }

    try {
      await _db.delete('groups', filters: {'id': 'eq.$groupId'});
      return _ok({'message': 'Group deleted'});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─── Helper ───────────────────────────────────────────────
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
}

// ─── Response helpers ──────────────────────────────────────────────────────────
const _jsonHeader = {'Content-Type': 'application/json'};

Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);
Response _badRequest(String msg) => Response(400, body: jsonEncode({'error': msg}), headers: _jsonHeader);
Response _forbidden(String msg) => Response.forbidden(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _conflict(String msg) => Response(409, body: jsonEncode({'error': msg}), headers: _jsonHeader);
Response _serverError(String msg) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);