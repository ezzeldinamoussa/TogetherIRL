import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

class ProfilesController {
  final _db = SupabaseClient.admin;

  Router get router {
    final router = Router();
    final auth = requireAuth();

    router.get('/me', Pipeline().addMiddleware(auth).addHandler(_getMyProfile));
    router.put('/me', Pipeline().addMiddleware(auth).addHandler(_upsertMyProfile));
    router.get('/<userId>', Pipeline().addMiddleware(auth).addHandler(_getProfileById));

    return router;
  }

  // GET /me
  Future<Response> _getMyProfile(Request req) async {
    final userId = req.userId;
    try {
      final rows = await _db.select('profiles', filters: {'id': 'eq.$userId'}, single: true);
      if (rows.isEmpty) return _notFound('Profile not found');
      return _ok(rows.first);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // PUT /me
  // Profiles only store permanent personal info now.
  // Budget, activity types, and food preferences are collected per-hangout.
  //
  // Body (all optional):
  // {
  //   "display_name": "Sophia",
  //   "avatar_url": "https://...",
  //   "bio": "Always hungry 🍜",
  //   "dietary_restrictions": ["vegetarian", "nut-allergy"],
  //   "max_travel_distance_km": 8
  // }
  Future<Response> _upsertMyProfile(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final profileData = <String, dynamic>{
      'id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    const allowedFields = [
      'display_name',
      'avatar_url',
      'bio',
      'dietary_restrictions',    // hard limits — stays on profile
      'max_travel_distance_km',  // general default — can be overridden per hangout
    ];

    for (final field in allowedFields) {
      if (body.containsKey(field)) profileData[field] = body[field];
    }

    try {
      final result = await _db.insert('profiles', profileData, upsert: true, onConflict: 'id');
      return _ok(result);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // GET /<userId> — public profile for group member cards
  Future<Response> _getProfileById(Request req) async {
    final userId = req.params['userId']!;
    try {
      final rows = await _db.select(
        'profiles',
        filters: {'id': 'eq.$userId'},
        columns: 'id,display_name,avatar_url,bio,dietary_restrictions,max_travel_distance_km',
        single: true,
      );
      if (rows.isEmpty) return _notFound('Profile not found');
      return _ok(rows.first);
    } on SupabaseException {
      return _notFound('Profile not found');
    }
  }
}

const _jsonHeader = {'Content-Type': 'application/json'};
Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);
Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _serverError(String msg) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);