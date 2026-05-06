import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

class TableTalkAudioService {
  Room? _room;

  Room? get room => _room;

  bool get isConnected => _room != null;

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> connect({
    required String username,
    String roomName = 'tabletalk-room',
  }) async {
    final granted = await requestMicrophonePermission();

    if (!granted) {
      throw Exception('Microphone permission denied');
    }

    final response = await http.post(
      Uri.parse('http://10.0.2.2:8001/token'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'room': roomName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get LiveKit token: ${response.body}');
    }

    final data = jsonDecode(response.body);

    final liveKitUrl = data['url'];
    final token = data['token'];

    if (liveKitUrl == null || token == null) {
      throw Exception('Missing LiveKit URL or token from backend.');
    }

    _room = Room();

    await _room!.connect(
      liveKitUrl,
      token,
    );

    await _room!.localParticipant?.setMicrophoneEnabled(true);
  }

  Future<void> disconnect() async {
    await _room?.localParticipant?.setMicrophoneEnabled(false);
    await _room?.disconnect();
    _room = null;
  }

  Future<void> setMicEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  void setParticipantMuted({
    required String participantIdentity,
    required bool muted,
  }) {
    final room = _room;
    if (room == null) return;

    final participant = room.remoteParticipants[participantIdentity];
    if (participant == null) return;

    for (final publication in participant.audioTrackPublications) {
      final track = publication.track;
      if (track == null) continue;

      track.mediaStreamTrack.enabled = !muted;
    }
  }

  void setParticipantVolume({
    required String participantIdentity,
    required double volume,
  }) {
    final shouldMute = volume <= 0.0;

    setParticipantMuted(
      participantIdentity: participantIdentity,
      muted: shouldMute,
    );
  }
}