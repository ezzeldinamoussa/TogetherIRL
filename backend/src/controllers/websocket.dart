import 'dart:convert';
import 'dart:io';
import '../config/supabase_client.dart';

/// Real-time WebSocket server — the Dart equivalent of Socket.io.
///
/// Flutter connects using the web_socket_channel package:
///   final channel = WebSocketChannel.connect(Uri.parse('ws://localhost:3000/ws'));
///   channel.sink.add(jsonEncode({'type': 'auth', 'token': accessToken}));
///
/// Events the server sends to clients:
///   { "type": "new_invite",    "data": { ... } }
///   { "type": "member_joined", "data": { "group_id": "...", "user_id": "..." } }
///   { "type": "error",         "data": { "message": "..." } }
///
/// Events clients send to the server:
///   { "type": "auth",         "token": "<supabase_jwt>" }
///   { "type": "join_group",   "group_id": "..." }
///   { "type": "leave_group",  "group_id": "..." }

class WebSocketHandler {
  // Map of userId → list of their open WebSocket connections
  // (a user might have multiple tabs/devices open)
  static final Map<String, List<WebSocket>> _userSockets = {};

  // Map of groupId → set of userIds in that group's real-time room
  static final Map<String, Set<String>> _groupMembers = {};

  final _db = SupabaseClient.admin;

  Future<void> handleConnection(WebSocket socket) async {
    String? authenticatedUserId;

    socket.listen(
      (dynamic message) async {
        Map<String, dynamic> event;
        try {
          event = jsonDecode(message as String) as Map<String, dynamic>;
        } catch (_) {
          _send(socket, 'error', {'message': 'Invalid JSON'});
          return;
        }

        final type = event['type'] as String?;

        switch (type) {
          // ── AUTH ──────────────────────────────────────────
          // Client must send this first before any other event.
          // { "type": "auth", "token": "<supabase_jwt>" }
          case 'auth':
            final token = event['token'] as String?;
            if (token == null) {
              _send(socket, 'error', {'message': 'Token required'});
              return;
            }
            final user = await _db.getUser(token);
            if (user == null) {
              _send(socket, 'error', {'message': 'Invalid token'});
              socket.close();
              return;
            }
            authenticatedUserId = user['id'] as String;
            _userSockets.putIfAbsent(authenticatedUserId!, () => []).add(socket);
            _send(socket, 'authenticated', {'user_id': authenticatedUserId});

          // ── JOIN GROUP ────────────────────────────────────
          // Subscribe to real-time events for a group.
          // { "type": "join_group", "group_id": "..." }
          case 'join_group':
            if (authenticatedUserId == null) {
              _send(socket, 'error', {'message': 'Authenticate first'});
              return;
            }
            final groupId = event['group_id'] as String?;
            if (groupId == null) return;

            // Verify membership
            try {
              final rows = await _db.select(
                'group_members',
                filters: {'group_id': 'eq.$groupId', 'user_id': 'eq.$authenticatedUserId', 'status': 'eq.active'},
              );
              if (rows.isEmpty) {
                _send(socket, 'error', {'message': 'Not a group member'});
                return;
              }
            } catch (_) {
              _send(socket, 'error', {'message': 'Could not verify membership'});
              return;
            }

            _groupMembers.putIfAbsent(groupId, () => {}).add(authenticatedUserId!);
            _send(socket, 'joined_group', {'group_id': groupId});

          // ── LEAVE GROUP ───────────────────────────────────
          case 'leave_group':
            final groupId = event['group_id'] as String?;
            if (groupId != null && authenticatedUserId != null) {
              _groupMembers[groupId]?.remove(authenticatedUserId);
            }

          default:
            _send(socket, 'error', {'message': 'Unknown event type: $type'});
        }
      },
      onDone: () {
        // Clean up on disconnect
        if (authenticatedUserId != null) {
          _userSockets[authenticatedUserId]?.remove(socket);
          if (_userSockets[authenticatedUserId]?.isEmpty == true) {
            _userSockets.remove(authenticatedUserId);
          }
          for (final members in _groupMembers.values) {
            members.remove(authenticatedUserId);
          }
        }
      },
      onError: (_) => socket.close(),
    );
  }

  // ─── Static broadcast helpers (call from controllers) ─────

  /// Send an event to a specific user (all their connected devices).
  static void sendToUser(String userId, String type, Map<String, dynamic> data) {
    final sockets = _userSockets[userId];
    if (sockets == null) return;
    final message = jsonEncode({'type': type, 'data': data});
    for (final socket in sockets) {
      try { socket.add(message); } catch (_) {}
    }
  }

  /// Broadcast an event to all active members of a group.
  static void broadcastToGroup(String groupId, String type, Map<String, dynamic> data) {
    final memberIds = _groupMembers[groupId];
    if (memberIds == null) return;
    for (final userId in memberIds) {
      sendToUser(userId, type, data);
    }
  }

  static void _send(WebSocket socket, String type, Map<String, dynamic> data) {
    try {
      socket.add(jsonEncode({'type': type, 'data': data}));
    } catch (_) {}
  }
}