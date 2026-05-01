import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'src/config/env.dart';
import 'src/controllers/profiles.dart';
import 'src/controllers/groups.dart';
import 'src/controllers/invites.dart';
//import 'src/controllers/voice.dart';
import 'src/controllers/hangout.dart';
import 'src/controllers/websocket.dart';

void main() async {
  Env.load();
  final port = int.parse(Env.port);

  final app = Router();

  app.mount('/api/profiles', ProfilesController().router);
  app.mount('/api/groups',   GroupsController().router);
  app.mount('/api/invites',  InvitesController().router);
  //app.mount('/api/voice',    VoiceController().router);
  app.mount('/api/hangouts', HangoutController().router);  // ← new

  app.get('/health', (Request req) => Response.ok(
    '{"status":"ok","timestamp":"${DateTime.now().toIso8601String()}"}',
    headers: {'Content-Type': 'application/json'},
  ));

  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addMiddleware(_jsonContentType())
      .addHandler(app);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  server.autoCompress = true;

  print('''
  ╔══════════════════════════════════════════╗
  ║   Hangout Backend (Dart) on port $port   ║
  ╚══════════════════════════════════════════╝

  Profiles:  http://localhost:$port/api/profiles
  Groups:    http://localhost:$port/api/groups
  Invites:   http://localhost:$port/api/invites
  Hangouts:  http://localhost:$port/api/hangouts
  Voice:     http://localhost:$port/api/voice
  Health:    http://localhost:$port/health
  WebSocket: ws://localhost:$port/ws
  ''');
}

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