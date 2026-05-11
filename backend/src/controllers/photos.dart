import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

class PhotosController {
  final _db = SupabaseClient.admin;
  final _uuid = const Uuid();

  Router get router {
    final router = Router();
    final auth = requireAuth();

    // GET  /api/photos/active                   active sessions for user's groups
    // POST /api/photos/sessions                 create a session
    // GET  /api/photos/sessions/<id>            session details + member statuses
    // POST /api/photos/sessions/<id>/upload     upload photos
    // POST /api/photos/sessions/<id>/skip       skip
    // POST /api/photos/sessions/<id>/undo       undo upload or skip

    router.get('/active', Pipeline().addMiddleware(auth).addHandler(_getActiveSessions));
    router.post('/sessions', Pipeline().addMiddleware(auth).addHandler(_createSession));
    router.get('/sessions/<sessionId>', Pipeline().addMiddleware(auth).addHandler(_getSession));
    router.post('/sessions/<sessionId>/upload', Pipeline().addMiddleware(auth).addHandler(_uploadPhotos));
    router.post('/sessions/<sessionId>/skip', Pipeline().addMiddleware(auth).addHandler(_skipSession));
    router.post('/sessions/<sessionId>/undo', Pipeline().addMiddleware(auth).addHandler(_undoAction));

    return router;
  }

