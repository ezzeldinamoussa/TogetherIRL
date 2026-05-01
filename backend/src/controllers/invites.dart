import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

class InvitesController {
  final _db = SupabaseClient.admin;

  Router get router {
    final router = Router();
    final auth = requireAuth();

    /// GET  /api/invites/pending              — see my pending invites
    /// POST /api/invites/<inviteId>/respond   — accept or decline
    router.get('/pending', Pipeline().addMiddleware(auth).addHandler(_getPendingInvites));
    router.post('/<inviteId>/respond', Pipeline().addMiddleware(auth).addHandler(_respondToInvite));

    return router;
  }

  // ─────────────────────────────────────────
  // GET /pending
  // Returns all unexpired pending invites for the current user.
  // ─────────────────────────────────────────
  Future<Response> _getPendingInvites(Request req) async {
    final userId = req.userId;
    final now = DateTime.now().toIso8601String();

    try {
      final invites = await _db.select(
        'group_invites',
        filters: {
          'invited_user_id': 'eq.$userId',
          'status': 'eq.pending',
          'expires_at': 'gt.$now',
        },
        columns: 'id,created_at,expires_at,groups(id,name,emoji,description),profiles!group_invites_invited_by_fkey(display_name,avatar_url)',
      );
      return _ok(invites);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // POST /<inviteId>/respond
  // Body: { "accept": true } or { "accept": false }
  // ─────────────────────────────────────────
  Future<Response> _respondToInvite(Request req) async {
    final inviteId = req.params['inviteId']!;
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    if (body['accept'] is! bool) {
      return _badRequest("'accept' must be true or false");
    }
    final accept = body['accept'] as bool;
    final now = DateTime.now().toIso8601String();

    try {
      // Verify invite belongs to this user, is pending, and not expired
      final invites = await _db.select(
        'group_invites',
        filters: {
          'id': 'eq.$inviteId',
          'invited_user_id': 'eq.$userId',
          'status': 'eq.pending',
          'expires_at': 'gt.$now',
        },
        single: true,
      );

      if (invites.isEmpty) {
        return _notFound('Invite not found or already responded to');
      }

      final invite = invites.first;
      final groupId = invite['group_id'] as String;

      // Update invite status
      await _db.update(
        'group_invites',
        {'status': accept ? 'accepted' : 'declined'},
        filters: {'id': 'eq.$inviteId'},
      );

      if (accept) {
        // Add user to group
        await _db.insert('group_members', {
          'group_id': groupId,
          'user_id': userId,
          'role': 'member',
          'status': 'active',
        });
      }

      return _ok({
        'message': accept ? 'You joined the group!' : 'Invite declined',
        'group_id': accept ? groupId : null,
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }
}

// ─── Response helpers ──────────────────────────────────────────────────────────
const _jsonHeader = {'Content-Type': 'application/json'};

Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);
Response _badRequest(String msg) => Response(400, body: jsonEncode({'error': msg}), headers: _jsonHeader);
Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _serverError(String msg) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);