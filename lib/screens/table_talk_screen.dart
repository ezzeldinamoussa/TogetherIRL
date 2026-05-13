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
  ];

  // ── Animation controllers ───────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────
  void _toggleMute(int index) =>
      setState(() => _participants[index].muted = !_participants[index].muted);

  void _setVolume(int index, double v) =>
      setState(() => _participants[index].volume = v);

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

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
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
        left: 20,
        right: 20,
        bottom: 24,
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
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
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
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

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
  }
}

// ─────────────────────────────────────────────────────────────
// _ParticipantTile  –  one card in the voice mixer
// ─────────────────────────────────────────────────────────────
class _ParticipantTile extends StatelessWidget {
  final _Participant participant;
  final VoidCallback onMuteToggle;
  final ValueChanged<double> onVolumeChanged;

  const _ParticipantTile({
    required this.participant,
    required this.onMuteToggle,
    required this.onVolumeChanged,
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
                      ),
                    ),
                  ],
                ),
              ),

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
      ),
    );
  }
}
