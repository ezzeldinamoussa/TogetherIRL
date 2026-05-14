// ─────────────────────────────────────────────────────────────
// table_talk_screen.dart  –  TableTalk real-time voice mixer
//
// Concept: everyone at the table wears earbuds. This screen lets
// you independently boost or lower each person's voice — like a
// personal mixing board for a live conversation.  A Discord-style
// per-user mute is included so you can cut a single voice entirely.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/table_talk_audio_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vibration/vibration.dart';

// ── Data model for a TableTalk participant ────────────────────
class _Participant {
  final String name;
  final Color color;
  final Color colorAlt;
  double volume;   // 0.0 – 1.5  (150 % max, like Discord's boost)
  bool muted;

  _Participant({
    required this.name,
    required this.color,
    required this.colorAlt,
    this.volume = 1.0,
    this.muted = false,
  });

  String get initials => name[0].toUpperCase();
}

// ─────────────────────────────────────────────────────────────
class TableTalkScreen extends StatefulWidget {
  final String groupName;
  final String venueName;

  const TableTalkScreen({
    super.key,
    this.groupName = 'Your Group',
    this.venueName = 'Current Venue',
  });

  @override
  State<TableTalkScreen> createState() => _TableTalkScreenState();
}

class _TableTalkScreenState extends State<TableTalkScreen>
    with TickerProviderStateMixin {
<<<<<<< HEAD
  // ── Your own mic state ──────────────────────────────────────
  bool _selfMuted = false;

  // ── Participants (everyone else at the table) ───────────────
  final List<_Participant> _participants = [
    _Participant(
        name: 'Alex',
        color: Color(0xFF3B82F6),
        colorAlt: Color(0xFF1D4ED8),
        volume: 1.0),
    _Participant(
        name: 'Jordan',
        color: Color(0xFF8B5CF6),
        colorAlt: Color(0xFF6D28D9),
        volume: 1.3),
    _Participant(
        name: 'Sam',
        color: Color(0xFF22C55E),
        colorAlt: Color(0xFF15803D),
        volume: 0.6,
        muted: true),
    _Participant(
        name: 'Casey',
        color: Color(0xFFF97316),
        colorAlt: Color(0xFFC2410C),
        volume: 1.0),
=======
  final TableTalkAudioService _audioService = TableTalkAudioService();

  bool _isConnectedToAudio = false;
  bool _isConnectingToAudio = false;

  bool _selfMuted = false;
  bool _hasLeft = false;
  String? _username;
  IO.Socket? _socket;

  double _foregroundVolume = 1.0;
  double _backgroundVolume = 0.5;
  bool _foregroundMuted = false;
  bool _backgroundMuted = false;

  // Participants are no longer hardcoded.
  // This list gets filled with real LiveKit remote participants after joining.
  final List<_Participant> _participants = [];

  // Used to give each real participant a different avatar color.
  final List<Color> _participantColors = const [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
>>>>>>> audio
  ];

  // ── Animation controllers ───────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

<<<<<<< HEAD
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
=======
@override
void initState() {
  super.initState();

  _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
    CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
  );

  // Starts listening for nudge notifications from the backend.
  _setupNudgeSocket();
}

@override
void dispose() {
  // Remove the room listener before disconnecting so the screen
  // does not try to update after it has already been closed.
  _audioService.room?.removeListener(_roomListener);

  // Stop listening to nudge socket events when leaving this screen.
  _socket?.off('receive_nudge');
  _socket?.off('nudge_sent');
  _socket?.off('nudge_failed');
  _socket?.disconnect();

  _pulseCtrl.dispose();
  _audioService.disconnect();
  super.dispose();
}

void _setupNudgeSocket() {
  _socket = IO.io(
    'https://togetherirl.onrender.com',
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build(),
  );

  _socket!.connect();

  _socket!.onConnect((_) {
    debugPrint('Nudge socket connected');
  });

  _socket!.on('receive_nudge', (data) async {
    final hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator == true) {
      Vibration.vibrate(duration: 300);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${data['fromUser']} wants to talk to you'),
      ),
    );
  });

  _socket!.on('nudge_sent', (data) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(data['message'] ?? 'Nudge sent.'),
      ),
    );
  });

  _socket!.on('nudge_failed', (data) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(data['message'] ?? 'Nudge failed.'),
      ),
    );
  });
}