  // ── GET /active ───────────────────────────────────────────────
  Future<Response> _getActiveSessions(Request req) async {
    final userId = req.userId;
    final now = DateTime.now().toIso8601String();

    try {
      // Get all groups the user is active in
      final memberships = await _db.select(
        'group_members',
        filters: {'user_id': 'eq.$userId', 'status': 'eq.active'},
        columns: 'group_id',
      );
      if (memberships.isEmpty) return _ok([]);

      final groupIds = memberships.map((m) => m['group_id'] as String).toList();

      // Get active sessions for those groups
      final sessions = await _db.select(
        'hangout_photo_sessions',
        filters: {
          'group_id': 'in.(${groupIds.join(',')})',
          'closes_at': 'gt.$now',
          'order': 'created_at.desc',
        },
        columns: 'id,title,group_id,hangout_plan_id,opens_at,closes_at,groups(name,emoji)',
      );

      // For each session, attach the user's own status
      final enriched = await Future.wait(sessions.map((s) async {
        final myStatus = await _getMemberStatus(s['id'] as String, userId);
        return {...s, 'my_status': myStatus};
      }));

      return _ok(enriched);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ── POST /sessions ────────────────────────────────────────────
  Future<Response> _createSession(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final groupId = body['group_id'] as String?;
    if (groupId == null) return _badRequest('group_id is required');

    final membership = await _getMembership(groupId, userId);
    if (membership == null) return _forbidden('Not a group member');

    try {
      final closes = DateTime.now().add(const Duration(hours: 24)).toIso8601String();
      final session = await _db.insert('hangout_photo_sessions', {
        'id': _uuid.v4(),
        'group_id': groupId,
        if (body['hangout_plan_id'] != null) 'hangout_plan_id': body['hangout_plan_id'],
        'title': body['title'] ?? 'Photo Collection',
        'closes_at': closes,
      });
      return Response(201, body: jsonEncode(session), headers: _jsonHeader);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ── GET /sessions/<id> ────────────────────────────────────────
  Future<Response> _getSession(Request req) async {
    final sessionId = req.params['sessionId']!;
    final userId = req.userId;

    try {
      final sessions = await _db.select(
        'hangout_photo_sessions',
        filters: {'id': 'eq.$sessionId'},
        single: true,
      );
      if (sessions.isEmpty) return _notFound('Session not found');
      final session = sessions.first;

      final membership = await _getMembership(session['group_id'] as String, userId);
      if (membership == null) return _forbidden('Not a group member');

      // Get all active group members
      final members = await _db.select(
        'group_members',
        filters: {'group_id': 'eq.${session['group_id']}', 'status': 'eq.active'},
        columns: 'user_id,role,profiles(display_name,avatar_url)',
      );

      // Get all photo records for this session
      final photoRecords = await _db.select(
        'hangout_member_photos',
        filters: {'session_id': 'eq.$sessionId'},
      );

      final recordMap = {
        for (final r in photoRecords) r['user_id'] as String: r,
      };

      // Build member status list
      final memberStatuses = members.map((m) {
        final uid = m['user_id'] as String;
        final profile = m['profiles'] as Map<String, dynamic>? ?? {};
        final record = recordMap[uid];
        return {
          'user_id': uid,
          'display_name': profile['display_name'] ?? 'Member',
          'avatar_url': profile['avatar_url'],
          'role': m['role'],
          'status': record?['status'] ?? 'pending',
          'photo_urls': record?['photo_urls'] ?? [],
          'uploaded_at': record?['uploaded_at'],
        };
      }).toList();

      final total = memberStatuses.length;
      final responded = memberStatuses
          .where((m) => m['status'] != 'pending')
          .length;

      // Collect all uploaded photos
      final allPhotos = memberStatuses
          .where((m) => m['status'] == 'uploaded')
          .expand((m) => (m['photo_urls'] as List).cast<String>())
          .toList();

      return _ok({
        ...session,
        'members': memberStatuses,
        'responded': responded,
        'total': total,
        'all_photos': allPhotos,
        'my_status': recordMap[userId]?['status'] ?? 'pending',
        'my_photos': recordMap[userId]?['photo_urls'] ?? [],
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ── POST /sessions/<id>/upload ────────────────────────────────
  // Body: { "photos": ["<base64>", ...] }
  Future<Response> _uploadPhotos(Request req) async {
    final sessionId = req.params['sessionId']!;
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final photos = (body['photos'] as List?)?.cast<String>() ?? [];

    if (photos.isEmpty) return _badRequest('No photos provided');

    try {
      final sessions = await _db.select(
        'hangout_photo_sessions',
        filters: {'id': 'eq.$sessionId'},
        single: true,
      );
      if (sessions.isEmpty) return _notFound('Session not found');
      final session = sessions.first;

      // Check window is still open
      final closesAt = DateTime.parse(session['closes_at'] as String);
      if (DateTime.now().isAfter(closesAt)) {
        return _badRequest('Photo collection window has closed');
      }

      // Upload each photo to Supabase Storage
      final urls = <String>[];
      for (int i = 0; i < photos.length; i++) {
        final bytes = base64Decode(photos[i]);
        final path = 'sessions/$sessionId/$userId/${_uuid.v4()}.jpg';
        final url = await _db.uploadFile(
          bucket: 'hangout-photos',
          path: path,
          bytes: bytes,
          contentType: 'image/jpeg',
        );
        urls.add(url);
      }

      // Upsert photo record
      await _db.insert(
        'hangout_member_photos',
        {
          'id': _uuid.v4(),
          'session_id': sessionId,
          'user_id': userId,
          'status': 'uploaded',
          'photo_urls': urls,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
        upsert: true,
        onConflict: 'session_id,user_id',
      );

      return _ok({'message': 'Photos uploaded', 'urls': urls});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ── POST /sessions/<id>/skip ──────────────────────────────────
  Future<Response> _skipSession(Request req) async {
    final sessionId = req.params['sessionId']!;
    final userId = req.userId;

    try {
      await _db.insert(
        'hangout_member_photos',
        {
          'id': _uuid.v4(),
          'session_id': sessionId,
          'user_id': userId,
          'status': 'skipped',
          'photo_urls': [],
        },
        upsert: true,
        onConflict: 'session_id,user_id',
      );
      return _ok({'message': 'Skipped'});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ── POST /sessions/<id>/undo ──────────────────────────────────
  Future<Response> _undoAction(Request req) async {
    final sessionId = req.params['sessionId']!;
    final userId = req.userId;

    try {
      await _db.update(
        'hangout_member_photos',
        {'status': 'pending', 'photo_urls': [], 'uploaded_at': null},
        filters: {'session_id': 'eq.$sessionId', 'user_id': 'eq.$userId'},
      );
      return _ok({'message': 'Undone'});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  Future<String> _getMemberStatus(String sessionId, String userId) async {
    try {
      final rows = await _db.select(
        'hangout_member_photos',
        filters: {'session_id': 'eq.$sessionId', 'user_id': 'eq.$userId'},
        single: true,
      );
      return rows.firstOrNull?['status'] as String? ?? 'pending';
    } on SupabaseException {
      return 'pending';
    }
  }

  Future<Map<String, dynamic>?> _getMembership(String groupId, String userId) async {
    try {
      final rows = await _db.select(
        'group_members',
        filters: {'group_id': 'eq.$groupId', 'user_id': 'eq.$userId', 'status': 'eq.active'},
        single: true,
      );
      return rows.firstOrNull;
    } on SupabaseException {
      return null;
    }
  }
}

const _jsonHeader = {'Content-Type': 'application/json'};
Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);
Response _badRequest(String msg) => Response(400, body: jsonEncode({'error': msg}), headers: _jsonHeader);
Response _forbidden(String msg) => Response.forbidden(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _serverError(String msg) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);
