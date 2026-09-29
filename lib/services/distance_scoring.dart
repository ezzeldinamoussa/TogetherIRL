import 'dart:math' as math;
import 'location_utils.dart';
import 'places_service.dart';

class MemberTravel {
  final String userId;
  final String displayName;
  final LatLng home;
  final double maxKm;

  MemberTravel({
    required this.userId,
    required this.displayName,
    required this.home,
    required this.maxKm,
  });
}

class ScoredPlace {
  final PlaceCandidate place;

  /// Distance from this place to each member.
  final Map<String, double> distanceByMember;

  /// Overall group accessibility score.
  /// Lower is better.
  final double score;

  /// Broad category used for candidate balancing.
  final String category;

  ScoredPlace({
    required this.place,
    required this.distanceByMember,
    required this.score,
    required this.category,
  });

  Map<String, dynamic> toPromptJson() {
  return {
    'name': place.name,
    'address': place.address,
    'latitude': place.location.lat,
    'longitude': place.location.lng,
    'category': category,
    'distance_km_by_member': distanceByMember,
    'group_distance_score': score,
    'budget_hint': _budgetHint(place),
  };
}
}

/// Score every place based on how convenient it is for the entire group.
///
/// Lower score = better.
///
/// A place is NOT rejected just because it exceeds someone's preferred
/// max distance. Going over the preference creates a penalty instead.
List<ScoredPlace> scorePlaces({
  required List<PlaceCandidate> places,
  required List<MemberTravel> members,
}) {
  final scored = <ScoredPlace>[];

  for (final place in places) {
    final distances = <String, double>{};

    double totalDistance = 0;
    double travelPenalty = 0;

    for (final member in members) {
      final distance = haversineKm(
        member.home,
        place.location,
      );

      distances[member.userId] = distance;
      totalDistance += distance;

      // Soft penalty when the place is beyond this member's
      // preferred maximum travel distance.
      if (distance > member.maxKm) {
        final excess = distance - member.maxKm;

        final normalizedExcess =
            member.maxKm > 0 ? excess / member.maxKm : excess;

        travelPenalty += normalizedExcess * 10;
      }
    }

    final averageDistance =
        members.isEmpty ? 0 : totalDistance / members.length;

    final score = averageDistance + travelPenalty;

    scored.add(
      ScoredPlace(
        place: place,
        distanceByMember: distances,
        score: score,
        category: _categoryFor(place),
      ),
    );
  }

  scored.sort(
    (a, b) => a.score.compareTo(b.score),
  );

  return scored;
}