Future<String?> _askForUsername() async {
  final controller = TextEditingController(text: _username ?? '');

  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Join TableTalk'),

      // Username input field
      content: TextField(
        controller: controller,
        autofocus: true,

        // Lets the enter key submit properly
        textInputAction: TextInputAction.done,

        decoration: const InputDecoration(
          labelText: 'Your name',
          hintText: 'Enter your name',
        ),

        // Handles pressing enter on the keyboard
        onSubmitted: (value) {
          final typedName = value.trim();

          if (typedName.isEmpty) return;

          Navigator.pop(context, typedName);
        },
      ),

      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),

        // Join button
        ElevatedButton(
          onPressed: () {
            final typedName = controller.text.trim();

            if (typedName.isEmpty) return;

            Navigator.pop(context, typedName);
          },
          child: const Text('Join'),
        ),
      ],
    ),
  );

  return name;
}
  // ── Audio helpers ────────────────────────────────────────────
 Future<void> _connectAudio() async {
  // Ask the user for a name before joining.
  // If they already entered one before, reuse it.
  final username = _username ?? await _askForUsername();

  // User cancelled the popup.
  if (username == null || username.trim().isEmpty) {
    return;
  }

  setState(() {
    _username = username.trim();
    _isConnectingToAudio = true;
  });

  try {
    await _audioService.connect(
    username: _username!,
    roomName: 'tabletalk-room',
  );

    _socket?.emit('register', {
    'username': _username,
    'room': 'tabletalk-room',
  });
    // Pull the current LiveKit participant list once after joining.
    _syncParticipantsFromLiveKit();

    // Listen for LiveKit room changes.
    // This lets the UI update when someone joins, leaves, or publishes audio.
    _audioService.room?.addListener(_roomListener);

    setState(() {
      _isConnectedToAudio = true;
      _selfMuted = false;
      _hasLeft = false;
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not connect to TableTalk audio: $e'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isConnectingToAudio = false;
      });
    }
  }
}

  Future<void> _disconnectAudio() async {
    // Stop listening to LiveKit room updates before disconnecting.
    _audioService.room?.removeListener(_roomListener);

    await _audioService.disconnect();

    if (!mounted) return;

    setState(() {
      _isConnectedToAudio = false;
      _selfMuted = false;
      _participants.clear();
    });
  }

  Future<void> _toggleSelfMute() async {
    final newMutedValue = !_selfMuted;

    await _audioService.setMicEnabled(!newMutedValue);

    setState(() {
      _selfMuted = newMutedValue;
    });
  }

  // This runs whenever LiveKit says the room changed.
  // It keeps the UI participant list synced with the actual voice room.
  void _roomListener() {
  // Prevents updates after the widget has been disposed
    if (!mounted) return;

  // Refresh participant list from LiveKit
    _syncParticipantsFromLiveKit();
}

  void _syncParticipantsFromLiveKit() {
    if (!mounted) return;
    final liveKitNames = _audioService.getParticipantNames();

    setState(() {
      for (final name in liveKitNames) {
        final alreadyExists = _participants.any((p) => p.name == name);

        if (!alreadyExists) {
          final color =
              _participantColors[_participants.length % _participantColors.length];

          _participants.add(
            _Participant(
              name: name,
              color: color,
              volume: _backgroundVolume,
              group: _VoiceGroup.background,
            ),
          );
        }
      }

      // Remove people from the UI if they are no longer in the LiveKit room.
      _participants.removeWhere(
        (p) => !liveKitNames.contains(p.name),
      );
    });
  }

  // ── Mixer helpers ────────────────────────────────────────────
  void _toggleMute(int index) {
    setState(() {
      _participants[index].muted = !_participants[index].muted;
    });

    _audioService.setParticipantMuted(
      participantIdentity: _participants[index].name,
      muted: _participants[index].muted,
>>>>>>> audio
    );
  }

  void _setIndividualVolume(int index, double v) {
    setState(() {
      _participants[index].volume = v;
    });

    _audioService.setParticipantVolume(
      participantIdentity: _participants[index].name,
      volume: v,
    );
  }

