// ─────────────────────────────────────────────────────────────
// main.dart  –  App entry point, providers, and bottom nav
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'providers/bill_provider.dart';
import 'providers/photo_provider.dart';
import 'providers/group_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/group_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/bill_screen.dart';
import 'screens/scrapbook_screen.dart';
import 'screens/table_talk_screen.dart';

void main() {
  runApp(const TogetherIRLApp());
}

class TogetherIRLApp extends StatelessWidget {
  const TogetherIRLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Register all providers here so any screen can access them
      providers: [
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
      ],
      child: MaterialApp(
        title: 'TogetherIRL',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const MainShell(),
      ),
    );
  }
}

// ── Main shell with bottom navigation ─────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Navigate to a specific tab programmatically
  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    // Screens are defined here so we can pass callbacks between them
    final screens = [
      DashboardScreen(
        onCreateGroup: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GroupScreen()),
        ),
        onViewPlanner: () => _goToTab(1),
        onViewMemories: () => _goToTab(4),
      ),
      const PlannerScreen(),
      const TableTalkScreen(),
      const BillScreen(),
      const ScrapbookScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(const [
          'TogetherIRL',
          'Planner',
          'TableTalk',
          'Bill Splitter',
          'Memories',
        ][_currentIndex]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: IndexedStack(
        // IndexedStack keeps each screen's state alive when switching tabs
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.spatial_audio_outlined),
            activeIcon: Icon(Icons.spatial_audio),
            label: 'TableTalk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Memories',
          ),
        ],
      ),
    );
  }
}
