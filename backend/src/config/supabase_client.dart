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
      if (onConflict != null) {
        headers['Prefer'] += ',on_conflict=$onConflict';
      }
    }
 
    final uri = Uri.parse('$_baseUrl/$table');
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
    return '${Env.supabaseUrl}/storage/v1/object/public/$bucket/$path';
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