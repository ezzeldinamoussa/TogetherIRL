// ─────────────────────────────────────────────────────────────
// scrapbook_screen.dart  –  Memory scrapbook
// Mirrors the React <Scrapbook> component
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/sample_data.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class ScrapbookScreen extends StatelessWidget {
  const ScrapbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          const Text(
            'Memory Scrapbook 📔',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const SubTitle('Relive your favorite hangouts and memories'),
          const SizedBox(height: 16),

          // ── Stats ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        Text('12',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w700)),
                        SubTitle('Total Hangouts'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        Text('156',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w700)),
                        SubTitle('Photos Shared'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Hangout cards ────────────────────────────────────
          ...sampleHangouts.map((hangout) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _HangoutCard(hangout: hangout),
              )),

          // ── Premium upsell ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Unlock Premium Features',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    AppBadge('PRO', color: AppTheme.purple),
                  ],
                ),
                const SizedBox(height: 4),
                const SubTitle('Get the most out of your memories'),
                const SizedBox(height: 12),
                ...[
                  'Unlimited scrapbook memories',
                  'Create groups with 10+ members',
                  'Order printed photo books',
                  'Priority support & early features',
                ].map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.purple,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(feature, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.purple),
                    child: const Text('Upgrade to Premium'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Hangout memory card ────────────────────────────────────────
class _HangoutCard extends StatelessWidget {
  final dynamic hangout;
  const _HangoutCard({required this.hangout});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hangout.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 12,
                              color: AppTheme.mutedForeground),
                          const SizedBox(width: 4),
                          SubTitle(hangout.date),
                        ],
                      ),
                    ],
                  ),
                ),
                AppBadge(hangout.group),
              ],
            ),
            const SizedBox(height: 8),

            // Stars
            Row(
              children: List.generate(
                hangout.rating,
                (_) => const Icon(Icons.star,
                    size: 16, color: AppTheme.yellow),
              ),
            ),
            const SizedBox(height: 12),

            // Photo grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              children: (hangout.photoUrls as List<String>)
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: NetImage(url),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Quick stats
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickStat(Icons.attach_money,
                      '\$${hangout.totalSpent.toStringAsFixed(2)}', 'Spent'),
                  _QuickStat(
                      Icons.place, '${hangout.places}', 'Places'),
                  _QuickStat(Icons.group, '4', 'Friends'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Highlights
            const Text('Highlights',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            ...(hangout.highlights as List<String>).map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: AppTheme.primary)),
                      Expanded(
                          child: Text(h,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.mutedForeground))),
                    ],
                  ),
                )),
            const SizedBox(height: 10),

            // Food review
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Food Review',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(hangout.foodReview,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedForeground)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chevron_right, size: 16),
                label: const Text('View Full Memory'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _QuickStat(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.mutedForeground),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          SubTitle(label),
        ],
      );
}