<<<<<<< HEAD
  // ── Helpers ─────────────────────────────────────────────────
  void _toggleMute(int index) =>
      setState(() => _participants[index].muted = !_participants[index].muted);

  void _setVolume(int index, double v) =>
      setState(() => _participants[index].volume = v);
=======
  // When the group slider moves, scale all participants in that group proportionally
  // so their individual sliders react visually.
  void _setGroupVolume(bool isForeground, double newVol) {
    final oldVol = isForeground ? _foregroundVolume : _backgroundVolume;
    final targetGroup =
        isForeground ? _VoiceGroup.foreground : _VoiceGroup.background;

    setState(() {
      if (isForeground) {
        _foregroundVolume = newVol;
      } else {
        _backgroundVolume = newVol;
      }

      for (final p in _participants) {
        if (p.group != targetGroup) continue;

        if (oldVol < 0.001) {
          // Was at zero — restore individuals to the new group value
          p.volume = newVol.clamp(0.0, 1.5);
        } else {
          p.volume = (p.volume * newVol / oldVol).clamp(0.0, 1.5);
        }

        _audioService.setParticipantVolume(
          participantIdentity: p.name,
          volume: p.volume,
        );
      }
    });
  }

  void _toggleGroupMute(bool isForeground) {
    final targetGroup =
        isForeground ? _VoiceGroup.foreground : _VoiceGroup.background;

    setState(() {
      if (isForeground) {
        _foregroundMuted = !_foregroundMuted;
      } else {
        _backgroundMuted = !_backgroundMuted;
      }
    });

    final shouldMute = isForeground ? _foregroundMuted : _backgroundMuted;

    for (final p in _participants) {
      if (p.group != targetGroup) continue;

      _audioService.setParticipantMuted(
        participantIdentity: p.name,
        muted: shouldMute,
      );
    }
  }

  void _moveToForeground(int index) {
  setState(() {
    _participants[index].group = _VoiceGroup.foreground;
    _participants[index].volume = _foregroundVolume;
  });

  _audioService.setParticipantVolume(
    participantIdentity: _participants[index].name,
    volume: _foregroundMuted ? 0.0 : _foregroundVolume,
  );
}

void _moveToBackground(int index) {
  setState(() {
    _participants[index].group = _VoiceGroup.background;
    _participants[index].volume = _backgroundVolume;
  });

  _audioService.setParticipantVolume(
    participantIdentity: _participants[index].name,
    volume: _backgroundMuted ? 0.0 : _backgroundVolume,
  );
}

  List<MapEntry<int, _Participant>> get _foregroundList => _participants
      .asMap()
      .entries
      .where((e) => e.value.group == _VoiceGroup.foreground)
      .toList();

  List<MapEntry<int, _Participant>> get _backgroundList => _participants
      .asMap()
      .entries
      .where((e) => e.value.group == _VoiceGroup.background)
      .toList();
>>>>>>> audio

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildParticipantList()),
          _buildSelfCard(context),
        ],
      ),
    );
  }

<<<<<<< HEAD
  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