/// Select up to 50 candidates from ONE compact geographic area.
///
/// Target:
///   20 food
///   15 dessert / coffee
///   15 activities
///
/// The algorithm first chooses the strongest geographic cluster.
/// It only expands into nearby clusters if the strongest cluster does
/// not contain enough places to fill all 50 slots.
///
/// This prevents Gemini from receiving places scattered across NYC/NJ.
List<ScoredPlace> selectItineraryCandidates({
  required List<ScoredPlace> scoredPlaces,
  int maxCandidates = 50,
}) {
  if (scoredPlaces.isEmpty) {
    return [];
  }

  // ------------------------------------------------------------
  // Candidate targets.
  //
  // These are the preferred proportions for Gemini's candidate pool.
  // ------------------------------------------------------------

  final foodTarget = math.min(
    20,
    maxCandidates,
  );

  final dessertTarget = math.min(
    15,
    math.max(0, maxCandidates - foodTarget),
  );

  final activityTarget = math.min(
    15,
    math.max(
      0,
      maxCandidates - foodTarget - dessertTarget,
    ),
  );

  // ------------------------------------------------------------
  // STEP 1:
  // Build compact geographic clusters.
  //
  // Only the strongest 100 places by member-accessibility score are
  // used as anchors. This prevents random distant places from
  // creating clusters.
  // ------------------------------------------------------------

  final clusters = <_PlaceCluster>[];

  final anchorCandidates = scoredPlaces.take(
    math.min(100, scoredPlaces.length),
  );

  for (final candidate in anchorCandidates) {
    _PlaceCluster? closestCluster;

    double closestDistance = double.infinity;

    for (final cluster in clusters) {
      final distance = haversineKm(
        cluster.center,
        candidate.place.location,
      );

      if (distance <= 1.5 && distance < closestDistance) {
        closestCluster = cluster;
        closestDistance = distance;
      }
    }

    if (closestCluster == null) {
      clusters.add(
        _PlaceCluster(
          center: candidate.place.location,
          places: [candidate],
        ),
      );
    } else {
      closestCluster.places.add(candidate);
      closestCluster.recalculateCenter();
    }
  }

  if (clusters.isEmpty) {
    return scoredPlaces.take(maxCandidates).toList();
  }

  // ------------------------------------------------------------
  // STEP 2:
  // Score each geographic cluster.
  // ------------------------------------------------------------

  for (final cluster in clusters) {
    cluster.score = _scoreCluster(cluster);
  }

  clusters.sort(
    (a, b) => a.score.compareTo(b.score),
  );

  // ------------------------------------------------------------
  // STEP 3:
  // Choose the BEST cluster.
  //
  // This is the major change from your old implementation.
  //
  // We do NOT immediately combine candidates from every cluster.
  // Gemini should primarily see places from one neighborhood/area.
  // ------------------------------------------------------------

  final bestCluster = clusters.first;

  // ------------------------------------------------------------
  // STEP 4:
  // Fill the three category slots from the best cluster.
  // ------------------------------------------------------------

  final selected = <ScoredPlace>[];
  final selectedNames = <String>{};

  _addCategoryCandidates(
    selected: selected,
    selectedNames: selectedNames,
    candidates: bestCluster.places,
    category: 'food',
    limit: foodTarget,
  );

  _addCategoryCandidates(
    selected: selected,
    selectedNames: selectedNames,
    candidates: bestCluster.places,
    category: 'dessert',
    limit: dessertTarget,
  );

  _addCategoryCandidates(
    selected: selected,
    selectedNames: selectedNames,
    candidates: bestCluster.places,
    category: 'activity',
    limit: activityTarget,
  );

  // ------------------------------------------------------------
  // STEP 5:
  // If the strongest cluster doesn't have enough places in a
  // category, use nearby clusters.
  //
  // IMPORTANT:
  // We don't jump to arbitrary clusters across the city.
  //
  // We only use clusters within 3 km of the best cluster.
  // ------------------------------------------------------------

  if (selected.length < maxCandidates) {
    final nearbyClusters = clusters
        .where(
          (cluster) =>
              cluster != bestCluster &&
              haversineKm(
                    bestCluster.center,
                    cluster.center,
                  ) <=
                  3.0,
        )
        .toList();

    nearbyClusters.sort(
      (a, b) {
        final distanceA = haversineKm(
          bestCluster.center,
          a.center,
        );

        final distanceB = haversineKm(
          bestCluster.center,
          b.center,
        );

        return distanceA.compareTo(distanceB);
      },
    );

    for (final cluster in nearbyClusters) {
      if (selected.length >= maxCandidates) {
        break;
      }

      _addCategoryCandidates(
        selected: selected,
        selectedNames: selectedNames,
        candidates: cluster.places,
        category: 'food',
        limit: foodTarget,
      );

      _addCategoryCandidates(
        selected: selected,
        selectedNames: selectedNames,
        candidates: cluster.places,
        category: 'dessert',
        limit: dessertTarget,
      );

      _addCategoryCandidates(
        selected: selected,
        selectedNames: selectedNames,
        candidates: cluster.places,
        category: 'activity',
        limit: activityTarget,
      );
    }
  }

  // ------------------------------------------------------------
  // STEP 6:
  // If we STILL don't have 50 candidates, fill remaining slots
  // with the best places close to the chosen area.
  //
  // This is only a fallback.
  // ------------------------------------------------------------

  if (selected.length < maxCandidates) {
    final remaining = [...scoredPlaces];

    remaining.sort(
      (a, b) {
        final distanceA = haversineKm(
          bestCluster.center,
          a.place.location,
        );

        final distanceB = haversineKm(
          bestCluster.center,
          b.place.location,
        );

        // Geographic proximity is more important than global
        // accessibility score for this fallback.
        final distanceComparison =
            distanceA.compareTo(distanceB);

        if (distanceComparison != 0) {
          return distanceComparison;
        }

        return a.score.compareTo(b.score);
      },
    );

    for (final candidate in remaining) {
      if (selected.length >= maxCandidates) {
        break;
      }

      if (selectedNames.add(candidate.place.name)) {
        selected.add(candidate);
      }
    }
  }

  // ------------------------------------------------------------
  // STEP 7:
  // Sort candidates by category and then accessibility score.
  //
  // This keeps the JSON sent to Gemini organized:
  //
  // food
  // food
  // food
  // ...
  // dessert
  // dessert
  // ...
  // activity
  // activity
  // ...
  // ------------------------------------------------------------

  selected.sort(
    (a, b) {
      final categoryComparison =
          _categoryOrder(a.category).compareTo(
        _categoryOrder(b.category),
      );

      if (categoryComparison != 0) {
        return categoryComparison;
      }

      return a.score.compareTo(b.score);
    },
  );

  return selected.take(maxCandidates).toList();
}

