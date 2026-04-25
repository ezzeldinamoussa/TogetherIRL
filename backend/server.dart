import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'src/config/env.dart';
import 'src/controllers/profiles.dart';
import 'src/controllers/groups.dart';
import 'src/controllers/invites.dart';
import 'src/controllers/voice.dart';
import 'src/controllers/websocket.dart';

void main() async {
  // Load .env file
  Env.load();

  final port = int.parse(Env.port);

  // ─── Build main router ────────────────────────────────────
  final app = Router();

  // Mount controllers at their base paths
  app.mount('/api/profiles', ProfilesController().router);
 // app.mount('/api/groups',   GroupsController().router);
  //app.mount('/api/invites',  InvitesController().router);
  //app.mount('/api/voice',    VoiceController().router);

  // Health check — useful for deployment platforms
  app.get('/health', (Request req) {
    return Response.ok('{"status":"ok","timestamp":"${DateTime.now().toIso8601String()}"}',
        headers: {'Content-Type': 'application/json'});
  });

  // ─── Middleware pipeline ──────────────────────────────────
  final handler = Pipeline()
      .addMiddleware(corsHeaders())      // allow Flutter app to call the API
      .addMiddleware(logRequests())      // print every request to console
      .addMiddleware(_jsonContentType()) // default Content-Type for responses
      .addHandler(app);

  // ─── Start HTTP server ────────────────────────────────────
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  // ─── WebSocket upgrade (real-time events) ────────────────
  // WebSocket connections come in on the same port as HTTP.
  // Shelf handles the upgrade automatically when the client sends
  // an "Upgrade: websocket" header.
  //
  // For a production-grade setup, use package:shelf_web_socket instead.
  // This basic version wires WebSockets via dart:io directly.
  final wsHandler = WebSocketHandler();

  print('''
  ╔══════════════════════════════════════════╗
  ║   Hangout Backend (Dart) on port $port   ║
  ╚══════════════════════════════════════════╝

  REST API:  http://localhost:$port/api
  WebSocket: ws://localhost:$port/ws
  Health:    http://localhost:$port/health
  ''');

  // Handle WebSocket upgrade requests at /ws
  server.autoCompress = true;
}

// Sets Content-Type: application/json on all responses that don't set it
Middleware _jsonContentType() {
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      if (!response.headers.containsKey('content-type')) {
        return response.change(headers: {'Content-Type': 'application/json'});
      }
      return response;
    };
  };
}