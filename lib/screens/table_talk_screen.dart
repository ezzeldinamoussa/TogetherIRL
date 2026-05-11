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
  double volume;   // 0.0 – 1.5  (150 % max, like Discord's boost)
  bool muted;

  _Participant({
    required this.name,
    required this.color,
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
    _Participant(name: 'Alex',   color: Color(0xFF3B82F6), volume: 1.0),
    _Participant(name: 'Jordan', color: Color(0xFF8B5CF6), volume: 1.3),
    _Participant(name: 'Sam',    color: Color(0xFF22C55E), volume: 0.6, muted: true),
    _Participant(name: 'Casey',  color: Color(0xFFF97316), volume: 1.0),
  ];

  // ── Animation controller for the "Live" pulse dot ──────────
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildParticipantList()),
          _buildSelfBar(context),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back + title + overflow
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const Expanded(
                child: Text(
                  'TableTalk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white70),
                onPressed: () {},
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Session info chip area
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
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
                // Live indicator
                Row(
                  children: [
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
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live · ${_participants.length + 1} connected',
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
        ],
      ),
    );
  }

  // ── Participant list ─────────────────────────────────────────
  Widget _buildParticipantList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      children: [
        const Text(
          'Adjust voices',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Drag sliders to boost or reduce each person\'s voice',
          style: TextStyle(fontSize: 12, color: AppTheme.mutedForeground),
        ),
        const SizedBox(height: 16),
        ..._participants.asMap().entries.map(
          (e) => _ParticipantTile(
            participant: e.value,
            onMuteToggle: () => _toggleMute(e.key),
            onVolumeChanged: (v) => _setVolume(e.key, v),
          ),
        ),
      ],
    );
  }

  // ── Your own bottom bar ──────────────────────────────────────
  Widget _buildSelfBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          // You avatar
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'Y',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  _selfMuted ? 'mic off' : 'mic on',
                  style: TextStyle(
                    fontSize: 12,
                    color: _selfMuted
                        ? AppTheme.destructive
                        : AppTheme.green,
                  ),
                ),
              ],
            ),
          ),
          // Mute self
          OutlinedButton.icon(
            onPressed: () => setState(() => _selfMuted = !_selfMuted),
            icon: Icon(
              _selfMuted ? Icons.mic_off : Icons.mic,
              size: 16,
              color: _selfMuted ? AppTheme.destructive : null,
            ),
            label: Text(_selfMuted ? 'Unmute' : 'Mute'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  _selfMuted ? AppTheme.destructive : const Color(0xFF0F172A),
              side: BorderSide(
                color: _selfMuted ? AppTheme.destructive : AppTheme.border,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          // End session
          ElevatedButton(
            onPressed: () => _confirmEnd(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructive,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('End'),
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
// _ParticipantTile  –  one row in the voice mixer
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

  @override
  Widget build(BuildContext context) {
    final isMuted = participant.muted;
    final pct = '${(participant.volume * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isMuted
                      ? participant.color.withValues(alpha: 0.35)
                      : participant.color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    participant.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  participant.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isMuted ? AppTheme.mutedForeground : const Color(0xFF0F172A),
                    decoration: isMuted ? TextDecoration.none : null,
                  ),
                ),
              ),

              // Volume percentage label
              SizedBox(
                width: 42,
                child: Text(
                  isMuted ? 'muted' : pct,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMuted
                        ? AppTheme.destructive
                        : _volumeColor(participant.volume),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mute toggle button
              GestureDetector(
                onTap: onMuteToggle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isMuted
                        ? AppTheme.destructive.withValues(alpha: 0.1)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    size: 18,
                    color: isMuted ? AppTheme.destructive : AppTheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),

          // Volume slider
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 0, top: 4),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: isMuted
                    ? AppTheme.mutedForeground.withValues(alpha: 0.3)
                    : _volumeColor(participant.volume),
                inactiveTrackColor: AppTheme.border,
                thumbColor: isMuted
                    ? AppTheme.mutedForeground.withValues(alpha: 0.4)
                    : _volumeColor(participant.volume),
                overlayColor:
                    _volumeColor(participant.volume).withValues(alpha: 0.15),
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: isMuted ? 0.0 : participant.volume,
                min: 0.0,
                max: 1.5,
                divisions: 30,
                onChanged: isMuted ? null : onVolumeChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Color shifts green→yellow→red as volume increases past 100 %
  Color _volumeColor(double v) {
    if (v <= 1.0) return AppTheme.green;
    if (v <= 1.25) return const Color(0xFFF59E0B); // amber
    return AppTheme.destructive;
  }
}
