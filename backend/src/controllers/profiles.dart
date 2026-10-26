import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';
import '../../../lib/services/geocoding_service.dart';

class ProfilesController {
  final _db = SupabaseClient.admin;
  final _geocoder = GeocodingService();

  /// Hard-preference locations a user can save.
  static const _locationLabels = ['home', 'school', 'work'];

  Router get router {
    final router = Router();
    final auth = requireAuth();

    router.get('/me', Pipeline().addMiddleware(auth).addHandler(_getMyProfile));
    router.put('/me', Pipeline().addMiddleware(auth).addHandler(_upsertMyProfile));
    router.get('/<userId>', Pipeline().addMiddleware(auth).addHandler(_getProfileById));

    return router;
  }

  // GET /me
  // Returns the profile plus:
  //   "locations": { "home": {zipcode,lat,lng}, "school": {...}, "work": {...} }
  Future<Response> _getMyProfile(Request req) async {
    final userId = req.userId;
    try {
      final rows = await _db.select('profiles', filters: {'id': 'eq.$userId'}, single: true);
      if (rows.isEmpty) return _notFound('Profile not found');
      final profile = rows.first;

      final locations = await _loadLocations(userId);

      // Legacy fallback: profile saved a zipcode before profile_locations existed.
      if (!locations.containsKey('home') &&
          profile['zipcode'] != null &&
          profile['home_lat'] != null &&
          profile['home_lng'] != null) {
        locations['home'] = {
          'zipcode': profile['zipcode'],
          'lat': profile['home_lat'],
          'lng': profile['home_lng'],
        };
      }

      return _ok({...profile, 'locations': locations});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // PUT /me
  //
  // Body (all optional):
  // {
  //   "display_name": "Sophia",
  //   "avatar_url": "https://...",
  //   "bio": "Always hungry 🍜",
  //   "dietary_restrictions": ["Vegetarian"],
  //   "max_travel_distance_km": 8,
  //   "locations": { "home": "10001", "school": "10031", "work": "" }
  // }
  //
  // In "locations": a ZIP saves/updates that place, an empty string removes it,
  // and an omitted key leaves it unchanged.
  // The legacy "zipcode" field is treated as locations.home.
  Future<Response> _upsertMyProfile(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    // ── 1. Work out which locations the client wants to change ──
    final requested = <String, String>{};
    final rawLocations = body['locations'];
    if (rawLocations is Map) {
      for (final label in _locationLabels) {
        if (rawLocations.containsKey(label)) {
          requested[label] = (rawLocations[label]?.toString() ?? '').trim();
        }
      }
    }
    if (!requested.containsKey('home') && body['zipcode'] is String) {
      requested['home'] = (body['zipcode'] as String).trim();
    }

    // ── 2. Validate + geocode BEFORE writing anything ──
    // value null => remove that location
    final resolved = <String, GeoPoint?>{};
    final resolvedZips = <String, String>{};
    for (final entry in requested.entries) {
      if (entry.value.isEmpty) {
        resolved[entry.key] = null;
        continue;
      }
      final zip5 = GeocodingService.normalizeZip(entry.value);
      if (zip5 == null) {
        return _badRequest(
            '"${entry.value}" is not a valid 5-digit ZIP code (${entry.key}).');
      }
      final point = await _geocoder.geocodeZip(zip5);
      if (point == null) {
        return _badRequest(
            'Could not find ZIP code $zip5 (${entry.key}). Double-check it and try again.');
      }
      resolved[entry.key] = point;
      resolvedZips[entry.key] = zip5;
    }

    // ── 3. Profile row ──
    final profileData = <String, dynamic>{
      'id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    const allowedFields = [
      'display_name',
      'avatar_url',
      'bio',
      'dietary_restrictions',
      'max_travel_distance_km',
    ];
    for (final field in allowedFields) {
      if (body.containsKey(field)) profileData[field] = body[field];
    }

    // Keep the legacy profile columns mirrored to "home" so older code paths
    // (and the hangout_member_constraints fallback) keep working.
    if (resolved.containsKey('home')) {
      final home = resolved['home'];
      profileData['zipcode'] = home == null ? null : resolvedZips['home'];
      profileData['home_lat'] = home?.lat;
      profileData['home_lng'] = home?.lng;
    }

    try {
      final result = await _db.insert('profiles', profileData, upsert: true, onConflict: 'id');

      // ── 4. Location rows ──
      for (final entry in resolved.entries) {
        final label = entry.key;
        final point = entry.value;
        if (point == null) {
          await _db.delete('profile_locations',
              filters: {'user_id': 'eq.$userId', 'label': 'eq.$label'});
        } else {
          await _db.insert(
            'profile_locations',
            {
              'user_id': userId,
              'label': label,
              'zipcode': resolvedZips[label],
              'lat': point.lat,
              'lng': point.lng,
              'updated_at': DateTime.now().toIso8601String(),
            },
            upsert: true,
            onConflict: 'user_id,label',
          );
          print('Saved $label ZIP ${resolvedZips[label]} -> ${point.lat}, ${point.lng}');
        }
      }

      final locations = await _loadLocations(userId);
      return _ok({...result, 'locations': locations});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // GET /<userId> — public profile for group member cards.
  // Locations (zip codes) are private and intentionally NOT returned here.
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

  Future<Map<String, dynamic>> _loadLocations(String userId) async {
    final rows = await _db.select(
      'profile_locations',
      filters: {'user_id': 'eq.$userId'},
      columns: 'label,zipcode,lat,lng',
    );
    final out = <String, dynamic>{};
    for (final r in rows) {
      out[r['label'] as String] = {
        'zipcode': r['zipcode'],
        'lat': r['lat'],
        'lng': r['lng'],
      };
    }
    return out;
  }
}

const _jsonHeader = {'Content-Type': 'application/json'};
Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);
Response _badRequest(String msg) => Response(400, body: jsonEncode({'error': msg}), headers: _jsonHeader);
Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _serverError(String msg) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);