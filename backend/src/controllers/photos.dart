import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

class PhotosController {
  static const _bucket = 'hangout-photos';

  final _db = SupabaseClient.admin;
  final _uuid = const Uuid();

  Router get router {
    final router = Router();
    final auth = requireAuth();

    // GET  /api/photos/active                   active sessions for user's groups
    // GET  /api/photos/past                     closed sessions (finished memories)
    // POST /api/photos/sessions                 create a session
    // GET  /api/photos/sessions/<id>            session details + member statuses
    // POST /api/photos/sessions/<id>/upload     upload photos
    // POST /api/photos/sessions/<id>/skip       skip
    // POST /api/photos/sessions/<id>/undo       undo upload or skip

    router.get('/active', Pipeline().addMiddleware(auth).addHandler(_getActiveSessions));
    router.get('/past', Pipeline().addMiddleware(auth).addHandler(_getPastSessions));
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
    final now = DateTime.now().toUtc().toIso8601String();

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
        columns: 'id,title,group_id,hangout_plan_id,opens_at,closes_at,'
            'groups(name,emoji),hangout_plans(title,planned_for)',
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

  // ── GET /past ─────────────────────────────────────────────────
  // Collections whose window has closed. /active deliberately hides these,
  // so without this route a finished collection — and every photo in it —
  // is unreachable from the app once 24 hours have passed.
  Future<Response> _getPastSessions(Request req) async {
    final userId = req.userId;
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      final memberships = await _db.select(
        'group_members',
        filters: {'user_id': 'eq.$userId', 'status': 'eq.active'},
        columns: 'group_id',
      );
      if (memberships.isEmpty) return _ok([]);

      final groupIds = memberships.map((m) => m['group_id'] as String).toList();

      final sessions = await _db.select(
        'hangout_photo_sessions',
        filters: {
          'group_id': 'in.(${groupIds.join(',')})',
          'closes_at': 'lt.$now',
          'order': 'closes_at.desc',
        },
        columns: 'id,title,group_id,hangout_plan_id,opens_at,closes_at,'
            'groups(name,emoji),hangout_plans(title,planned_for)',
      );
      if (sessions.isEmpty) return _ok([]);

      // One query covering every session, rather than one query per session.
      final sessionIds = sessions.map((s) => s['id'] as String).toList();
      final records = await _db.select(
        'hangout_member_photos',
        filters: {
          'session_id': 'in.(${sessionIds.join(',')})',
          'status': 'eq.uploaded',
        },
        columns: 'session_id,photo_urls',
      );

      final photosBySession = <String, List<String>>{};
      for (final r in records) {
        final urls = (r['photo_urls'] as List?)?.cast<String>() ?? const [];
        photosBySession
            .putIfAbsent(r['session_id'] as String, () => [])
            .addAll(urls);
      }

      // One signing round for every photo across every past collection.
      final signed = await _signMap(
        [for (final urls in photosBySession.values) ...urls],
      );

      // Collections that closed with nobody uploading hold no memory, so
      // they are dropped rather than shown as empty cards forever.
      final enriched = <Map<String, dynamic>>[];
      for (final s in sessions) {
        final photos = _applySigned(photosBySession[s['id'] as String], signed);
        if (photos.isEmpty) continue;
        enriched.add({...s, 'photos': photos, 'photo_count': photos.length});
      }

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
      // toUtc() matters: toIso8601String() on a local DateTime emits no
      // offset, so Postgres read it as UTC and every window closed early by
      // the server's offset from UTC — 24h was really 20h on EDT.
      final closes = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String();
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
        columns: '*,groups(name,emoji),hangout_plans(title,planned_for)',
        single: true,
      );
      if (sessions.isEmpty) return _notFound('Session not found');
      final session = sessions.first;

      final membership = await _getMembership(session['group_id'] as String, userId);
      if (membership == null) return _forbidden('Not a group member');

      // Get all active group members. group_members.user_id points at
      // auth.users rather than profiles, so PostgREST cannot embed profiles
      // from here — asking it to made this whole route fail with PGRST200,
      // which the app swallowed as "no members". Fetched separately and
      // merged, the same way GroupsController does it.
      final members = await _db.select(
        'group_members',
        filters: {'group_id': 'eq.${session['group_id']}', 'status': 'eq.active'},
        columns: 'user_id,role',
      );

      final profilesById = await _profilesByIds(
        members.map((m) => m['user_id'] as String).toList(),
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
        final profile = profilesById[uid] ?? const <String, dynamic>{};
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

      // One signing round covers every photo in the session, rather than
      // one request per member.
      final signed = await _signMap([
        for (final m in memberStatuses)
          ...((m['photo_urls'] as List?)?.cast<String>() ?? const <String>[]),
      ]);

      final signedMembers = [
        for (final m in memberStatuses)
          {...m, 'photo_urls': _applySigned(m['photo_urls'], signed)},
      ];

      // Collect all uploaded photos
      final allPhotos = signedMembers
          .where((m) => m['status'] == 'uploaded')
          .expand((m) => (m['photo_urls'] as List).cast<String>())
          .toList();

      return _ok({
        ...session,
        'members': signedMembers,
        'responded': responded,
        'total': total,
        'all_photos': allPhotos,
        'my_status': recordMap[userId]?['status'] ?? 'pending',
        'my_photos': _applySigned(recordMap[userId]?['photo_urls'], signed),
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

      // Upload each photo to Supabase Storage. uploadFile hands back the
      // object path, which is what gets stored: the bucket is private, so a
      // link has to be signed fresh on every read.
      final paths = <String>[];
      for (int i = 0; i < photos.length; i++) {
        final bytes = base64Decode(photos[i]);
        final path = 'sessions/$sessionId/$userId/${_uuid.v4()}.jpg';
        paths.add(await _db.uploadFile(
          bucket: _bucket,
          path: path,
          bytes: bytes,
          contentType: 'image/jpeg',
        ));
      }

      // Append rather than replace. The record is upserted on
      // (session_id, user_id), so overwriting photo_urls would silently drop
      // everything from an earlier upload in the same window and orphan those
      // files in storage. Appending also lets the client send a big selection
      // as several small requests instead of one huge one.
      final existing = await _existingPhotoRow(sessionId, userId);
      final previous =
          (existing?['photo_urls'] as List?)?.cast<String>() ??
              const <String>[];

      await _db.insert(
        'hangout_member_photos',
        {
          'id': existing?['id'] ?? _uuid.v4(),
          'session_id': sessionId,
          'user_id': userId,
          'status': 'uploaded',
          'photo_urls': [...previous, ...paths],
          'uploaded_at': DateTime.now().toUtc().toIso8601String(),
        },
        upsert: true,
        onConflict: 'session_id,user_id',
      );

      return _ok({
        'message': 'Photos uploaded',
        'urls': _applySigned(paths, await _signMap(paths)),
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ── POST /sessions/<id>/skip ──────────────────────────────────
  Future<Response> _skipSession(Request req) async {
    final sessionId = req.params['sessionId']!;
    final userId = req.userId;

    try {
      // Reuse the row's own id when one already exists (skip after an undo,
      // say) so the upsert updates it in place instead of renumbering its
      // primary key.
      final existing = await _existingPhotoRow(sessionId, userId);

      await _db.insert(
        'hangout_member_photos',
        {
          'id': existing?['id'] ?? _uuid.v4(),
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

  /// This member's row for the session, or null if they have not responded.
  ///
  /// Deliberately not single: true — that asks PostgREST for exactly one row
  /// and fails outright on zero, which is the normal case here.
  Future<Map<String, dynamic>?> _existingPhotoRow(
      String sessionId, String userId) async {
    final rows = await _db.select(
      'hangout_member_photos',
      filters: {'session_id': 'eq.$sessionId', 'user_id': 'eq.$userId'},
    );
    return rows.firstOrNull;
  }

  /// Display names and avatars for [userIds], keyed by user id.
  Future<Map<String, Map<String, dynamic>>> _profilesByIds(
      List<String> userIds) async {
    final unique = userIds.toSet().toList();
    if (unique.isEmpty) return const {};
    final rows = await _db.select(
      'profiles',
      filters: {'id': 'in.(${unique.join(',')})'},
      columns: 'id,display_name,avatar_url',
    );
    return {for (final r in rows) r['id'] as String: r};
  }

  /// Rows written while the bucket was public hold a full public URL; newer
  /// rows hold a bare object path. Both reduce to the same path.
  String _objectPath(String stored) {
    const marker = '/storage/v1/object/public/$_bucket/';
    final i = stored.indexOf(marker);
    return i >= 0 ? stored.substring(i + marker.length) : stored;
  }

  /// Maps each stored value to a signed link. Signing happens in one request
  /// for the whole set, and de-duplicates first so a photo shared between
  /// members is only signed once.
  Future<Map<String, String>> _signMap(List<String> stored) async {
    final unique = stored.toSet().toList();
    if (unique.isEmpty) return const {};
    try {
      final signed = await _db.createSignedUrls(
        bucket: _bucket,
        paths: unique.map(_objectPath).toList(),
      );
      return {
        for (var i = 0; i < unique.length; i++)
          if (signed[i] != null) unique[i]: signed[i]!,
      };
    } on SupabaseException {
      return const {};
    }
  }

  /// The signed links for [stored], in order. An object that could not be
  /// signed is left out: the bucket is private, so an unsigned path is not
  /// something the app can load.
  List<String> _applySigned(Object? stored, Map<String, String> signed) => [
        for (final s in (stored as List?)?.cast<String>() ?? const <String>[])
          if (signed[s] != null) signed[s]!,
      ];

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
