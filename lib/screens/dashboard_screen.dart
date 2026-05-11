import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/models.dart';
import '../providers/group_provider.dart';
import '../providers/hangout_provider.dart';
import '../providers/invite_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'group_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onViewPlanner;

  const DashboardScreen({
    super.key,
    required this.onCreateGroup,
    required this.onViewPlanner,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadGroups();
        await _loadCalendarEvents();
      },
      child: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────
          SliverToBoxAdapter(child: _Header(firstName: _firstName, events: _events)),

          // ── Pending invites ────────────────────────────────────
          const _InvitesBanner(),

          // ── Stats row ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.group,
                    label: '${provider.groups.length} Groups',
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.calendar_today,
                    label: 'Plan a hangout',
                    color: AppTheme.green,
                  ),
                ],
              ),
            ),
          ),

          // ── Your Groups ────────────────────────────────────────
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

// ── Hero header ────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String firstName;
  final Map<DateTime, List<Map<String, String>>> events;
  const _Header({required this.firstName, required this.events});

  void _showCalendar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CalendarDialog(events: events),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
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
          GestureDetector(
            onTap: () => _showCalendar(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
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

// ── Stat chip ──────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
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
        child: Row(
          children: [
            // Emoji bubble
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(group.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (group.myRole == 'admin')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.members.isEmpty
                        ? 'Just you for now'
                        : '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  if (group.members.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MemberAvatarStack(members: group.members),
                  ],
                ],
              ),
            ),
            // Manage button
            IconButton(
              icon: const Icon(Icons.person_add_outlined, size: 20),
              color: AppTheme.mutedForeground,
              tooltip: 'Manage group',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: group),
                ),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No groups yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a group and invite your friends to start planning hangouts together.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.mutedForeground),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create your first group'),
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
