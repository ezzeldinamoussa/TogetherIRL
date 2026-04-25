import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

class ProfilesController {
  final _db = SupabaseClient.admin;

  Router get router {
    final router = Router();

    // All routes require auth
    final auth = requireAuth();

    /// GET /api/profiles/me
    /// Returns the authenticated user's full profile.
    router.get('/me', Pipeline().addMiddleware(auth).addHandler(_getMyProfile));

    /// PUT /api/profiles/me
    /// Creates or updates the authenticated user's profile.
    router.put('/me', Pipeline().addMiddleware(auth).addHandler(_upsertMyProfile));

    /// GET /api/profiles/<userId>
    /// Returns any user's public profile (for group member cards).
    router.get('/<userId>', Pipeline().addMiddleware(auth).addHandler(_getProfileById));

    return router;
  }

  // ─────────────────────────────────────────
  // GET /me
  // ─────────────────────────────────────────
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

  // ─────────────────────────────────────────
  // PUT /me
  // ─────────────────────────────────────────
  // Body (all fields optional):
  // {
  //   "display_name": "Sophia",
  //   "bio": "Always hungry 🍜",
  //   "food_preferences": ["Korean", "Mexican"],
  //   "dietary_restrictions": ["vegetarian"],
  //   "budget_range": "$$",
  //   "activity_types": ["food", "coffee", "dessert"],
  //   "max_travel_distance_km": 5
  // }
  Future<Response> _upsertMyProfile(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final profileData = <String, dynamic>{
      'id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Only include fields the client actually sent
    const allowedFields = [
      'display_name', 'avatar_url', 'bio',
      'food_preferences', 'dietary_restrictions',
      'budget_range', 'activity_types', 'max_travel_distance_km',
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

  // ─────────────────────────────────────────
  // GET /<userId>
  // ─────────────────────────────────────────
  Future<Response> _getProfileById(Request req) async {
    final userId = req.params['userId']!;
    try {
      final rows = await _db.select(
        'profiles',
        filters: {'id': 'eq.$userId'},
        columns: 'id,display_name,avatar_url,bio,food_preferences,dietary_restrictions,budget_range,activity_types',
        single: true,
      );
      if (rows.isEmpty) return _notFound('Profile not found');
      return _ok(rows.first);
    } on SupabaseException {
      return _notFound('Profile not found');
    }
  }
}

// ─── Response helpers ─────────────────────────────────────────────────────────
Response _ok(dynamic data) => Response.ok(
      jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

Response _notFound(String msg) => Response.notFound(
      jsonEncode({'error': msg}),
      headers: {'Content-Type': 'application/json'},
    );

Response _serverError(String msg) => Response.internalServerError(
      body: jsonEncode({'error': msg}),
      headers: {'Content-Type': 'application/json'},
    );