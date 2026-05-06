// ─────────────────────────────────────────────────────────────
// bill_screen.dart  –  Bill splitting screen
// Mirrors the React <BillSplitter> component
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sample_data.dart';
import '../providers/bill_provider.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class BillScreen extends StatelessWidget {
  const BillScreen({super.key});

  // Bill splitter members (index matches memberColors)
  static final _members = sampleMembers.sublist(1, 5); // Alex, Jordan, Sam, Casey

  @override
  Widget build(BuildContext context) {
    final bill = context.watch<BillProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Upload / scan banner ─────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Scan Receipt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Enter Manually'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Items list ───────────────────────────────────────
          const SectionTitle('Items'),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: bill.items.map((item) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          // Item info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  '\$${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: AppTheme.mutedForeground,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          // Member checkboxes
                          Row(
                            children: _members.asMap().entries.map((entry) {
                              final i = entry.key;
                              final member = entry.value;
                              final selected =
                                  item.selectedBy.contains(member.id);
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 6),
                                child: GestureDetector(
                                  onTap: () =>
                                      bill.toggleItem(item.id, member.id),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppTheme.memberColors[i]
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? AppTheme.memberColors[i]
                                            : AppTheme.border,
                                        width: 2,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        member.name[0],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : AppTheme.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Member legend ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _members.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: AppTheme.memberColors[i],
                      child: Text(m.name[0],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                    const SizedBox(width: 4),
                    Text(m.name,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Tip selector ─────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Tip'),
                  const SizedBox(height: 12),
                  Row(
                    children: [15, 18, 20, 25].map((pct) {
                      final selected = bill.tipPercent == pct;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => bill.setTip(pct),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$pct%',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Totals ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TotalRow('Subtotal',
                      '\$${bill.subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  _TotalRow('Tip (${bill.tipPercent}%)',
                      '\$${bill.tipAmount.toStringAsFixed(2)}'),
                  const Divider(height: 16),
                  _TotalRow(
                    'Total',
                    '\$${bill.grandTotal.toStringAsFixed(2)}',
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Per-person breakdown ──────────────────────────────
          const SectionTitle('Per Person'),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _members.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  final total = bill.memberTotal(m.id);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        MemberAvatar(name: m.name, colorIndex: i),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(m.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
        ],
      );
}
