import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/models.dart';
import '../providers/group_provider.dart';
import '../providers/invite_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'group_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onViewPlanner;
  final void Function(Group) onPlanHangout;
  final VoidCallback? onViewBills;
  final VoidCallback? onViewMemories;

  const DashboardScreen({
    super.key,
    required this.onCreateGroup,
    required this.onViewPlanner,
    required this.onPlanHangout,
    this.onViewBills,
    this.onViewMemories,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  // date → list of {title, group}
  final Map<DateTime, List<Map<String, String>>> _events = {};
  bool _loadingEvents = false;

  String get _firstName {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name'] as String?
        ?? user?.email?.split('@').first
        ?? 'there';
    return name.split(' ').first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    if (_loadingEvents) return;
    final groups = context.read<GroupProvider>().groups;
    if (groups.isEmpty) return;

    setState(() => _loadingEvents = true);
    final events = <DateTime, List<Map<String, String>>>{};

    for (final group in groups) {
      try {
        final hangouts = await ApiService.instance.getGroupHangouts(group.id);
        for (final h in hangouts) {
          final plannedFor = h['planned_for'] as String?;
          if (plannedFor == null) continue;
          final dt = DateTime.parse(plannedFor).toLocal();
          final day = DateTime(dt.year, dt.month, dt.day);
          events[day] = [
            ...(events[day] ?? []),
            {'title': h['title'] as String? ?? 'Hangout', 'group': '${group.emoji} ${group.name}'},
          ];
        }
      } catch (_) {}
    }

    if (mounted) setState(() { _events.addAll(events); _loadingEvents = false; });
  }

  List<Map<String, String>> _eventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  /// Returns the next upcoming event across all days, or null.
  Map<String, String>? get _nextUpcomingEvent {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sortedDays = _events.keys
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();
    if (sortedDays.isEmpty) return null;
    final firstDay = sortedDays.first;
    final eventsOnDay = _events[firstDay];
    if (eventsOnDay == null || eventsOnDay.isEmpty) return null;
    return eventsOnDay.first;
  }

  void _showGroupPicker(BuildContext context) {
    final groups = context.read<GroupProvider>().groups;
    if (groups.isEmpty) {
      widget.onCreateGroup();
      return;
    }
    if (groups.length == 1) {
      widget.onPlanHangout(groups.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            const SizedBox(height: 16),
            const Text('Pick a group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            ...groups.map((group) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.onPlanHangout(group);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text(group.emoji, style: const TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(group.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final nextEvent = _nextUpcomingEvent;

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadGroups();
        await _loadCalendarEvents();
      },
      child: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Header(
              firstName: _firstName,
              events: _events,
              nextEvent: nextEvent,
            ),
          ),

          // ── Pending invites ────────────────────────────────────
          const _InvitesBanner(),

          // ── Quick actions grid ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    children: [
                      _ActionCard(
                        icon: Icons.group_rounded,
                        iconBg: const Color(0xFF4F46E5),
                        title: '${provider.groups.length} Groups',
                        subtitle: 'Your squads',
                        onTap: widget.onCreateGroup,
                      ),
                      _ActionCard(
                        icon: Icons.calendar_today_rounded,
                        iconBg: const Color(0xFF0EA5E9),
                        title: 'Plan Hangout',
                        subtitle: 'Schedule time together',
                        onTap: () => _showGroupPicker(context),
                      ),
                      _ActionCard(
                        icon: Icons.receipt_long_rounded,
                        iconBg: const Color(0xFF0D9488),
                        title: 'Split Bills',
                        subtitle: 'Fair & easy',
                        onTap: widget.onViewBills,
                      ),
                      _ActionCard(
                        icon: Icons.auto_stories_rounded,
                        iconBg: const Color(0xFFF59E0B),
                        title: 'Memories',
                        subtitle: 'Capture moments',
                        onTap: widget.onViewMemories,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Your Groups header ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Groups',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: widget.onCreateGroup,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                  ),
                ],
              ),
            ),
          ),

          if (provider.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.error != null)
            SliverFillRemaining(
              child: _ErrorState(
                message: provider.error!,
                onRetry: provider.loadGroups,
              ),
            )
          else if (provider.groups.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(onCreateGroup: widget.onCreateGroup),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupCard(
                      group: provider.groups[i],
                      onTap: widget.onViewPlanner,
                    ),
                  ),
                  childCount: provider.groups.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Quick action card ──────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero header ────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String firstName;
  final Map<DateTime, List<Map<String, String>>> events;
  final Map<String, String>? nextEvent;

  const _Header({
    required this.firstName,
    required this.events,
    this.nextEvent,
  });

  void _showCalendar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CalendarDialog(events: events),
    );
  }

  void _showNotifications(BuildContext context) {
    final provider = context.read<InviteProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationPanel(provider: provider),
    );
  }

  String get _avatarInitial {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name'] as String?
        ?? user?.email ?? '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final inviteCount = context.watch<InviteProvider>().pendingCount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey, $firstName! 👋',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ready to plan your next hangout?',
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Bell notification button
              GestureDetector(
                onTap: () => _showNotifications(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 22),
                      if (inviteCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$inviteCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Calendar button
              GestureDetector(
                onTap: () => _showCalendar(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month,
                      color: Colors.white, size: 22),
                ),
              ),
              // Profile avatar button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _avatarInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ── Upcoming event pill ──────────────────────────────
          if (nextEvent != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_rounded,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Up next',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          nextEvent!['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      nextEvent!['group'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Notification panel bottom sheet ────────────────────────────
class _NotificationPanel extends StatelessWidget {
  final InviteProvider provider;
  const _NotificationPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<InviteProvider>(
        builder: (context, p, _) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.notifications, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (p.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${p.pendingCount} new',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (p.loading)
                const Center(child: CircularProgressIndicator())
              else if (p.pendingInvites.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No new notifications',
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                ...p.pendingInvites.map(
                  (invite) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InviteCard(invite: invite, provider: p),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Calendar popup dialog ──────────────────────────────────────
class _CalendarDialog extends StatefulWidget {
  final Map<DateTime, List<Map<String, String>>> events;
  const _CalendarDialog({required this.events});

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Map<String, String>> _eventsForDay(DateTime day) {
    return widget.events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _eventsForDay(_selectedDay);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Your Schedule',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            TableCalendar(
              firstDay: DateTime(2024),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _eventsForDay,
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              }),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppTheme.green,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
            ),
            if (selectedEvents.isNotEmpty) ...[
              const Divider(),
              ...selectedEvents.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 4, height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['title']!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(e['group']!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.mutedForeground)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ] else ...[
              const SizedBox(height: 8),
              const Text('No events on this day.',
                  style: TextStyle(color: AppTheme.mutedForeground)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Group card ─────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left gradient accent strip
            Container(
              width: 4,
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Emoji bubble
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(group.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (group.myRole == 'admin')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Member count badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_rounded,
                                  size: 11,
                                  color: AppTheme.mutedForeground),
                              const SizedBox(width: 3),
                              Text(
                                group.members.isEmpty
                                    ? 'Just you'
                                    : '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (group.members.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _MemberAvatarStack(members: group.members),
                    ],
                  ],
                ),
              ),
            ),
            // Arrow + manage
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(group: group),
                      ),
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          size: 15, color: AppTheme.mutedForeground),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppTheme.mutedForeground),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stacked member avatars ──────────────────────────────────────
class _MemberAvatarStack extends StatelessWidget {
  final List<GroupMember> members;
  const _MemberAvatarStack({required this.members});

  @override
  Widget build(BuildContext context) {
    const max = 4;
    final visible = members.take(max).toList();
    final overflow = members.length - max;

    return SizedBox(
      height: 26,
      child: Stack(
        children: [
          ...List.generate(visible.length, (i) {
            final member = visible[i];
            final color = AppTheme.memberColors[i % AppTheme.memberColors.length];
            return Positioned(
              left: i * 18.0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    member.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (overflow > 0)
            Positioned(
              left: visible.length * 18.0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateGroup;
  const _EmptyState({required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4F46E5).withOpacity(0.12),
                    const Color(0xFF0EA5E9).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No groups yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create a group and invite your friends to start planning hangouts together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedForeground,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreateGroup,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create your first group'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.mutedForeground),
            const SizedBox(height: 16),
            const Text('Could not load groups',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.mutedForeground)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pending invites banner ─────────────────────────────────────
class _InvitesBanner extends StatelessWidget {
  const _InvitesBanner();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InviteProvider>();
    if (provider.pendingInvites.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${provider.pendingCount} pending invite${provider.pendingCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...provider.pendingInvites.map(
              (invite) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InviteCard(invite: invite, provider: provider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatefulWidget {
  final Map<String, dynamic> invite;
  final InviteProvider provider;
  const _InviteCard({required this.invite, required this.provider});

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  bool _loading = false;

  Future<void> _respond(bool accept) async {
    setState(() => _loading = true);
    final ok = await widget.provider.respond(widget.invite['id'] as String, accept);
    if (ok && accept && mounted) {
      context.read<GroupProvider>().loadGroups();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.invite['groups'] as Map<String, dynamic>? ?? {};
    final invitedBy = widget.invite['profiles'] as Map<String, dynamic>? ?? {};
    final groupName = group['name'] as String? ?? 'a group';
    final groupEmoji = group['emoji'] as String? ?? '🎉';
    final inviterName = invitedBy['display_name'] as String? ?? 'Someone';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(groupEmoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(groupName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$inviterName invited you',
                    style: const TextStyle(fontSize: 12, color: AppTheme.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_loading)
            const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            GestureDetector(
              onTap: () => _respond(false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Decline',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _respond(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Accept',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
