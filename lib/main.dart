import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'theme.dart';
import 'providers/bill_provider.dart';
import 'providers/photo_provider.dart';
import 'providers/group_provider.dart';
import 'providers/hangout_provider.dart';
import 'providers/invite_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/table_talk_screen.dart';
import 'screens/bill_screen.dart';
import 'screens/memories_screen.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const TogetherIRLApp());
}

class TogetherIRLApp extends StatelessWidget {
  const TogetherIRLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => HangoutProvider()),
        ChangeNotifierProvider(create: (_) => InviteProvider()),
      ],
      child: MaterialApp(
        title: 'TogetherIRL',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) return const MainShell();
        return const AuthScreen();
      },
    );
  }
}

// ── Main shell ─────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _plannerGroupTrigger = ValueNotifier<Group?>(null);

  @override
  void dispose() {
    _plannerGroupTrigger.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroups();
      final inviteProvider = context.read<InviteProvider>();
      inviteProvider.loadPendingInvites();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        inviteProvider.subscribeRealtime(userId);
        context.read<GroupProvider>().subscribeRealtime(userId);
      }
    });
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  void _showCreateGroup() {
    final provider = context.read<GroupProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateGroupSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tabs: Home · Planner · TableTalk · Bills · Memories
    final screens = [
      DashboardScreen(
        onCreateGroup: _showCreateGroup,
        onViewPlanner: () => _goToTab(1),
        onPlanHangout: (group) {
          _plannerGroupTrigger.value = group;
          _goToTab(1);
        },
        onViewBills: () => _goToTab(3),
        onViewMemories: () => _goToTab(4),
      ),
      PlannerScreen(groupTrigger: _plannerGroupTrigger),
      const TableTalkScreen(),
      const BillScreen(),
      const MemoriesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
        pendingCount: context.watch<InviteProvider>().pendingCount,
      ),
    );
  }
}

// ── Floating nav bar ───────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final int pendingCount;
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      (icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Planner'),
      (icon: Icons.mic_none_outlined, activeIcon: Icons.mic_rounded, label: 'TableTalk'),
      (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Bills'),
      (icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories_rounded, label: 'Memories'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final active = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        color: active ? Colors.white : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                      if (i == 0 && pendingCount > 0)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Re-exported here so MainShell can show the create group sheet
// without importing the full GroupScreen.
class _CreateGroupSheet extends StatefulWidget {
  final GroupProvider provider;
  const _CreateGroupSheet({required this.provider});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '🎉';
  bool _loading = false;
  String? _error;

  static const _emojis = [
    '🎉', '🍕', '🎮', '🏖️', '🍜', '☕',
    '🏕️', '🎬', '🎵', '🍔', '🥂', '🏃',
    '🎨', '🌮', '🍣', '🎭', '🧗', '🎲',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Group name is required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.provider.createGroup(name, _selectedEmoji);
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
          const Text('Create a Group',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Give your crew a name and a vibe.',
              style: TextStyle(color: AppTheme.mutedForeground)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'e.g., Friday Crew, Foodie Gang',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          const Text('Pick an emoji',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis.map((e) {
              final selected = e == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = e),
                child: Container(
                  width: 44, height: 44,                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.secondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Group', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