/// Adds the best places from one category.
///
/// Existing places are not duplicated.
void _addCategoryCandidates({
  required List<ScoredPlace> selected,
  required Set<String> selectedNames,
  required List<ScoredPlace> candidates,
  required String category,
  required int limit,
}) {
  if (limit <= 0) {
    return;
  }

  final matching = candidates
      .where(
        (place) => place.category == category,
      )
      .toList();

  matching.sort(
    (a, b) => a.score.compareTo(b.score),
  );

  var added = 0;

  for (final candidate in matching) {
    if (added >= limit) {
      break;
    }

    if (selectedNames.add(candidate.place.name)) {
      selected.add(candidate);
      added++;
    }
  }
}

/// Scores a geographic cluster.
///
/// Lower score = better.
///
/// A good cluster:
/// - is accessible to the group
/// - has food
/// - has dessert / coffee
/// - has activities
/// - contains enough places to give Gemini choices
double _scoreCluster(_PlaceCluster cluster) {
  if (cluster.places.isEmpty) {
    return double.infinity;
  }

  final averagePlaceScore =
      cluster.places
              .map((p) => p.score)
              .reduce((a, b) => a + b) /
          cluster.places.length;

  final categories =
      cluster.places.map((p) => p.category).toSet();

  double categoryBonus = 0;

  // Reward clusters containing the categories we need.
  if (categories.contains('food')) {
    categoryBonus -= 5;
  }

  if (categories.contains('dessert')) {
    categoryBonus -= 5;
  }

  if (categories.contains('activity')) {
    categoryBonus -= 6;
  }

  // Strong bonus for a complete outing area.
  if (categories.contains('food') &&
      categories.contains('dessert') &&
      categories.contains('activity')) {
    categoryBonus -= 12;
  }

  // Reward clusters with enough candidates.
  //
  // More options gives Gemini more flexibility.
  if (cluster.places.length >= 30) {
    categoryBonus -= 5;
  }

  if (cluster.places.length >= 50) {
    categoryBonus -= 5;
  }

  return averagePlaceScore + categoryBonus;
}

