import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/group_provider.dart';
import '../providers/hangout_provider.dart';
import '../theme.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  Group? _selectedGroup;

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
          // ── Group selector ─────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Planning for',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedForeground)),
                const SizedBox(height: 8),
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
                                  ? AppTheme.primary
                                  : AppTheme.secondary,
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
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
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
          const Divider(height: 1),

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
              icon: const Icon(Icons.add),
              label: const Text('New Hangout'),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
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
      case 'collecting_preferences': return 'Collecting responses';
      case 'planning': return 'Planning';
      case 'confirmed': return 'Confirmed';
      case 'completed': return 'Completed';
      default: return hangout['status'] ?? '';
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hangout['title'] ?? 'Hangout',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (hangout['planned_for'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 12, color: AppTheme.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(hangout['planned_for'] as String),
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.mutedForeground),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: AppTheme.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  'Tap to view & submit preferences',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.mutedForeground),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: AppTheme.mutedForeground),
              ],
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

// ── Hangout detail + preferences ───────────────────────────────
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
  // Preferences form state
  String? _budget;
  final Set<String> _activities = {};
  final Set<String> _foods = {};
  final _notesController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  static const _budgets = ['\$', '\$\$', '\$\$\$'];
  static const _activityOptions = [
    'Food', 'Coffee', 'Dessert', 'Activities', 'Shopping', 'Nightlife'
  ];
  static const _foodOptions = [
    'Italian', 'Mexican', 'Asian', 'American', 'Mediterranean',
    'Korean', 'Thai', 'Indian', 'Mediterranean', 'BBQ',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _deleteHangout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Hangout?'),
        content: const Text('This will permanently delete this hangout and all preferences. This cannot be undone.'),
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
      await context.read<HangoutProvider>().deleteHangout(
          widget.hangout['id'] as String, widget.group.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final prefs = <String, dynamic>{
        if (_budget != null) 'budget_range': _budget,
        if (_activities.isNotEmpty) 'activity_types': _activities.toList(),
        if (_foods.isNotEmpty) 'food_preferences': _foods.toList(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      };
      await context
          .read<HangoutProvider>()
          .submitPreferences(
              widget.hangout['id'] as String, widget.group.id, prefs);
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hangout = widget.hangout;
    final status = hangout['status'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(hangout['title'] ?? 'Hangout'),
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
          // ── Status banner ──────────────────────────────────────
          _StatusBanner(status: status),
          const SizedBox(height: 20),

          // ── Preferences form ───────────────────────────────────
          if (status == 'collecting_preferences') ...[
            if (_submitted)
              _SuccessBanner(onEdit: () => setState(() => _submitted = false))
            else ...[
              const Text('Your Preferences',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Tell the group what you\'re feeling.',
                style: TextStyle(color: AppTheme.mutedForeground),
              ),
              const SizedBox(height: 20),

              // Budget
              const Text('Budget',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: _budgets.map((b) {
                  final sel = _budget == b;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _budget = b),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.primary
                              : AppTheme.secondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? AppTheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          b,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: sel ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Activity types
              _ChipSelector(
                title: 'Activity Types',
                options: _activityOptions,
                selected: _activities,
                onToggle: (v) => setState(() =>
                    _activities.contains(v)
                        ? _activities.remove(v)
                        : _activities.add(v)),
              ),
              const SizedBox(height: 20),

              // Food preferences
              _ChipSelector(
                title: 'Food Preferences',
                options: _foodOptions,
                selected: _foods,
                onToggle: (v) => setState(() =>
                    _foods.contains(v)
                        ? _foods.remove(v)
                        : _foods.add(v)),
              ),
              const SizedBox(height: 20),

              // Notes
              const Text('Notes (optional)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Anywhere but that Thai place please...',
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 13)),
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
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Preferences',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Preferences are locked once planning begins.',
                style: TextStyle(color: AppTheme.mutedForeground),
              ),
            ),
          ],
        ],
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
            const Text('🗓️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('No hangouts planned yet',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Create a hangout and let everyone submit their preferences.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mutedForeground),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create a Hangout'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
