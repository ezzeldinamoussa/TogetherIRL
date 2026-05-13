import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class ApiService {
  static final ApiService _i = ApiService._();
  ApiService._();
  static ApiService get instance => _i;

  String get _base => AppConfig.apiBaseUrl;

  Future<Map<String, String>> get _headers async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Profiles ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyProfile() async {
    final res = await http.get(
      Uri.parse('$_base/api/profiles/me'),
      headers: await _headers,
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$_base/api/profiles/me'),
      headers: await _headers,
      body: jsonEncode(data),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Groups ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyGroups() async {
    final res = await http.get(
      Uri.parse('$_base/api/groups'),
      headers: await _headers,
    );
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> createGroup(String name, String emoji, {String? description}) async {
    final res = await http.post(
      Uri.parse('$_base/api/groups'),
      headers: await _headers,
      body: jsonEncode({'name': name, 'emoji': emoji, 'description': description}),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroup(String groupId) async {
    final res = await http.get(
      Uri.parse('$_base/api/groups/$groupId'),
      headers: await _headers,
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> inviteMember(String groupId, String email) async {
    final res = await http.post(
      Uri.parse('$_base/api/groups/$groupId/invite'),
      headers: await _headers,
      body: jsonEncode({'email': email}),
    );
    _check(res);
  }

  Future<void> leaveGroup(String groupId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/groups/$groupId/leave'),
      headers: await _headers,
    );
    _check(res);
  }

  // ── Hangouts ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGroupHangouts(String groupId) async {
    final res = await http.get(
      Uri.parse('$_base/api/hangouts/group/$groupId'),
      headers: await _headers,
    );
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> getHangout(String hangoutId) async {
    final res = await http.get(
      Uri.parse('$_base/api/hangouts/$hangoutId'),
      headers: await _headers,
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> submitPreferences(String hangoutId, Map<String, dynamic> prefs) async {
    final res = await http.put(
      Uri.parse('$_base/api/hangouts/$hangoutId/preferences'),
      headers: await _headers,
      body: jsonEncode(prefs),
    );
    _check(res);
  }

  Future<Map<String, dynamic>> getAllPreferences(String hangoutId) async {
    final res = await http.get(
      Uri.parse('$_base/api/hangouts/$hangoutId/preferences'),
      headers: await _headers,
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteHangout(String hangoutId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/hangouts/$hangoutId'),
      headers: await _headers,
    );
    _check(res);
  }

  Future<void> deleteGroup(String groupId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/groups/$groupId'),
      headers: await _headers,
    );
    _check(res);
  }

  Future<void> updateHangoutStatus(String hangoutId, String status) async {
    final res = await http.patch(
      Uri.parse('$_base/api/hangouts/$hangoutId/status'),
      headers: await _headers,
      body: jsonEncode({'status': status}),
    );
    _check(res);
  }

  Future<Map<String, dynamic>> createHangout(String groupId, {String? title, String? plannedFor}) async {
    final res = await http.post(
      Uri.parse('$_base/api/hangouts'),
      headers: await _headers,
      body: jsonEncode({
        'group_id': groupId,
        'title': title ?? 'Hangout',
        if (plannedFor != null) 'planned_for': plannedFor,
      }),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Invites ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingInvites() async {
    final res = await http.get(
      Uri.parse('$_base/api/invites/pending'),
      headers: await _headers,
    );
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<void> respondToInvite(String inviteId, bool accept) async {
    final res = await http.post(
      Uri.parse('$_base/api/invites/$inviteId/respond'),
      headers: await _headers,
      body: jsonEncode({'accept': accept}),
    );
    _check(res);
  }

  // ── Photo sessions ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final res = await http.get(
      Uri.parse('$_base/api/photos/active'),
      headers: await _headers,
    );
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> getPhotoSession(String sessionId) async {
    final res = await http.get(
      Uri.parse('$_base/api/photos/sessions/$sessionId'),
      headers: await _headers,
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPhotoSession(String groupId, String title) async {
    final res = await http.post(
      Uri.parse('$_base/api/photos/sessions'),
      headers: await _headers,
      body: jsonEncode({'group_id': groupId, 'title': title}),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> uploadSessionPhotos(String sessionId, List<String> base64Photos) async {
    final res = await http.post(
      Uri.parse('$_base/api/photos/sessions/$sessionId/upload'),
      headers: await _headers,
      body: jsonEncode({'photos': base64Photos}),
    );
    _check(res);
  }

  Future<void> skipPhotoSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('$_base/api/photos/sessions/$sessionId/skip'),
      headers: await _headers,
    );
    _check(res);
  }

  Future<void> undoPhotoAction(String sessionId) async {
    final res = await http.post(
      Uri.parse('$_base/api/photos/sessions/$sessionId/undo'),
      headers: await _headers,
    );
    _check(res);
  }

  // ── Bill scanning ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> scanBill(String base64Image) async {
    final res = await http.post(
      Uri.parse('$_base/api/bills/scan'),
      headers: await _headers,
      body: jsonEncode({'image': base64Image}),
    );
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['items'] ?? []);
  }

  // ── Bills ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGroupBills(String groupId) async {
    final res = await http.get(
      Uri.parse('$_base/api/bills/group/$groupId'),
      headers: await _headers,
    );
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> getBill(String billId) async {
    final res = await http.get(
      Uri.parse('$_base/api/bills/$billId'),
      headers: await _headers,
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBill(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$_base/api/bills'),
      headers: await _headers,
      body: jsonEncode(data),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateBill(String billId, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$_base/api/bills/$billId'),
      headers: await _headers,
      body: jsonEncode(data),
    );
    _check(res);
  }

  Future<void> deleteBill(String billId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/bills/$billId'),
      headers: await _headers,
    );
    _check(res);
  }

  void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'Request failed (${res.statusCode})');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
