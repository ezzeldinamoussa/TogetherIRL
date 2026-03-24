// ─────────────────────────────────────────────────────────────
// planner_screen.dart  –  Day itinerary view
// Mirrors the React <DayPlanner> component
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/sample_data.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final totalDistance = sampleItinerary.fold<double>(
      0,
      (sum, s) => sum + double.parse(s.distance.replaceAll(' mi', '')),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          const Text(
            'Your Perfect Day Plan ✨',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const SubTitle('Optimized for your group\'s preferences'),
          const SizedBox(height: 16),

          // ── Summary bar ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryStat(
                    icon: Icons.place,
                    label: 'Total distance',
                    value: '${totalDistance.toStringAsFixed(1)} mi',
                  ),
                  _SummaryStat(
                    icon: Icons.attach_money,
                    label: 'Est. budget',
                    value: r'$35–45',
                  ),
                  _SummaryStat(
                    icon: Icons.schedule,
                    label: 'Duration',
                    value: '~5 hrs',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Itinerary stops ──────────────────────────────────
          const SectionTitle('Today\'s Itinerary'),
          const SizedBox(height: 12),

          ...sampleItinerary.asMap().entries.map((entry) {
            final i = entry.key;
            final stop = entry.value;
            final isLast = i == sampleItinerary.length - 1;
            return Column(
              children: [
                _ItineraryCard(stop: stop, index: i),
                // Connector line between stops
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 28),
                        Container(
                          width: 2,
                          height: 24,
                          color: AppTheme.border,
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.directions_walk,
                            size: 14, color: AppTheme.mutedForeground),
                        const SizedBox(width: 4),
                        SubTitle(sampleItinerary[i + 1].distance + ' walk'),
                      ],
                    ),
                  ),
              ],
            );
          }),

          const SizedBox(height: 24),

          // ── Action buttons ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('Start Navigation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Regenerate Plan'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Summary stat widget ────────────────────────────────────────
class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          SubTitle(label),
        ],
      );
}

// ── Itinerary stop card ────────────────────────────────────────
class _ItineraryCard extends StatelessWidget {
  final dynamic stop;
  final int index;

  const _ItineraryCard({required this.stop, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: NetImage(stop.imageUrl),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge + match score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppBadge(stop.type, color: AppTheme.primary),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${stop.matchScore}% match',
                        style: const TextStyle(
                          color: AppTheme.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Name
                Text(
                  stop.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),

                // Details row
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Detail(Icons.schedule, stop.time),
                    _Detail(Icons.timer_outlined, stop.duration),
                    _Detail(Icons.place_outlined, stop.distance),
                    _Detail(Icons.attach_money, stop.priceRange),
                    _Detail(Icons.star, stop.rating.toString()),
                  ],
                ),
                const SizedBox(height: 8),
                SubTitle(stop.address),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Detail(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.mutedForeground),
          const SizedBox(width: 3),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.mutedForeground)),
        ],
      );
}
