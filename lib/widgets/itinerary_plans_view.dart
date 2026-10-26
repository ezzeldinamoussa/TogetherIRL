import 'package:flutter/material.dart';
import '../theme.dart';

// ── Theme badge info ───────────────────────────────────────────
class _ThemeInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _ThemeInfo(this.label, this.icon, this.color);
}

_ThemeInfo _themeInfo(String? theme) {
  switch (theme) {
    case 'budget_friendly':
      return const _ThemeInfo('Budget-friendly', Icons.savings_outlined, Color(0xFF0D9488));
    case 'activity_packed':
      return const _ThemeInfo('Activity-packed', Icons.local_activity_outlined, Color(0xFFF59E0B));
    case 'closest':
      return const _ThemeInfo('Easiest to reach', Icons.near_me_outlined, Color(0xFF0EA5E9));
    default:
      return const _ThemeInfo('Best overall fit', Icons.auto_awesome, Color(0xFF4F46E5));
  }
}

IconData _categoryIcon(String? category) {
  switch (category) {
    case 'food':
      return Icons.restaurant_rounded;
    case 'dessert':
      return Icons.icecream_rounded;
    case 'activity':
      return Icons.local_activity_rounded;
    default:
      return Icons.place_rounded;
  }
}

Color _categoryColor(String? category) {
  switch (category) {
    case 'food':
      return const Color(0xFFF97316);
    case 'dessert':
      return const Color(0xFFEC4899);
    case 'activity':
      return const Color(0xFF0D9488);
    default:
      return AppTheme.mutedForeground;
  }
}

// ─────────────────────────────────────────────────────────────
// Plans view — pills to switch between plans, one card at a time.
// ─────────────────────────────────────────────────────────────
class ItineraryPlansView extends StatefulWidget {
  /// Response of GET /hangouts/:id/itinerary
  final Map<String, dynamic>? itinerary;
  final String itineraryStatus; // idle | generating | ready | failed
  final bool isOrganizer;
  final bool selecting;
  final ValueChanged<int> onSelect;
  final VoidCallback onRegenerate;

  const ItineraryPlansView({
    super.key,
    required this.itinerary,
    required this.itineraryStatus,
    required this.isOrganizer,
    required this.selecting,
    required this.onSelect,
    required this.onRegenerate,
  });

  @override
  State<ItineraryPlansView> createState() => _ItineraryPlansViewState();
}

class _ItineraryPlansViewState extends State<ItineraryPlansView> {
  int _index = 0;

