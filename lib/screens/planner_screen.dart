import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../providers/group_provider.dart';
import '../providers/hangout_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/itinerary_plans_view.dart';

class PlannerScreen extends StatefulWidget {
  final ValueNotifier<Group?>? groupTrigger;
  const PlannerScreen({super.key, this.groupTrigger});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  Group? _selectedGroup;

  @override
  void initState() {
    super.initState();
    widget.groupTrigger?.addListener(_onGroupTrigger);
  }

  @override
  void dispose() {
    widget.groupTrigger?.removeListener(_onGroupTrigger);
    super.dispose();
  }

  void _onGroupTrigger() {
    final group = widget.groupTrigger?.value;
    if (group == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectGroup(group);
      _showCreateHangout();
      widget.groupTrigger!.value = null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-select first group and load its hangouts
    final groups = context.read<GroupProvider>().groups;
    if (_selectedGroup == null && groups.isNotEmpty) {
      _selectedGroup = groups.first;
      _loadHangouts(_selectedGroup!.id);
    }
  }

  void _loadHangouts(String groupId) {
    context.read<HangoutProvider>().loadHangouts(groupId);
  }

  void _selectGroup(Group group) {
    setState(() => _selectedGroup = group);
    _loadHangouts(group.id);
  }

  void _showCreateHangout() {
    if (_selectedGroup == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateHangoutSheet(group: _selectedGroup!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupProvider>().groups;
    final hangoutProvider = context.watch<HangoutProvider>();

    if (groups.isEmpty) {
      return const _NoGroupsState();
    }

    final hangouts = _selectedGroup != null
        ? hangoutProvider.hangoutsFor(_selectedGroup!.id)
        : <Map<String, dynamic>>[];
    final loading = _selectedGroup != null
        ? hangoutProvider.isLoading(_selectedGroup!.id)
        : false;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with Today button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planner',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Plan your next hangout',
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    // Today pill button
                    GestureDetector(
                      onTap: () {
                        // Scroll to today's hangouts by reloading
                        if (_selectedGroup != null) {
                          _loadHangouts(_selectedGroup!.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.today_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Group selector pills ──────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: groups.map((group) {
                      final selected = _selectedGroup?.id == group.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _selectGroup(group),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(group.emoji,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  group.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF4F46E5)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Hangout list ───────────────────────────────────────
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : hangouts.isEmpty
                    ? _EmptyHangoutsState(onCreateTap: _showCreateHangout)
                    : RefreshIndicator(
                        onRefresh: () =>
                            hangoutProvider.loadHangouts(_selectedGroup!.id),
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: hangouts.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _HangoutCard(
                              hangout: hangouts[i],
                              group: _selectedGroup!,
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _selectedGroup != null
          ? FloatingActionButton.extended(
              onPressed: _showCreateHangout,
              backgroundColor: const Color(0xFF4F46E5),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Hangout',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

// ── Hangout card ───────────────────────────────────────────────
class _HangoutCard extends StatelessWidget {
  final Map<String, dynamic> hangout;
  final Group group;

  const _HangoutCard({required this.hangout, required this.group});

  Color get _statusColor {
    switch (hangout['status']) {
      case 'collecting_preferences': return const Color(0xFFF59E0B);
      case 'planning': return AppTheme.primary;
      case 'confirmed': return AppTheme.green;
      case 'completed': return AppTheme.mutedForeground;
      default: return AppTheme.mutedForeground;
    }
  }

  String get _statusLabel {
    switch (hangout['status']) {
      case 'collecting_preferences': return 'Planning';
      case 'planning': return 'Planning';
      case 'confirmed': return 'Confirmed';
      case 'completed': return 'Past';
      default: return hangout['status'] ?? '';
    }
  }

  IconData get _statusIcon {
    switch (hangout['status']) {
      case 'collecting_preferences': return Icons.hourglass_top_rounded;
      case 'planning': return Icons.edit_note_rounded;
      case 'confirmed': return Icons.check_circle_rounded;
      case 'completed': return Icons.star_rounded;
      default: return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HangoutDetailScreen(
            hangout: hangout,
            group: group,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left gradient accent strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_statusColor, _statusColor.withOpacity(0.4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            hangout['title'] ?? 'Hangout',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon,
                                  size: 11, color: _statusColor),
                              const SizedBox(width: 4),
                              Text(
                                _statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Group pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${group.emoji} ${group.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hangout['planned_for'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 12,
                              color: AppTheme.mutedForeground),
                          const SizedBox(width: 5),
                          Text(
                            _formatDate(hangout['planned_for'] as String),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Action chips row
                    Row(
                      children: [
                        _ActionChip(
                          label: 'Preferences',
                          icon: Icons.tune_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HangoutDetailScreen(
                                hangout: hangout,
                                group: group,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ActionChip(
                          label: 'View',
                          icon: Icons.open_in_new_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HangoutDetailScreen(
                                hangout: hangout,
                                group: group,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ActionChip(
                          label: 'Delete',
                          icon: Icons.delete_outline_rounded,
                          isDestructive: true,
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete Hangout?'),
                                content: const Text(
                                    'This will permanently delete this hangout and all preferences.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete',
                                        style: TextStyle(
                                            color: AppTheme.destructive)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              try {
                                await context
                                    .read<HangoutProvider>()
                                    .deleteHangout(
                                      hangout['id'] as String,
                                      group.id,
                                    );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())));
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Inline action chip ─────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.destructive : AppTheme.mutedForeground;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
              color: isDestructive
                  ? AppTheme.destructive.withOpacity(0.3)
                  : AppTheme.border),
          borderRadius: BorderRadius.circular(8),
          color: isDestructive
              ? AppTheme.destructive.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create hangout sheet ───────────────────────────────────────
class _CreateHangoutSheet extends StatefulWidget {
  final Group group;
  const _CreateHangoutSheet({required this.group});

  @override
  State<_CreateHangoutSheet> createState() => _CreateHangoutSheetState();
}

class _CreateHangoutSheetState extends State<_CreateHangoutSheet> {
  final _titleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String? get _plannedFor {
    if (_selectedDate == null) return null;
    final time = _selectedTime ?? const TimeOfDay(hour: 18, minute: 0);
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      time.hour,
      time.minute,
    );
    return dt.toIso8601String();
  }

  String get _dateLabel {
    if (_selectedDate == null) return 'Pick a date';
    final d = _selectedDate!;
    return '${d.month}/${d.day}/${d.year}';
  }

  String get _timeLabel {
    if (_selectedTime == null) return 'Pick a time';
    final h = _selectedTime!.hourOfPeriod == 0 ? 12 : _selectedTime!.hourOfPeriod;
    final m = _selectedTime!.minute.toString().padLeft(2, '0');
    final period = _selectedTime!.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this hangout a title');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _error = 'Pick a date for the hangout');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context
          .read<HangoutProvider>()
          .createHangout(widget.group.id, title, plannedFor: _plannedFor);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(widget.group.emoji,
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Hangout',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    Text(widget.group.name,
                        style: const TextStyle(
                            color: AppTheme.mutedForeground, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Hangout title',
              hintText: 'e.g., Friday Night Out, Weekend Brunch',
            ),
          ),
          const SizedBox(height: 16),

          // Date + Time pickers
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedDate != null
                          ? AppTheme.primary.withOpacity(0.08)
                          : AppTheme.secondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedDate != null
                            ? AppTheme.primary.withOpacity(0.3)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16,
                            color: _selectedDate != null
                                ? AppTheme.primary
                                : AppTheme.mutedForeground),
                        const SizedBox(width: 8),
                        Text(
                          _dateLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _selectedDate != null
                                ? AppTheme.primary
                                : AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _selectedDate != null ? _pickTime : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedTime != null
                          ? AppTheme.primary.withOpacity(0.08)
                          : AppTheme.secondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedTime != null
                            ? AppTheme.primary.withOpacity(0.3)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16,
                            color: _selectedTime != null
                                ? AppTheme.primary
                                : AppTheme.mutedForeground),
                        const SizedBox(width: 8),
                        Text(
                          _timeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _selectedTime != null
                                ? AppTheme.primary
                                : AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _create,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create Hangout',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hangout detail + preferences + plans ───────────────────────
class HangoutDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hangout;
  final Group group;

  const HangoutDetailScreen({
    super.key,
    required this.hangout,
    required this.group,
  });

  @override
  State<HangoutDetailScreen> createState() => _HangoutDetailScreenState();
}

class _HangoutDetailScreenState extends State<HangoutDetailScreen> {
  // Live copy of the hangout (status / itinerary_status change on the server)
  late Map<String, dynamic> _hangout;
  Map<String, dynamic>? _itinerary;
  Timer? _pollTimer;
  bool _selecting = false;

  // Preferences form state
  double _budget = 25;
  final Set<String> _activities = {};
  final Set<String> _foods = {};
  final _notesController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  // Starting location (soft preference)
  Map<String, dynamic> _savedLocations = {};
  bool _loadingLocations = true;
  String? _locationSource; // home | school | work | current | manual
  final _manualZipController = TextEditingController();
  double? _currentLat;
  double? _currentLng;
  bool _locating = false;
  String? _locationError;

  static const double _minBudget = 25;
  static const double _maxBudget = 200;

  static const _activityOptions = [
    'Coffee & Brunch',
    'Food',
    'Dessert',
    'Entertainment',
    'Outdoors',
    'Arts & Culture',
    'Shopping',
  ];

  static const _foodOptions = [
    'Italian', 'French', 'Mexican', 'Latin American', 'Japanese', 'Chinese',
    'Vietnamese', 'Korean', 'Thai', 'American', 'Mediterranean', 'Greek',
    'Middle Eastern', 'Indian', 'No Preference'
  ];

  String get _status => _hangout['status'] as String? ?? '';
  String get _itStatus => _hangout['itinerary_status'] as String? ?? 'idle';
  bool get _isOrganizer =>
      Supabase.instance.client.auth.currentUser?.id == _hangout['created_by'];

  @override
  void initState() {
    super.initState();
    _hangout = Map<String, dynamic>.from(widget.hangout);
    _loadSavedLocations();
    if (_status != 'collecting_preferences') _loadItinerary();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _notesController.dispose();
    _manualZipController.dispose();
    super.dispose();
  }

  // ── Polling ──────────────────────────────────────────────────
  Future<void> _poll() async {
    if (!mounted) return;
    final waiting =
        (_status == 'collecting_preferences' && _submitted) || _itStatus == 'generating';
    if (!waiting) return;
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final h = await ApiService.instance.getHangout(_hangout['id'] as String);
      if (!mounted) return;
      setState(() => _hangout = {..._hangout, ...h});
      if (_status != 'collecting_preferences') await _loadItinerary();
    } catch (_) {}
  }

  Future<void> _loadItinerary() async {
    try {
      final it = await ApiService.instance.getItinerary(_hangout['id'] as String);
      if (!mounted) return;
      setState(() {
        _itinerary = it;
        _hangout = {
          ..._hangout,
          'itinerary_status': it['itinerary_status'] ?? _itStatus,
        };
      });
    } catch (_) {}
  }

  // ── Saved locations (from the profile) ───────────────────────
  Future<void> _loadSavedLocations() async {
    try {
      final profile = await ApiService.instance.getMyProfile();
      final locs = (profile['locations'] as Map?)?.cast<String, dynamic>() ?? {};
      if (!mounted) return;
      setState(() {
        _savedLocations = locs;
        for (final k in ['home', 'school', 'work']) {
          if (_locationSource == null && locs[k] != null) _locationSource = k;
        }
        _loadingLocations = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  void _pickSource(String source) {
    setState(() {
      _locationSource = source;
      _locationError = null;
    });
    if (source == 'current' && _currentLat == null) _captureCurrentLocation();
  }

  Future<void> _captureCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationError = 'Location services are turned off on this device.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Location permission was denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _locationError = 'Could not get your location. Try again or use a ZIP code.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Actions ──────────────────────────────────────────────────
  Future<void> _deleteHangout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Hangout?'),
        content: const Text(
            'This will permanently delete this hangout and all preferences. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await context
          .read<HangoutProvider>()
          .deleteHangout(widget.hangout['id'] as String, widget.group.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submit() async {
    // Validate starting location first
    final source = _locationSource;
    if (source == null) {
      setState(() => _error = 'Choose where you\'re starting from.');
      return;
    }
    if (source == 'manual' && !RegExp(r'^\d{5}$').hasMatch(_manualZipController.text.trim())) {
      setState(() => _error = 'Enter a valid 5-digit ZIP code.');
      return;
    }
    if (source == 'current' && (_currentLat == null || _currentLng == null)) {
      setState(() => _error = 'Share your current location, or pick another starting point.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final prefs = <String, dynamic>{
        'budget_range': _budget.round(),
        'location_source': source,
        if (source == 'manual') 'location_zip': _manualZipController.text.trim(),
        if (source == 'current') 'location_lat': _currentLat,
        if (source == 'current') 'location_lng': _currentLng,
        if (_activities.isNotEmpty) 'activity_types': _activities.toList(),
        if (_foods.isNotEmpty) 'food_preferences': _foods.toList(),
        if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
      };
      await context
          .read<HangoutProvider>()
          .submitPreferences(widget.hangout['id'] as String, widget.group.id, prefs);
      if (!mounted) return;
      setState(() => _submitted = true);
      await _refresh(); // picks up itinerary_status if we were the last to respond
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _selectPlan(int index) async {
    setState(() => _selecting = true);
    try {
      await ApiService.instance.selectItineraryPlan(_hangout['id'] as String, index);
      await _refresh();
      if (mounted) context.read<HangoutProvider>().loadHangouts(widget.group.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _regenerate() async {
    try {
      await ApiService.instance.generateItinerary(_hangout['id'] as String);
      if (mounted) setState(() => _hangout = {..._hangout, 'itinerary_status': 'generating'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hangout['title'] ?? 'Hangout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete hangout',
            onPressed: _deleteHangout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(status: _status),
          const SizedBox(height: 20),
          if (_status == 'collecting_preferences')
            ..._collectingSection()
          else
            ..._plansSection(),
        ],
      ),
    );
  }

  List<Widget> _plansSection() {
    if (_itStatus == 'generating') return const [PlansBuildingCard()];
    return [
      ItineraryPlansView(
        itinerary: _itinerary,
        itineraryStatus: _itStatus,
        isOrganizer: _isOrganizer,
        selecting: _selecting,
        onSelect: _selectPlan,
        onRegenerate: _regenerate,
      ),
    ];
  }

  List<Widget> _collectingSection() {
    if (_submitted) {
      return [
        _SuccessBanner(onEdit: () => setState(() => _submitted = false)),
        if (_itStatus == 'generating') ...[
          const SizedBox(height: 16),
          const PlansBuildingCard(),
        ],
        if (_itStatus == 'failed') ...[
          const SizedBox(height: 16),
          ItineraryFailedCard(isOrganizer: _isOrganizer, onRetry: _regenerate),
        ],
      ];
    }

    return [
      const Text('Your Preferences',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text(
        'Tell the group what you\'re feeling.',
        style: TextStyle(color: AppTheme.mutedForeground),
      ),
      const SizedBox(height: 20),

      // ── Starting location ──
      _buildLocationPicker(),
      const SizedBox(height: 20),

      // ── Budget ──
      const Text('Budget per person', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('For the entire hangout',
          style: TextStyle(fontSize: 12, color: AppTheme.mutedForeground)),
      const SizedBox(height: 8),
      Center(
        child: Text(
          '\$${_budget.round()}',
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary),
        ),
      ),
      Slider(
        value: _budget,
        min: _minBudget,
        max: _maxBudget,
        divisions: 35,
        label: '\$${_budget.round()}',
        activeColor: AppTheme.primary,
        onChanged: (value) => setState(() => _budget = value),
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('\$25', style: TextStyle(fontSize: 12, color: AppTheme.mutedForeground)),
          Text('\$200+', style: TextStyle(fontSize: 12, color: AppTheme.mutedForeground)),
        ],
      ),
      const SizedBox(height: 20),

      _ChipSelector(
        title: 'Activity Types',
        options: _activityOptions,
        selected: _activities,
        onToggle: (v) => setState(
            () => _activities.contains(v) ? _activities.remove(v) : _activities.add(v)),
      ),
      const SizedBox(height: 20),

      _ChipSelector(
        title: 'Food Preferences',
        options: _foodOptions,
        selected: _foods,
        onToggle: (v) =>
            setState(() => _foods.contains(v) ? _foods.remove(v) : _foods.add(v)),
      ),
      const SizedBox(height: 20),

      const Text('Notes (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: _notesController,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Anywhere but that Thai place please...'),
      ),

      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
      ],
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: AppTheme.primary,
          ),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit Preferences', style: TextStyle(fontSize: 16)),
        ),
      ),
    ];
  }

  // ── Starting-location picker ─────────────────────────────────
  Widget _buildLocationPicker() {
    const options = [
      ('home', 'Home', Icons.home_outlined),
      ('school', 'School', Icons.school_outlined),
      ('work', 'Work', Icons.work_outline),
      ('current', 'Current location', Icons.my_location),
      ('manual', 'Other ZIP', Icons.pin_drop_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Where are you starting from?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('We\'ll look for places that work for everyone\'s starting points.',
            style: TextStyle(fontSize: 12, color: AppTheme.mutedForeground)),
        const SizedBox(height: 10),
        if (_loadingLocations)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((o) {
              final key = o.$1;
              final isSaved = ['home', 'school', 'work'].contains(key);
              final saved = _savedLocations[key] as Map?;
              final disabled = isSaved && saved == null;
              return _LocationChip(
                icon: o.$3,
                label: o.$2,
                subtitle: saved?['zipcode']?.toString(),
                selected: _locationSource == key,
                disabled: disabled,
                onTap: disabled ? null : () => _pickSource(key),
              );
            }).toList(),
          ),
        if (!_loadingLocations &&
            ['home', 'school', 'work'].any((k) => _savedLocations[k] == null)) ...[
          const SizedBox(height: 6),
          const Text(
            'Greyed-out places aren\'t saved yet — add them in your Profile.',
            style: TextStyle(fontSize: 11, color: AppTheme.mutedForeground),
          ),
        ],
        if (_locationSource == 'manual') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _manualZipController,
              keyboardType: TextInputType.number,
              maxLength: 5,
              decoration: const InputDecoration(
                labelText: 'ZIP code',
                hintText: '10001',
                counterText: '',
              ),
            ),
          ),
        ],
        if (_locationSource == 'current') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (_locating)
                const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(
                  _currentLat != null ? Icons.check_circle : Icons.location_off_outlined,
                  size: 18,
                  color: _currentLat != null ? AppTheme.green : AppTheme.mutedForeground,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locating
                      ? 'Getting your location…'
                      : _currentLat != null
                          ? 'Location captured'
                          : 'Location not shared yet',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (!_locating)
                TextButton(
                  onPressed: _captureCurrentLocation,
                  child: Text(_currentLat != null ? 'Refresh' : 'Share'),
                ),
            ],
          ),
          if (_locationError != null)
            Text(_locationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ],
    );
  }
}

// ── Starting-location chip ─────────────────────────────────────
class _LocationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _LocationChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.disabled,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = disabled
        ? AppTheme.mutedForeground.withValues(alpha: 0.5)
        : selected
            ? AppTheme.primary
            : const Color(0xFF0F172A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.secondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
            if (subtitle != null && !disabled) ...[
              const SizedBox(width: 6),
              Text(subtitle!,
                  style: const TextStyle(fontSize: 11, color: AppTheme.mutedForeground)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status banner ──────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final configs = {
      'collecting_preferences': (
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFF59E0B),
        bg: const Color(0xFFFFFBEB),
        label: 'Collecting Preferences',
        sub: 'Waiting for everyone to submit their preferences.',
      ),
      'planning': (
        icon: Icons.edit_note,
        color: AppTheme.primary,
        bg: const Color(0xFFEEF2FF),
        label: 'Planning in Progress',
        sub: 'All responses are in — the organizer is finalizing the plan.',
      ),
      'confirmed': (
        icon: Icons.check_circle_outline,
        color: AppTheme.green,
        bg: const Color(0xFFF0FDF4),
        label: 'Hangout Confirmed!',
        sub: 'Everything is locked in. Get ready!',
      ),
      'completed': (
        icon: Icons.star_outline,
        color: AppTheme.mutedForeground,
        bg: AppTheme.secondary,
        label: 'Completed',
        sub: 'This hangout is done. Check Memories for the recap.',
      ),
    };

    final c = configs[status];
    if (c == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(c.icon, color: c.color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: c.color)),
                const SizedBox(height: 2),
                Text(c.sub,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.mutedForeground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success banner ─────────────────────────────────────────────
class _SuccessBanner extends StatelessWidget {
  final VoidCallback onEdit;
  const _SuccessBanner({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.green, size: 36),
          const SizedBox(height: 10),
          const Text('Preferences submitted!',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Waiting for the rest of the group to respond.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedForeground, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onEdit,
            child: const Text('Edit my preferences'),
          ),
        ],
      ),
    );
  }
}

// ── Chip selector ──────────────────────────────────────────────
class _ChipSelector extends StatelessWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _ChipSelector({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final sel = selected.contains(o);
            return GestureDetector(
              onTap: () => onToggle(o),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.primary.withOpacity(0.1)
                      : AppTheme.secondary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        sel ? AppTheme.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: sel
                        ? AppTheme.primary
                        : const Color(0xFF0F172A),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Empty states ───────────────────────────────────────────────
class _NoGroupsState extends StatelessWidget {
  const _NoGroupsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📅', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('No groups yet',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'Create a group on the Home tab first, then come back to plan a hangout.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHangoutsState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyHangoutsState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4F46E5).withOpacity(0.1),
                    const Color(0xFF0EA5E9).withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🗓️', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Nothing planned yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Create a hangout and let everyone submit their preferences.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.mutedForeground, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create a Hangout'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}