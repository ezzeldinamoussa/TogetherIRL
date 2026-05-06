// ─────────────────────────────────────────────────────────────
// table_talk_screen.dart  –  TableTalk real-time voice mixer
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/table_talk_audio_service.dart';

enum _VoiceGroup { foreground, background }

class _Participant {
  final String name;
  final Color color;
  double volume; // 0.0 – 1.5; updated proportionally when group slider moves
  bool muted;
  _VoiceGroup group;

  _Participant({
    required this.name,
    required this.color,
    this.volume = 1.0,
    this.muted = false,
    this.group = _VoiceGroup.background,
  });

  String get initials => name[0].toUpperCase();
}

// ─────────────────────────────────────────────────────────────
class TableTalkScreen extends StatefulWidget {
  final String groupName;
  final String venueName;

  const TableTalkScreen({
    super.key,
    this.groupName = 'College Squad',
    this.venueName = 'The Corner Cafe',
  });

  @override
  State<TableTalkScreen> createState() => _TableTalkScreenState();
}

class _TableTalkScreenState extends State<TableTalkScreen>
    with TickerProviderStateMixin {
  final TableTalkAudioService _audioService = TableTalkAudioService();

  bool _isConnectedToAudio = false;
  bool _isConnectingToAudio = false;

  bool _selfMuted = false;
  bool _hasLeft = false;

  double _foregroundVolume = 1.0;
  double _backgroundVolume = 0.5;
  bool _foregroundMuted = false;
  bool _backgroundMuted = false;

  // All participants start in Background by default
  final List<_Participant> _participants = [
    _Participant(name: 'Alex', color: Color(0xFF3B82F6)),
    _Participant(name: 'Jordan', color: Color(0xFF8B5CF6)),
    _Participant(name: 'Sam', color: Color(0xFF22C55E)),
    _Participant(name: 'Casey', color: Color(0xFFF97316)),
  ];

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _audioService.disconnect();
    super.dispose();
  }

  // ── Audio helpers ────────────────────────────────────────────
  Future<void> _connectAudio() async {
    setState(() {
      _isConnectingToAudio = true;
    });

    try {
      await _audioService.connect(
        username: 'Alex',
        roomName: 'tabletalk-room',
      );

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
    await _audioService.disconnect();

    if (!mounted) return;

    setState(() {
      _isConnectedToAudio = false;
      _selfMuted = false;
    });
  }

  Future<void> _toggleSelfMute() async {
    final newMutedValue = !_selfMuted;

    await _audioService.setMicEnabled(!newMutedValue);

    setState(() {
      _selfMuted = newMutedValue;
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

  void _moveToForeground(int index) =>
      setState(() => _participants[index].group = _VoiceGroup.foreground);

  void _moveToBackground(int index) =>
      setState(() => _participants[index].group = _VoiceGroup.background);

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

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_hasLeft) return _buildLeftState(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dimmed
              ? [Colors.grey.shade400, Colors.grey.shade600]
              : const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Group header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      ),
                    ),
                  ],
                ),
                // Group volume slider
                Row(
                  children: [
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
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        groupMuted ? 'muted' : '${(volume * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: groupMuted
                              ? AppTheme.destructive
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),

          // ── Participant tiles inside the box ──────────────────
          if (participants.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Text(
                isForeground
                    ? 'Tap "Foreground" on someone in the Background group'
                    : 'Everyone is in the foreground',
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
                        isInForeground: isForeground,
                        enabled: _isConnectedToAudio,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

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
            'Others will stay connected. You can rejoin anytime.'),
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
    }
  }
}

// ─────────────────────────────────────────────────────────────
// _ParticipantTile — collapsed by default; expands on chevron
// tap to reveal the individual fine-tune slider.
// ─────────────────────────────────────────────────────────────
class _ParticipantTile extends StatefulWidget {
  final _Participant participant;
  final VoidCallback onMuteToggle;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onGroupToggle;
  final bool isInForeground;
  final bool enabled;

  const _ParticipantTile({
    super.key,
    required this.participant,
    required this.onMuteToggle,
    required this.onVolumeChanged,
    required this.onGroupToggle,
    required this.isInForeground,
    required this.enabled,
  });

  @override
  State<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<_ParticipantTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.participant;
    final isMuted = p.muted;
    final pct = '${(p.volume * 100).round()}%';

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
              // ── Collapsed row ─────────────────────────────────
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
                        ),
                      ),
                    ),
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
                            horizontal: 8, vertical: 5),
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
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Expand/collapse fine-tune
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

              // ── Fine-tune slider (expanded only) ──────────────
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
      ),
    );
  }
}