=======
  // ── Left state ───────────────────────────────────────────────
  Widget _buildLeftState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context, dimmed: true),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_end,
                      size: 56, color: AppTheme.mutedForeground),
                  const SizedBox(height: 16),
                  const Text(
                    'You left the session',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Others are still connected.',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.mutedForeground),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _connectAudio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Rejoin Session'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header — session info chip only, no title bar ────────────
  Widget _buildHeader(BuildContext context, {bool dimmed = false}) {
>>>>>>> audio
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
<<<<<<< HEAD
        left: 20,
        right: 20,
        bottom: 24,
=======
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: session info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.venueName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!dimmed && _isConnectedToAudio)
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Opacity(
                            opacity: _pulseAnim.value,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dimmed || !_isConnectedToAudio
                                ? Colors.grey
                                : const Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        dimmed
                            ? 'Disconnected'
                            : _isConnectingToAudio
                                ? 'Connecting...'
                                : _isConnectedToAudio
                                    ? 'Live · ${_participants.length + 1} connected'
                                    : 'Not connected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right: mic + leave controls
            if (!dimmed) ...[
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _isConnectedToAudio ? _toggleSelfMute : _connectAudio,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _selfMuted
                            ? Colors.red.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isConnectedToAudio
                            ? (_selfMuted ? Icons.mic_off : Icons.mic)
                            : Icons.mic_none,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _confirmLeave(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _isConnectedToAudio ? 'Leave' : 'Join',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────
  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        _buildGroupBox(isForeground: true),
        const SizedBox(height: 16),
        _buildGroupBox(isForeground: false),
      ],
    );
  }

  // ── Group box — header + slider + participant tiles inside ────
  Widget _buildGroupBox({required bool isForeground}) {
    final label = isForeground ? 'Foreground' : 'Background';
    final subtitle = isForeground
        ? 'People you want to hear clearly'
        : 'Others at the table — lower volume by default';
    final volume = isForeground ? _foregroundVolume : _backgroundVolume;
    final groupMuted = isForeground ? _foregroundMuted : _backgroundMuted;
    final participants = isForeground ? _foregroundList : _backgroundList;

    return Container(
      decoration: BoxDecoration(
        color: isForeground
            ? AppTheme.primary.withValues(alpha: 0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isForeground
              ? AppTheme.primary.withValues(alpha: 0.25)
              : AppTheme.border,
        ),
>>>>>>> audio
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back + title + overflow
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 18),
                ),
              ),
              const Expanded(
                child: Text(
                  'TableTalk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // LIVE badge with animated red pulse
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: _pulseAnim.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
<<<<<<< HEAD
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
=======
                    // Group mute button
                    GestureDetector(
                      onTap: _isConnectedToAudio
                          ? () => _toggleGroupMute(isForeground)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: groupMuted
                              ? AppTheme.destructive.withValues(alpha: 0.1)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              groupMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              size: 14,
                              color: groupMuted
                                  ? AppTheme.destructive
                                  : AppTheme.mutedForeground,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              groupMuted ? 'Unmute' : 'Mute',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: groupMuted
                                    ? AppTheme.destructive
                                    : AppTheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
>>>>>>> audio
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Session info card
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
<<<<<<< HEAD
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
=======
                    Expanded(
                      child: Slider(
                        value: groupMuted ? 0.0 : volume,
                        min: 0.0,
                        max: 1.5,
                        divisions: 30,
                        activeColor: AppTheme.primary,
                        onChanged: groupMuted || !_isConnectedToAudio
                            ? null
                            : (v) => _setGroupVolume(isForeground, v),
>>>>>>> audio
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.venueName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Connected count chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_participants.length + 1} connected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
<<<<<<< HEAD
=======

          // ── Participant tiles inside the box ──────────────────
          if (participants.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Text(
                isForeground
                    ? 'Tap "Foreground" on someone in the Background group'
                    : _isConnectedToAudio
                        ? 'Waiting for others to join...'
                        : 'Join audio to see people at the table',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.mutedForeground,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: participants
                    .map(
                      (e) => _ParticipantTile(
                        key: ValueKey(e.value.name),
                        participant: e.value,
                        onMuteToggle: () => _toggleMute(e.key),
                        onVolumeChanged: (v) =>
                            _setIndividualVolume(e.key, v),
                        onGroupToggle: isForeground
                            ? () => _moveToBackground(e.key)
                            : () => _moveToForeground(e.key),
                        onNudge: () => _sendNudge(e.value.name),
                        isInForeground: isForeground,
                        enabled: _isConnectedToAudio,
                      ),
                    )
                    .toList(),
              ),
            ),
>>>>>>> audio
        ],
      ),
    );
  }

<<<<<<< HEAD
  // ── Participant list ─────────────────────────────────────────
  Widget _buildParticipantList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Mixer',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Adjust each person\'s volume independently',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._participants.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ParticipantTile(
              participant: e.value,
              onMuteToggle: () => _toggleMute(e.key),
              onVolumeChanged: (v) => _setVolume(e.key, v),
            ),
          ),
        ),
      ],
    );
  }

  // ── Self mic card at the bottom ──────────────────────────────
  Widget _buildSelfCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Row(
            children: [
              const Text(
                'Your Microphone',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedForeground,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _selfMuted
                      ? AppTheme.destructive.withValues(alpha: 0.1)
                      : AppTheme.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selfMuted ? 'Muted' : 'Live',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _selfMuted
                        ? AppTheme.destructive
                        : AppTheme.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // You avatar with gradient
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Y',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      'Tap to toggle your mic',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedForeground),
                    ),
                  ],
                ),
              ),
              // Mute toggle button
              GestureDetector(
                onTap: () => setState(() => _selfMuted = !_selfMuted),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selfMuted
                        ? AppTheme.destructive
                        : AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selfMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selfMuted ? 'Unmute' : 'Mute',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // End session button
              GestureDetector(
                onTap: () => _confirmEnd(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.destructive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.destructive.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'End',
                    style: TextStyle(
                      color: AppTheme.destructive,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── End session confirmation ─────────────────────────────────
  Future<void> _confirmEnd(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End TableTalk session?'),
        content: const Text(
          'Everyone will be disconnected. You can start a new session anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructive,
              foregroundColor: Colors.white,
            ),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
    }
=======
// ── Leave confirmation ───────────────────────────────────────
Future<void> _confirmLeave(BuildContext context) async {
  if (!_isConnectedToAudio) {
    await _connectAudio();
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Leave session?'),
      content: const Text(
        'Others will stay connected. You can rejoin anytime.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.destructive,
            foregroundColor: Colors.white,
          ),
          child: const Text('Leave'),
        ),
      ],
    ),
  );

  if (confirmed == true && mounted) {
    await _disconnectAudio();
    setState(() => _hasLeft = true);
>>>>>>> audio
  }
}

void _sendNudge(String toUser) {
  if (_username == null) return;

  _socket?.emit('send_nudge', {
    'room': 'tabletalk-room',
    'fromUser': _username,
    'toUser': toUser,
  });
}
    }
