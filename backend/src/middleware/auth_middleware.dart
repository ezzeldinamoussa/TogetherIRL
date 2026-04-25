import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../config/supabase_client.dart';
 
/// Middleware that validates the Supabase JWT on every protected request.
///
/// Flutter sends: Authorization: Bearer <supabase_access_token>
///
/// On success: adds 'userId' and 'userEmail' to the request context
/// On failure: returns 401 immediately
Middleware requireAuth() {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'] ?? '';
 
      if (!authHeader.startsWith('Bearer ')) {
        return _unauthorized('Missing or malformed Authorization header');
      }
 
      final token = authHeader.substring(7); // strip "Bearer "
 
      try {
        final user = await SupabaseClient.admin.getUser(token);
        if (user == null) return _unauthorized('Invalid or expired token');
 
        // Pass user info downstream via request context
        final updatedRequest = request.change(context: {
          ...request.context,
          'userId': user['id'] as String,
          'userEmail': user['email'] as String? ?? '',
        });
 
        return innerHandler(updatedRequest);
      } on SupabaseException {
        return _unauthorized('Token validation failed');
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Auth check failed'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}
 
Response _unauthorized(String message) => Response.unauthorized(
      jsonEncode({'error': message}),
      headers: {'Content-Type': 'application/json'},
    );
 
/// Helper: extract userId that was set by requireAuth middleware
extension RequestContext on Request {
  String get userId => context['userId'] as String? ?? '';
  String get userEmail => context['userEmail'] as String? ?? '';
}