import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';
 
/// Thin wrapper around Supabase's REST API.
/// Dart doesn't have an official Supabase server SDK yet,
/// so we call the PostgREST API directly with http requests.
///
/// The service role key bypasses Row Level Security — only use server-side.
class SupabaseClient {
  final String _baseUrl;
  final String _apiKey;
 
  SupabaseClient._(this._baseUrl, this._apiKey);
 
  /// Admin client — uses service role key, bypasses RLS.
  /// Use this in all backend controllers.
  static SupabaseClient get admin => SupabaseClient._(
        '${Env.supabaseUrl}/rest/v1',
        Env.supabaseServiceRoleKey,
      );
 
  Map<String, String> get _headers => {
        'apikey': _apiKey,
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation', // makes Supabase return the inserted/updated row
      };
 
  // ─── SELECT ───────────────────────────────────────────────
 
  /// SELECT * FROM [table] WHERE [filters]
  /// Example: select('profiles', filters: {'id': 'eq.abc123'})
  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, String> filters = const {},
    String? columns,
    bool single = false,
  }) async {
    final params = <String, String>{
      if (columns != null) 'select': columns,
      ...filters,
    };
 
    final uri = Uri.parse('$_baseUrl/$table').replace(queryParameters: params);
    final headers = Map<String, String>.from(_headers);
    if (single) headers['Accept'] = 'application/vnd.pgrst.object+json';
 
    final res = await http.get(uri, headers: headers);
    _checkStatus(res);
 
    if (single) {
      final decoded = jsonDecode(res.body);
      return [decoded as Map<String, dynamic>];
    }
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }
 
  // ─── INSERT ───────────────────────────────────────────────
 
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data, {
    bool upsert = false,
    String? onConflict,
  }) async {
    final headers = Map<String, String>.from(_headers);
    if (upsert) {
      headers['Prefer'] = 'return=representation,resolution=merge-duplicates';
    }
 

    // on_conflict is a query parameter, not a Prefer option. Sent as a
    // Prefer value it was ignored, so PostgREST fell back to the primary
    // key as the conflict target - a freshly generated id never collides,
    // so every upsert became a plain insert and tripped the real unique
    // constraint on the second write.
    final uri = Uri.parse('$_baseUrl/$table'
        '${upsert && onConflict != null ? '?on_conflict=$onConflict' : ''}');
    final res = await http.post(uri, headers: headers, body: jsonEncode(data));
    _checkStatus(res);
 
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.first as Map<String, dynamic>;
    return decoded as Map<String, dynamic>;
  }
 
  // ─── UPDATE ───────────────────────────────────────────────
 
  Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, String> filters,
  }) async {
    final params = Map<String, String>.from(filters);
    final uri = Uri.parse('$_baseUrl/$table').replace(queryParameters: params);
    final res = await http.patch(uri, headers: _headers, body: jsonEncode(data));
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }
 
  // ─── DELETE ───────────────────────────────────────────────────

  Future<void> delete(
    String table, {
    required Map<String, String> filters,
  }) async {
    final params = Map<String, String>.from(filters);
    final uri = Uri.parse('$_baseUrl/$table').replace(queryParameters: params);
    final res = await http.delete(uri, headers: _headers);
    _checkStatus(res);
  }

  // ─── AUTH: Get user from JWT ───────────────────────────────
 
  /// Validates a Supabase JWT and returns the user object.
  /// Used in the auth middleware to verify Flutter clients.
  Future<Map<String, dynamic>?> getUser(String accessToken) async {
    final uri = Uri.parse('${Env.supabaseUrl}/auth/v1/user');
    final res = await http.get(uri, headers: {
      'apikey': Env.supabaseAnonKey,
      'Authorization': 'Bearer $accessToken',
    });
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
 
  // ─── AUTH: List all users (admin) ─────────────────────────
 
  Future<List<Map<String, dynamic>>> listUsers() async {
    final uri = Uri.parse('${Env.supabaseUrl}/auth/v1/admin/users');
    final res = await http.get(uri, headers: {
      'apikey': _apiKey,
      'Authorization': 'Bearer $_apiKey',
    });
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['users'] ?? []);
  }
 
  // ─── STORAGE: Upload file ──────────────────────────────────
 
  /// Uploads [bytes] and returns the object's path within [bucket].
  ///
  /// A path, not a URL: the buckets holding user content are private, so
  /// there is no permanent public link to hand back. Call [createSignedUrls]
  /// to turn stored paths into links a client can load.
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse('${Env.supabaseUrl}/storage/v1/object/$bucket/$path');
    final res = await http.put(
      uri,
      headers: {
        'apikey': _apiKey,
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': contentType,
        'x-upsert': 'true',
      },
      body: bytes,
    );
    _checkStatus(res);
    return path;
  }
 
  // ─── STORAGE: Sign private objects ─────────────────────────

  /// Time-limited links for objects in a private bucket, in the same order as
  /// [paths]. An entry is null when that object could not be signed.
  Future<List<String?>> createSignedUrls({
    required String bucket,
    required List<String> paths,
    Duration expiresIn = const Duration(hours: 1),
  }) async {
    if (paths.isEmpty) return [];

    final res = await http.post(
      Uri.parse('${Env.supabaseUrl}/storage/v1/object/sign/$bucket'),
      headers: _headers,
      body: jsonEncode({
        'expiresIn': expiresIn.inSeconds,
        'paths': paths,
      }),
    );
    _checkStatus(res);

    // One entry per requested path, but keyed by path rather than ordered,
    // and signedURL comes back relative to the storage endpoint.
    final signedByPath = <String, String>{};
    for (final entry in jsonDecode(res.body) as List) {
      final row = entry as Map<String, dynamic>;
      final signed = row['signedURL'] as String?;
      final path = row['path'] as String?;
      if (signed != null && path != null) {
        signedByPath[path] = '${Env.supabaseUrl}/storage/v1$signed';
      }
    }

    return [for (final p in paths) signedByPath[p]];
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      throw SupabaseException(res.statusCode, res.body);
    }
  }
}
 
class SupabaseException implements Exception {
  final int statusCode;
  final String body;
  SupabaseException(this.statusCode, this.body);
 
  @override
  String toString() => 'SupabaseException($statusCode): $body';
}