// ─────────────────────────────────────────────────────────────
// _ParticipantTile  –  one card in the voice mixer
// ─────────────────────────────────────────────────────────────
class _ParticipantTile extends StatelessWidget {
  final _Participant participant;
  final VoidCallback onMuteToggle;
  final ValueChanged<double> onVolumeChanged;
<<<<<<< HEAD
=======
  final VoidCallback onGroupToggle;
  final VoidCallback onNudge;
  final bool isInForeground;
  final bool enabled;
>>>>>>> audio

  const _ParticipantTile({
    required this.participant,
    required this.onMuteToggle,
    required this.onVolumeChanged,
<<<<<<< HEAD
=======
    required this.onGroupToggle,
    required this.onNudge,
    required this.isInForeground,
    required this.enabled,
>>>>>>> audio
  });

  // Color shifts green→yellow→red as volume increases past 100%
  Color _volumeColor(double v) {
    if (v <= 1.0) return AppTheme.green;
    if (v <= 1.25) return const Color(0xFFF59E0B);
    return AppTheme.destructive;
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = participant.muted;
    final pct = '${(participant.volume * 100).round()}%';

<<<<<<< HEAD
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Large gradient avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: isMuted
                      ? LinearGradient(
                          colors: [
                            participant.color.withValues(alpha: 0.3),
                            participant.colorAlt.withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [participant.color, participant.colorAlt],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
=======
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isMuted
                            ? p.color.withValues(alpha: 0.35)
                            : p.color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          p.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
>>>>>>> audio
                        ),
                  shape: BoxShape.circle,
                  boxShadow: isMuted
                      ? null
                      : [
                          BoxShadow(
                            color: participant.color.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    participant.initials,
                    style: TextStyle(
                      color: isMuted
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
<<<<<<< HEAD
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isMuted
                            ? AppTheme.mutedForeground
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMuted ? 'muted' : 'speaking',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isMuted
                            ? AppTheme.destructive
                            : AppTheme.green,
=======

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isMuted
                              ? AppTheme.mutedForeground
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),

                    // Group toggle
                    GestureDetector(
                      onTap: widget.enabled ? widget.onGroupToggle : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isInForeground
                              ? Colors.grey.shade100
                              : AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isInForeground
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 11,
                              color: widget.isInForeground
                                  ? AppTheme.mutedForeground
                                  : AppTheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.isInForeground
                                  ? 'Background'
                                  : 'Foreground',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.isInForeground
                                    ? AppTheme.mutedForeground
                                    : AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Nudge button
                    GestureDetector(
                      onTap: widget.enabled ? widget.onNudge : null,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Per-person mute
                    GestureDetector(
                      onTap: widget.enabled ? widget.onMuteToggle : null,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isMuted
                              ? AppTheme.destructive.withValues(alpha: 0.1)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isMuted ? Icons.volume_off : Icons.volume_up,
                          size: 16,
                          color: isMuted
                              ? AppTheme.destructive
                              : AppTheme.mutedForeground,
                        ),
>>>>>>> audio
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Expand/collapse
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

<<<<<<< HEAD
              // Volume percentage
              Text(
                isMuted ? '--' : pct,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isMuted
                      ? AppTheme.mutedForeground
                      : _volumeColor(participant.volume),
                ),
              ),
              const SizedBox(width: 10),

              // Mute toggle button — clear on/off state
              GestureDetector(
                onTap: onMuteToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isMuted
                        ? AppTheme.destructive
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 20,
                    color: isMuted ? Colors.white : AppTheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),

          // Custom thin volume slider
          Padding(
            padding: const EdgeInsets.only(left: 66, right: 0, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: isMuted
                        ? AppTheme.mutedForeground.withValues(alpha: 0.2)
                        : _volumeColor(participant.volume),
                    inactiveTrackColor: const Color(0xFFE2E8F0),
                    thumbColor: isMuted
                        ? AppTheme.mutedForeground.withValues(alpha: 0.3)
                        : _volumeColor(participant.volume),
                    overlayColor: _volumeColor(participant.volume)
                        .withValues(alpha: 0.12),
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: isMuted ? 0.0 : participant.volume,
                    min: 0.0,
                    max: 1.5,
                    divisions: 30,
                    onChanged: isMuted ? null : onVolumeChanged,
                  ),
                ),
                // Volume scale labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0%',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.mutedForeground
                                  .withValues(alpha: 0.6))),
                      Text('100%',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.mutedForeground
                                  .withValues(alpha: 0.6))),
                      Text('150%',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.mutedForeground
                                  .withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
=======
              // Fine-tune slider
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Text(
                        'Fine-tune',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: isMuted ? 0.0 : p.volume,
                          min: 0.0,
                          max: 1.5,
                          divisions: 30,
                          activeColor: AppTheme.primary,
                          onChanged: isMuted || !widget.enabled
                              ? null
                              : widget.onVolumeChanged,
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        child: Text(
                          isMuted ? 'muted' : pct,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isMuted
                                ? AppTheme.destructive
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
>>>>>>> audio
      ),
    );
  }
}