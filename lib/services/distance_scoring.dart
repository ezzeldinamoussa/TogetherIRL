import 'dart:math' as math;
import 'location_utils.dart'; // LatLng, haversineKm (defined once, there)
import 'places_service.dart';

class MemberTravel {
  final String userId;
  final String displayName;

  /// Where this member is starting from for THIS hangout
  /// (home / school / work / current location / typed ZIP).
  final LatLng home;
  final double maxKm;

  /// 'home' | 'school' | 'work' | 'current' | 'manual'
  final String source;

  MemberTravel({
    required this.userId,
    required this.displayName,
    required this.home,
    required this.maxKm,
    this.source = 'home',
  });
}

class ScoredPlace {
  final PlaceCandidate place;

  /// Distance from this place to each member's starting point (km), by userId.
  final Map<String, double> distanceByMember;

  /// Overall group accessibility score. Lower is better.
  final double score;

  /// 'food' | 'dessert' | 'activity'
  final String category;

  /// Stable id used in the Gemini prompt (e.g. "A07"). Set when the place
  /// is placed into a CandidateArea.
  String? id;
  String? areaId;

  ScoredPlace({
    required this.place,
    required this.distanceByMember,
    required this.score,
    required this.category,
  });

  /// Compact JSON for the prompt. [names] maps userId -> display name so the
  /// model sees readable names instead of UUIDs.
  Map<String, dynamic> toPromptJson({Map<String, String>? names}) {
    final dist = <String, double>{};
    distanceByMember.forEach((uid, km) {
      dist[names?[uid] ?? uid] = double.parse(km.toStringAsFixed(1));
    });
    return {
      'place_id': id,
      'name': place.name,
      'category': category,
      'budget_hint': budgetHintFor(place),
      'address': place.address,
      'km_from_each_member': dist,
    };
  }
}

/// A compact neighbourhood of candidate places the AI may build a plan from.
class CandidateArea {
  final String id; // "A", "B", "C"
  final LatLng center;
  final List<ScoredPlace> places;

  CandidateArea({
    required this.id,
    required this.center,
    required this.places,
  });
}

/// Score every place by how convenient it is for the whole group.
/// Lower score = better. Exceeding someone's preferred max distance is a
/// penalty, not a rejection.
List<ScoredPlace> scorePlaces({
  required List<PlaceCandidate> places,
  required List<MemberTravel> members,
}) {
  final scored = <ScoredPlace>[];

  for (final place in places) {
    final distances = <String, double>{};
    var totalDistance = 0.0;
    var travelPenalty = 0.0;

    for (final member in members) {
      final distance = haversineKm(member.home, place.location);
      distances[member.userId] = distance;
      totalDistance += distance;

      if (distance > member.maxKm) {
        final excess = distance - member.maxKm;
        final normalizedExcess = member.maxKm > 0 ? excess / member.maxKm : excess;
        travelPenalty += normalizedExcess * 10;
      }
    }

    final averageDistance = members.isEmpty ? 0.0 : totalDistance / members.length;

    scored.add(
      ScoredPlace(
        place: place,
        distanceByMember: distances,
        score: averageDistance + travelPenalty,
        category: categoryFor(place),
      ),
    );
  }

  scored.sort((a, b) => a.score.compareTo(b.score));
  return scored;
}

/// Picks up to [maxAreas] well-separated neighbourhoods and fills each with a
/// category-balanced pool of places. Each plan Gemini builds stays inside ONE
/// area, so different areas => genuinely different plans.
///
/// [scoredPlaces] must be sorted by score ascending (scorePlaces does this).
List<CandidateArea> selectCandidateAreas({
  required List<ScoredPlace> scoredPlaces,
  int maxAreas = 3,
  int foodPerArea = 12,
  int dessertPerArea = 9,
  int activityPerArea = 9,
  double clusterRadiusKm = 1.5,
}) {
  if (scoredPlaces.isEmpty) return [];

  // ── 1. Greedy clusters over the 100 most accessible places ──
  final clusters = <_PlaceCluster>[];
  for (final candidate in scoredPlaces.take(math.min(100, scoredPlaces.length))) {
    _PlaceCluster? closest;
    var closestDist = double.infinity;

    for (final cluster in clusters) {
      final d = haversineKm(cluster.center, candidate.place.location);
      if (d <= clusterRadiusKm && d < closestDist) {
        closest = cluster;
        closestDist = d;
      }
    }

    if (closest == null) {
      clusters.add(_PlaceCluster(center: candidate.place.location, places: [candidate]));
    } else {
      closest.places.add(candidate);
      closest.recalculateCenter();
    }
  }

  for (final c in clusters) {
    c.score = _scoreCluster(c);
  }
  clusters.sort((a, b) => a.score.compareTo(b.score));

  // ── 2. Choose separated clusters (>= 1 km apart) ──
  final chosen = <_PlaceCluster>[];
  for (final c in clusters) {
    if (chosen.length >= maxAreas) break;
    if (chosen.isNotEmpty && c.places.length < 4) continue; // too thin
    if (chosen.any((o) => haversineKm(o.center, c.center) < 1.0)) continue;
    chosen.add(c);
  }
  if (chosen.isEmpty) chosen.add(clusters.first);

  // ── 3. Fill each area from ALL scored places near its center ──
  final used = <ScoredPlace>{};
  final areas = <CandidateArea>[];
  final cap = foodPerArea + dessertPerArea + activityPerArea;

  for (final c in chosen) {
    final pool = scoredPlaces
        .where((p) =>
            !used.contains(p) &&
            haversineKm(c.center, p.place.location) <= clusterRadiusKm * 1.2)
        .toList(); // already best-score first

    final picked = <ScoredPlace>[];

    void take(String category, int limit) {
      var n = 0;
      for (final p in pool) {
        if (n >= limit) break;
        if (p.category == category && !picked.contains(p)) {
          picked.add(p);
          n++;
        }
      }
    }

    take('food', foodPerArea);
    take('dessert', dessertPerArea);
    take('activity', activityPerArea);

    for (final p in pool) {
      if (picked.length >= cap) break;
      if (!picked.contains(p)) picked.add(p);
    }

    if (picked.length < 3 && areas.isNotEmpty) continue;

    picked.sort((a, b) {
      final byCat = _categoryOrder(a.category).compareTo(_categoryOrder(b.category));
      return byCat != 0 ? byCat : a.score.compareTo(b.score);
    });

    final letter = String.fromCharCode(65 + areas.length); // A, B, C
    for (var i = 0; i < picked.length; i++) {
      picked[i].id = '$letter${(i + 1).toString().padLeft(2, '0')}';
      picked[i].areaId = letter;
      used.add(picked[i]);
    }

    areas.add(CandidateArea(id: letter, center: c.center, places: picked));
  }

  return areas;
}