  List<Map<String, dynamic>> get _plans =>
      (widget.itinerary?['plans'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  int? get _selectedIndex {
    final s = widget.itinerary?['selected_plan_index'];
    return s is int ? s : null;
  }

  @override
  void initState() {
    super.initState();
    final sel = _selectedIndex;
    if (sel != null && sel < _plans.length) _index = sel;
  }

  @override
  void didUpdateWidget(covariant ItineraryPlansView old) {
    super.didUpdateWidget(old);
    // New set of plans (regenerated) -> start from the top again.
    if (old.itinerary?['id'] != widget.itinerary?['id']) _index = 0;
    if (_index >= _plans.length) _index = 0;
    final newSel = _selectedIndex;
    if (newSel != null && old.itinerary?['selected_plan_index'] != newSel && newSel < _plans.length) {
      _index = newSel;
    }
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -200 && _index < _plans.length - 1) {
      setState(() => _index++);
    } else if (v > 200 && _index > 0) {
      setState(() => _index--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;

    if (plans.isEmpty) {
      if (widget.itineraryStatus == 'failed') {
        return ItineraryFailedCard(isOrganizer: widget.isOrganizer, onRetry: widget.onRegenerate);
      }
      return const PlansBuildingCard();
    }

    final selected = _selectedIndex;
    final plan = plans[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plans.length == 1 ? 'Your plan' : 'Your ${plans.length} plans',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          selected != null
              ? 'The organizer chose a plan.'
              : 'Ranked by how well they fit everyone. Swipe or tap to compare.',
          style: const TextStyle(color: AppTheme.mutedForeground, fontSize: 13),
        ),
        const SizedBox(height: 14),

        // Pills
        Row(
          children: List.generate(plans.length, (i) {
            final active = i == _index;
            final chosen = selected == i;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == plans.length - 1 ? 0 : 8),
                child: GestureDetector(
                  onTap: () => setState(() => _index = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : AppTheme.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (chosen) ...[
                          Icon(Icons.check_circle,
                              size: 14, color: active ? Colors.white : AppTheme.green),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'Plan ${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),

        GestureDetector(
          onHorizontalDragEnd: _onSwipe,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey('plan-$_index-${widget.itinerary?['id']}'),
              child: _buildPlanCard(plan, _index, selected),
            ),
          ),
        ),

        if (widget.isOrganizer && selected == null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: widget.onRegenerate,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerate plans'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index, int? selected) {
    final info = _themeInfo(plan['theme'] as String?);
    final stops = (plan['stops'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final members = (plan['member_distances'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    final cost = (plan['est_cost_per_person'] as num?)?.toDouble();
    final overBudget = plan['over_budget'] == true;
    final totalLeg = (plan['total_leg_km'] as num?)?.toDouble();
    final isTop = (plan['rank'] as num?)?.toInt() == 1;
    final isSelected = selected == index;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.green : AppTheme.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Badge(icon: info.icon, label: info.label, color: info.color),
                    if (isTop && selected == null)
                      const _Badge(icon: Icons.star_rounded, label: 'Top pick', color: Color(0xFFF59E0B)),
                    if (isSelected)
                      const _Badge(icon: Icons.check_circle, label: 'Selected', color: AppTheme.green),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan['title']?.toString() ?? 'Plan ${index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if ((plan['summary']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    plan['summary'].toString(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick stats
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (cost != null)
                      _StatChip(
                        icon: Icons.attach_money_rounded,
                        label: '~\$${cost.round()} / person',
                        color: overBudget ? AppTheme.destructive : AppTheme.primary,
                      ),
                    if (overBudget)
                      const _StatChip(
                        icon: Icons.warning_amber_rounded,
                        label: 'Above lowest budget',
                        color: AppTheme.destructive,
                      ),
                    if (totalLeg != null)
                      _StatChip(
                        icon: Icons.route_rounded,
                        label: '${totalLeg.toStringAsFixed(1)} km between stops',
                        color: AppTheme.mutedForeground,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildTimeline(stops),

                if (members.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Travel for each person (average to the stops)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(members.length, (i) {
                      final m = members[i];
                      final color = AppTheme.memberColors[i % AppTheme.memberColors.length];
                      final over = m['over_preference'] == true;
                      final name = m['display_name']?.toString() ?? 'Member';
                      final km = (m['avg_km'] as num?)?.toDouble() ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: over
                              ? AppTheme.destructive.withValues(alpha: 0.07)
                              : AppTheme.secondary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: color,
                              child: Text(
                                name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$name · ${km.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: over ? AppTheme.destructive : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],

                const SizedBox(height: 16),
                _buildAction(index, selected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> stops) {
    return Column(
      children: List.generate(stops.length, (i) {
        final s = stops[i];
        final last = i == stops.length - 1;
        final category = s['category']?.toString();
        final color = _categoryColor(category);
        final leg = (s['leg_km_from_previous'] as num?)?.toDouble() ?? 0;
        final time = s['suggested_time']?.toString() ?? '';
        final address = s['address']?.toString() ?? '';
        final reason = s['reason']?.toString() ?? '';

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_categoryIcon(category), size: 16, color: color),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: AppTheme.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                        ),
                      Text(
                        s['name']?.toString() ?? 'Stop',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      if (address.isNotEmpty && address != 'Address not available')
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            address,
                            style: const TextStyle(fontSize: 12, color: AppTheme.mutedForeground),
                          ),
                        ),
                      if (reason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                        ),
                      if (i > 0 && leg > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${leg.toStringAsFixed(1)} km from previous stop',
                            style: const TextStyle(fontSize: 11, color: AppTheme.mutedForeground),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAction(int index, int? selected) {
    if (selected == index) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppTheme.green, size: 18),
            SizedBox(width: 8),
            Text('This is the chosen plan',
                style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    if (selected != null) {
      return const Text(
        'Another plan was chosen for this hangout.',
        style: TextStyle(color: AppTheme.mutedForeground, fontSize: 13),
      );
    }

    if (widget.isOrganizer) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.selecting ? null : () => widget.onSelect(index),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: AppTheme.primary,
          ),
          child: widget.selecting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Choose this plan', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return const Text(
      'Waiting for the organizer to choose a plan.',
      style: TextStyle(color: AppTheme.mutedForeground, fontSize: 13),
    );
  }
}

// ── Small pieces ───────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// "Building your plans…" and failure states
// ─────────────────────────────────────────────────────────────
class PlansBuildingCard extends StatelessWidget {
  const PlansBuildingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 14),
          Text('Building your plans…',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(
            'Finding real places near everyone. This usually takes under a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class ItineraryFailedCard extends StatelessWidget {
  final bool isOrganizer;
  final VoidCallback onRetry;
  const ItineraryFailedCard({super.key, required this.isOrganizer, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.destructive.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.destructive, size: 32),
          const SizedBox(height: 10),
          const Text("We couldn't build plans this time",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            isOrganizer
                ? 'Give it another try.'
                : 'The organizer can retry plan generation.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
          ),
          if (isOrganizer) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}