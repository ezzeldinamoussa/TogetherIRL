// ─────────────────────────────────────────────────────────────
// scrapbook_screen.dart  –  Memories
//
// Two sections:
//   1. Active photo collection window — 24 hrs from midnight of
//      the hangout day. Shows each member's upload status so
//      everyone knows who's still pending.
//   2. Past memories — completed hangout scrapbook entries.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/sample_data.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class ScrapbookScreen extends StatefulWidget {
  const ScrapbookScreen({super.key});

  @override
  State<ScrapbookScreen> createState() => _ScrapbookScreenState();
}

class _ScrapbookScreenState extends State<ScrapbookScreen> {
  // Local copy so tapping Done/Skip updates the UI immediately
  late PhotoCollection _collection;

  @override
  void initState() {
    super.initState();
    _collection = sampleActiveCollection;
  }

  void _markSelf(UploadStatus status) {
    setState(() {
      _collection.memberStatuses['1'] = status; // '1' = You
    });
  }

  String _deadline(DateTime d) =>
      'Closes ${_monthName(d.month)} ${d.day} at midnight';

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    final selfStatus = _collection.memberStatuses['1'] ?? UploadStatus.pending;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Active collection window ───────────────────────────
          _ActiveCollectionCard(
            collection: _collection,
            selfStatus: selfStatus,
            deadline: _deadline(_collection.deadline),
            onUpload: () => _markSelf(UploadStatus.done),
            onSkip: () => _markSelf(UploadStatus.skipped),
            onUndone: () => _markSelf(UploadStatus.pending),
          ),

          const SizedBox(height: 28),

          // ── Past memories ──────────────────────────────────────
          const SizedBox(height: 4),

          Row(
            children: [
              Expanded(
                child: _StatCard(value: '12', label: 'Total Hangouts'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(value: '156', label: 'Photos Shared'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...sampleHangouts.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _HangoutCard(hangout: h),
            ),
          ),

          // ── Premium upsell ────────────────────────────────────
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
                ].map(
                  (f) => Padding(
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
                        Text(f, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
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

// ─────────────────────────────────────────────────────────────
// Active collection card
// ─────────────────────────────────────────────────────────────
class _ActiveCollectionCard extends StatelessWidget {
  final PhotoCollection collection;
  final UploadStatus selfStatus;
  final String deadline;
  final VoidCallback onUpload;
  final VoidCallback onSkip;
  final VoidCallback onUndone;

  const _ActiveCollectionCard({
    required this.collection,
    required this.selfStatus,
    required this.deadline,
    required this.onUpload,
    required this.onSkip,
    required this.onUndone,
  });

  @override
  Widget build(BuildContext context) {
    final responded = collection.totalResponded;
    final total = collection.members.length;
    final allDone = collection.allResponded;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.hangoutTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        AppBadge(collection.groupName,
                            color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${collection.hangoutDate.month}/'
                          '${collection.hangoutDate.day}/'
                          '${collection.hangoutDate.year}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedForeground),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Progress pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allDone
                      ? AppTheme.green.withValues(alpha: 0.12)
                      : AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  allDone
                      ? 'Complete!'
                      : '$responded / $total responded',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: allDone ? AppTheme.green : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule,
                  size: 13, color: AppTheme.mutedForeground),
              const SizedBox(width: 4),
              Text(
                deadline,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.mutedForeground),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ── Member status list ────────────────────────────────
          const Text(
            'Upload status',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          ...collection.members.asMap().entries.map((e) {
            final idx = e.key;
            final member = e.value;
            final status =
                collection.memberStatuses[member.id] ?? UploadStatus.pending;
            final isYou = member.id == '1';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  MemberAvatar(
                      name: member.name, colorIndex: idx, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isYou ? 'You' : member.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  _StatusChip(status: status),
                ],
              ),
            );
          }),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ── Your action ───────────────────────────────────────
          if (selfStatus == UploadStatus.pending) ...[
            const Text(
              'Your turn',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Upload photos'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("I don't have photos"),
                  ),
                ),
              ],
            ),
          ] else if (selfStatus == UploadStatus.done) ...[
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppTheme.green, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You\'ve uploaded your photos',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: onUndone,
                  child: const Text('Undo'),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.remove_circle_outline,
                    color: AppTheme.mutedForeground, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You skipped this collection',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: onUndone,
                  child: const Text('Undo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status chip shown next to each member
// ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final UploadStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case UploadStatus.done:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, size: 15, color: AppTheme.green),
          const SizedBox(width: 4),
          Text('Done',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.green)),
        ]);
      case UploadStatus.skipped:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.remove_circle_outline,
              size: 15, color: AppTheme.mutedForeground),
          const SizedBox(width: 4),
          Text('Skipped',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.mutedForeground)),
        ]);
      case UploadStatus.pending:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.schedule,
              size: 15, color: AppTheme.mutedForeground),
          const SizedBox(width: 4),
          Text('Pending',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.mutedForeground)),
        ]);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Small stat card
// ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700)),
            SubTitle(label),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Past hangout memory card
// ─────────────────────────────────────────────────────────────
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hangout.title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 12,
                            color: AppTheme.mutedForeground),
                        const SizedBox(width: 4),
                        SubTitle(hangout.date),
                      ]),
                    ],
                  ),
                ),
                AppBadge(hangout.group),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                hangout.rating,
                (_) => const Icon(Icons.star,
                    size: 16, color: AppTheme.yellow),
              ),
            ),
            const SizedBox(height: 12),
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
                  _QuickStat(Icons.group,
                      '${(hangout.photoUrls as List).length}', 'Friends'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Highlights',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            ...(hangout.highlights as List<String>).map(
              (h) => Padding(
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
                              color: AppTheme.mutedForeground)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
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