/// Determines the broad itinerary category of an OSM place.
String _categoryFor(PlaceCandidate place) {
  final text = [
    place.name,
    place.address,
    ...place.tags,
  ].join(' ').toLowerCase();

  // ------------------------------------------------------------
  // DESSERT / COFFEE
  // ------------------------------------------------------------

  if (text.contains('ice cream') ||
      text.contains('ice_cream') ||
      text.contains('gelato') ||
      text.contains('dessert') ||
      text.contains('bakery') ||
      text.contains('pastry') ||
      text.contains('confection') ||
      text.contains('cafe') ||
      text.contains('coffee') ||
      text.contains('coffee_shop') ||
      text.contains('donut') ||
      text.contains('doughnut') ||
      text.contains('cake') ||
      text.contains('chocolate') ||
      text.contains('bubble_tea') ||
      text.contains('tea')) {
    return 'dessert';
  }

  // ------------------------------------------------------------
  // ACTIVITIES
  // ------------------------------------------------------------

  if (text.contains('cinema') ||
      text.contains('movie') ||
      text.contains('bowling') ||
      text.contains('theatre') ||
      text.contains('theater') ||
      text.contains('museum') ||
      text.contains('gallery') ||
      text.contains('arts_centre') ||
      text.contains('arts center') ||
      text.contains('park') ||
      text.contains('garden') ||
      text.contains('nature') ||
      text.contains('beach') ||
      text.contains('amusement') ||
      text.contains('arcade') ||
      text.contains('escape_game') ||
      text.contains('escape room') ||
      text.contains('historic') ||
      text.contains('sport') ||
      text.contains('sports') ||
      text.contains('miniature_golf') ||
      text.contains('golf') ||
      text.contains('zoo') ||
      text.contains('aquarium') ||
      text.contains('theme_park') ||
      text.contains('water_park')) {
    return 'activity';
  }

  // ------------------------------------------------------------
  // FOOD
  // ------------------------------------------------------------

  return 'food';
}

String _budgetHint(PlaceCandidate place) {
  final text = [
    place.name,
    place.address,
    ...place.tags,
  ].join(' ').toLowerCase();

  if (text.contains('fast_food') ||
      text.contains('fast food') ||
      text.contains('amenity=fast_food') ||
      text.contains('ice cream') ||
      text.contains('ice_cream') ||
      text.contains('shop=bakery') ||
      text.contains('bakery')) {
    return 'low';
  }

  if (text.contains('cafe') ||
      text.contains('coffee') ||
      text.contains('amenity=cafe') ||
      text.contains('bubble_tea')) {
    return 'low_to_medium';
  }

  if (text.contains('park') ||
      text.contains('garden') ||
      text.contains('beach') ||
      text.contains('nature')) {
    return 'free_or_low';
  }

  if (text.contains('restaurant') ||
      text.contains('amenity=restaurant')) {
    return 'medium';
  }

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

  _PlaceCluster({
    required this.center,
    required this.places,
  });

  void recalculateCenter() {
    if (places.isEmpty) {
      return;
    }

    var totalLat = 0.0;
    var totalLng = 0.0;

    for (final place in places) {
      totalLat += place.place.location.lat;
      totalLng += place.place.location.lng;
    }

    center = LatLng(
      totalLat / places.length,
      totalLng / places.length,
    );
  }
}

/// Haversine distance in kilometers.
double haversineKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;

  final dLat = _degreesToRadians(
    b.lat - a.lat,
  );

  final dLng = _degreesToRadians(
    b.lng - a.lng,
  );

  final lat1 = _degreesToRadians(a.lat);
  final lat2 = _degreesToRadians(b.lat);

  final h =
      math.sin(dLat / 2) *
              math.sin(dLat / 2) +
          math.cos(lat1) *
              math.cos(lat2) *
              math.sin(dLng / 2) *
              math.sin(dLng / 2);

  final c = 2 *
      math.atan2(
        math.sqrt(h),
        math.sqrt(1 - h),
      );

  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) {
  return degrees * math.pi / 180;
}