// ─────────────────────────────────────────────────────────────
// Cluster scoring
// ─────────────────────────────────────────────────────────────

double _scoreCluster(_PlaceCluster cluster) {
  if (cluster.places.isEmpty) return double.infinity;

  final averagePlaceScore =
      cluster.places.map((p) => p.score).reduce((a, b) => a + b) / cluster.places.length;

  final categories = cluster.places.map((p) => p.category).toSet();

  var bonus = 0.0;
  if (categories.contains('food')) bonus -= 5;
  if (categories.contains('dessert')) bonus -= 5;
  if (categories.contains('activity')) bonus -= 6;
  if (categories.length == 3) bonus -= 12;
  if (cluster.places.length >= 30) bonus -= 5;
  if (cluster.places.length >= 50) bonus -= 5;

  return averagePlaceScore + bonus;
}

// ─────────────────────────────────────────────────────────────
// Categorisation — based on OSM tags, NOT free text.
// (Free-text matching misfiled e.g. "Steakhouse" as dessert because it
// contains "tea", and any restaurant on "Park Ave" as an activity.)
// ─────────────────────────────────────────────────────────────

Map<String, String> _tagMap(PlaceCandidate place) {
  final map = <String, String>{};
  for (final t in place.tags) {
    final i = t.indexOf('=');
    if (i <= 0) continue;
    map[t.substring(0, i)] = t.substring(i + 1).toLowerCase();
  }
  return map;
}

bool _cuisineHasAny(String? cuisine, List<String> needles) {
  if (cuisine == null) return false;
  final parts = cuisine.split(';').map((s) => s.trim());
  return parts.any(needles.contains);
}

String categoryFor(PlaceCandidate place) {
  final t = _tagMap(place);
  final amenity = t['amenity'];
  final shop = t['shop'];
  final leisure = t['leisure'];
  final tourism = t['tourism'];

  // Dessert / coffee
  if (amenity == 'ice_cream' ||
      amenity == 'cafe' ||
      const {'bakery', 'pastry', 'confectionery', 'chocolate', 'coffee', 'tea', 'ice_cream'}
          .contains(shop) ||
      _cuisineHasAny(t['cuisine'], const [
        'ice_cream', 'coffee_shop', 'donut', 'dessert', 'bubble_tea', 'gelato', 'cake', 'crepe',
      ])) {
    return 'dessert';
  }

  // Food
  if (const {'restaurant', 'fast_food', 'food_court', 'bar', 'pub', 'biergarten'}
      .contains(amenity)) {
    return 'food';
  }

  // Activities
  if (const {'cinema', 'theatre', 'arts_centre'}.contains(amenity) ||
      const {
        'museum', 'gallery', 'zoo', 'aquarium', 'theme_park', 'attraction', 'viewpoint',
      }.contains(tourism) ||
      const {
        'park', 'garden', 'bowling_alley', 'miniature_golf', 'amusement_arcade',
        'water_park', 'sports_centre', 'playground',
      }.contains(leisure) ||
      t['natural'] == 'beach' ||
      t['sport'] == '10pin') {
    return 'activity';
  }

  return 'food';
}

String budgetHintFor(PlaceCandidate place) {
  final t = _tagMap(place);
  final amenity = t['amenity'];
  final shop = t['shop'];

  if (amenity == 'fast_food' || amenity == 'ice_cream' || shop == 'bakery') return 'low';
  if (amenity == 'cafe') return 'low_to_medium';
  if (const {'park', 'garden'}.contains(t['leisure']) || t['natural'] == 'beach') {
    return 'free_or_low';
  }
  if (const {'museum', 'gallery'}.contains(t['tourism'])) return 'low_to_medium';
  if (amenity == 'restaurant') return 'medium';
  if (amenity == 'cinema' || t['sport'] == '10pin') return 'medium';
  return 'unknown';
}

int _categoryOrder(String category) {
  switch (category) {
    case 'food':
      return 0;
    case 'dessert':
      return 1;
    case 'activity':
      return 2;
    default:
      return 3;
  }
}

class _PlaceCluster {
  LatLng center;
  final List<ScoredPlace> places;
  double score = double.infinity;

  _PlaceCluster({required this.center, required this.places});

  void recalculateCenter() {
    if (places.isEmpty) return;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in places) {
      lat += p.place.location.lat;
      lng += p.place.location.lng;
    }
    center = LatLng(lat / places.length, lng / places.length);
  }
}