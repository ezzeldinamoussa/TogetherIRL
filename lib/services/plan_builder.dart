import 'dart:math' as math;
import 'distance_scoring.dart';
import 'location_utils.dart';

const _validThemes = {'best_fit', 'budget_friendly', 'activity_packed', 'closest'};

class PlanBuildResult {
  /// Validated, ranked plans (best first, max 3).
  final List<Map<String, dynamic>> plans;

  /// Human-readable reasons plans were rejected. Fed back into a retry prompt.
  final List<String> problems;

  PlanBuildResult(this.plans, this.problems);
}

class _Built {
  final double score;
  final Set<String> placeIds;
  final Map<String, dynamic> plan;
  _Built(this.score, this.placeIds, this.plan);
}

double _r1(double v) => double.parse(v.toStringAsFixed(1));

/// Turns raw Gemini plans into trustworthy ones:
///  - resolves every stop by place_id (no invented places, no name collisions)
///  - rejects plans with too few stops or stops too far apart
///  - computes real distances per member from the verified coordinates
///  - scores, de-duplicates (similar plans) and ranks
PlanBuildResult buildValidatedPlans({
  required List<Map<String, dynamic>> rawPlans,
  required List<CandidateArea> areas,
  required List<MemberTravel> members,
  required double? lowestBudget,
  double maxLegKm = 3.0,
  int maxPlans = 3,
}) {
  final problems = <String>[];

  final byId = <String, ScoredPlace>{};
  final byAreaAndName = <String, ScoredPlace>{};
  for (final area in areas) {
    for (final p in area.places) {
      byId[p.id!] = p;
      byAreaAndName['${area.id}|${p.place.name.toLowerCase()}'] = p;
    }
  }

  final built = <_Built>[];

  for (var pi = 0; pi < rawPlans.length; pi++) {
    final raw = rawPlans[pi];
    final label = 'Plan "${raw['title'] ?? 'Plan ${pi + 1}'}"';
    final areaHint = raw['area_id']?.toString();

    // ── Resolve stops ──
    final seen = <String>{};
    final resolved = <ScoredPlace>[];
    final rawStops = <Map<String, dynamic>>[];

    for (final s in (raw['stops'] as List? ?? const []).whereType<Map>()) {
      final sid = s['place_id']?.toString().trim();
      var sp = sid == null ? null : byId[sid];
      if (sp == null && areaHint != null) {
        sp = byAreaAndName['$areaHint|${s['name']?.toString().toLowerCase()}'];
      }
      if (sp == null) {
        problems.add('$label used an unknown place_id "$sid" ("${s['name']}"). '
            'Only use place_id values from the provided list.');
        continue;
      }
      if (!seen.add(sp.id!)) continue; // duplicate stop
      resolved.add(sp);
      rawStops.add(Map<String, dynamic>.from(s));
    }

    if (resolved.length < 2) {
      problems.add('$label needs at least 2 valid stops.');
      continue;
    }

    // ── Legs between consecutive stops ──
    final legs = <double>[0];
    var maxLeg = 0.0;
    for (var i = 1; i < resolved.length; i++) {
      final d = haversineKm(resolved[i - 1].place.location, resolved[i].place.location);
      legs.add(d);
      maxLeg = math.max(maxLeg, d);
    }
    if (maxLeg > maxLegKm) {
      problems.add('$label has consecutive stops ${maxLeg.toStringAsFixed(1)} km apart. '
          'Keep every leg under ${maxLegKm.toStringAsFixed(0)} km.');
      continue;
    }
    final totalLeg = legs.fold<double>(0, (a, b) => a + b);

    // ── Per-member distances ──
    final memberDistances = <Map<String, dynamic>>[];
    var sumAvg = 0.0;
    var penalty = 0.0;
    for (final m in members) {
      final ds = resolved.map((p) => p.distanceByMember[m.userId] ?? 0.0).toList();
      final avg = ds.reduce((a, b) => a + b) / ds.length;
      final mx = ds.reduce(math.max);
      sumAvg += avg;
      if (m.maxKm > 0 && avg > m.maxKm) {
        penalty += (avg - m.maxKm) / m.maxKm * 10;
      }
      memberDistances.add({
        'user_id': m.userId,
        'display_name': m.displayName,
        'start': m.source,
        'avg_km': _r1(avg),
        'max_km': _r1(mx),
        'preferred_max_km': m.maxKm,
        'over_preference': avg > m.maxKm,
      });
    }
    final meanAvg = members.isEmpty ? 0.0 : sumAvg / members.length;

    // ── Budget ──
    final estCost = (raw['est_cost_per_person'] as num?)?.toDouble();
    final overBudget =
        lowestBudget != null && estCost != null && estCost > lowestBudget * 1.1;

    // Lower is better.
    final score = meanAvg + penalty + totalLeg * 0.75 + (overBudget ? 6 : 0);

    final theme = raw['theme']?.toString();

    final stops = <Map<String, dynamic>>[];
    for (var i = 0; i < resolved.length; i++) {
      final sp = resolved[i];
      final rs = rawStops[i];
      stops.add({
        'place_id': sp.id,
        'area_id': sp.areaId,
        'type': rs['type']?.toString() ?? sp.category,
        'category': sp.category,
        'name': sp.place.name,
        'address': sp.place.address,
        'lat': sp.place.location.lat,
        'lng': sp.place.location.lng,
        'suggested_time': rs['suggested_time'],
        'reason': rs['reason'],
        'leg_km_from_previous': _r1(legs[i]),
        'distance_km_by_member': sp.distanceByMember,
      });
    }

    built.add(
      _Built(
        score,
        resolved.map((p) => p.id!).toSet(),
        {
          'title': raw['title']?.toString() ?? 'Plan ${pi + 1}',
          'theme': _validThemes.contains(theme) ? theme : 'best_fit',
          'summary': raw['summary']?.toString() ?? '',
          'area_id': resolved.first.areaId,
          'est_cost_per_person': estCost,
          'over_budget': overBudget,
          'total_leg_km': _r1(totalLeg),
          'member_distances': memberDistances,
          'fit_score': double.parse(score.toStringAsFixed(2)),
          'stops': stops,
        },
      ),
    );
  }

  // ── Rank, then drop near-duplicates ──
  built.sort((a, b) => a.score.compareTo(b.score));

  final accepted = <_Built>[];
  for (final candidate in built) {
    final tooSimilar = accepted.any((a) {
      final overlap = a.placeIds.intersection(candidate.placeIds).length;
      final smaller = math.min(a.placeIds.length, candidate.placeIds.length);
      return smaller > 0 && overlap / smaller > 0.5;
    });
    if (tooSimilar) {
      problems.add('Plan "${candidate.plan['title']}" was too similar to a better plan.');
      continue;
    }
    accepted.add(candidate);
    if (accepted.length == maxPlans) break;
  }

  final plans = <Map<String, dynamic>>[];
  for (var i = 0; i < accepted.length; i++) {
    plans.add({'rank': i + 1, ...accepted[i].plan});
  }

  return PlanBuildResult(plans, problems);
}