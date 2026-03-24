// ─────────────────────────────────────────────────────────────
// dashboard_screen.dart  –  Home / overview screen
// Mirrors the React <Dashboard> component
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/sample_data.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onViewPlanner;

  const DashboardScreen({
    super.key,
    required this.onCreateGroup,
    required this.onViewPlanner,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome header ──────────────────────────────────
          const Text(
            'Welcome back! 👋',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const SubTitle('Plan your next adventure or revisit amazing memories'),
          const SizedBox(height: 20),

          // ── Quick stats ─────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: const [
              StatCard(label: 'Total Hangouts', value: '12', icon: Icons.calendar_today),
              StatCard(label: 'Active Groups', value: '2', icon: Icons.group),
              StatCard(label: 'Money Saved', value: r'$240', icon: Icons.attach_money),
              StatCard(label: 'Places Visited', value: '36', icon: Icons.place),
            ],
          ),
          const SizedBox(height: 24),

          // ── Your groups ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Your Groups'),
              ElevatedButton.icon(
                onPressed: onCreateGroup,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Group'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...sampleGroups.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GroupCard(group: group, onTap: onViewPlanner),
              )),

          const SizedBox(height: 8),

          // ── Recent memories ──────────────────────────────────
          const SectionTitle('Recent Memories'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                children: [imgBrunch, imgCoffee, imgIceCream]
                    .map((url) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: NetImage(url),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Group list card ───────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final dynamic group; // Group model
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            // Thumbnail
            if (group.imageUrl != null)
              SizedBox(
                width: 90,
                height: 90,
                child: NetImage(group.imageUrl!, fit: BoxFit.cover),
              ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SubTitle('${group.members.length} members'),
                    const SizedBox(height: 6),
                    if (group.nextHangout != null)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 12, color: AppTheme.mutedForeground),
                          const SizedBox(width: 4),
                          AppBadge('Next: ${group.nextHangout}'),
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
}
