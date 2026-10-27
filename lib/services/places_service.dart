import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'location_utils.dart';

/// App cuisine chip -> OSM cuisine value. Shared with distance_scoring.dart
/// so plans can be checked against each member's cuisine picks.
const Map<String, String> cuisineKeyByLabel = {
  'Italian': 'italian',
  'French': 'french',
  'Mexican': 'mexican',
  'Latin American': 'latin_american',
  'Japanese': 'japanese',
  'Chinese': 'chinese',
  'Vietnamese': 'vietnamese',
  'Korean': 'korean',
  'Thai': 'thai',
  'American': 'american',
  'Mediterranean': 'mediterranean',
  'Greek': 'greek',
  'Middle Eastern': 'middle_eastern',
  'Indian': 'indian',
};

class PlaceCandidate {
  final String name;
  final String address;
  final LatLng location;
  final List<String> tags;

  PlaceCandidate({
    required this.name,
    required this.address,
    required this.location,
    required this.tags,
  });

  Map<String, dynamic> toPromptJson() {
    return {
      'name': name,
      'address': address,
      'latitude': location.lat,
      'longitude': location.lng,
      'tags': tags,
    };
  }
}

class PlacesService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  static const _userAgent = 'TogetherIRL/1.0 (contact: mmorcos434@gmail.com)';

  /// The app's activity chips -> the OSM features that satisfy them.
  /// (The old map was keyed by 'park', 'cinema', ... which no chip ever
  /// matched, so activity places were never searched.)
  static const Map<String, List<String>> _activityFilters = {
    'Coffee & Brunch': ['["amenity"="cafe"]', '["shop"="bakery"]'],
    'Food': ['["amenity"="restaurant"]', '["amenity"="fast_food"]'],
    'Dessert': [
      '["amenity"="ice_cream"]',
      '["shop"="bakery"]',
      '["shop"="confectionery"]',
    ],
    'Entertainment': [
      '["amenity"="cinema"]',
      '["amenity"="theatre"]',
      '["sport"="10pin"]',
      '["leisure"="amusement_arcade"]',
      '["leisure"="miniature_golf"]',
      '["tourism"="zoo"]',
      '["tourism"="aquarium"]',
    ],
    'Outdoors': [
      '["leisure"="park"]',
      '["leisure"="garden"]',
      '["natural"="beach"]',
      '["tourism"="viewpoint"]',
    ],
    'Arts & Culture': [
      '["tourism"="museum"]',
      '["tourism"="gallery"]',
      '["amenity"="arts_centre"]',
    ],
    // Targeted on purpose: a broad nwr["shop"] makes Overpass extremely slow.
    'Shopping': [
      '["shop"="mall"]',
      '["shop"="department_store"]',
      '["shop"="books"]',
    ],
  };

  Future<List<PlaceCandidate>> searchArea({
    required LatLng center,
    required double radiusKm,
    List<String> activityTypes = const [],
    List<String> foodPreferences = const [],
  }) async {
    final radiusMeters = (radiusKm * 1000).round();

    String clause(String filter) =>
        'nwr$filter(around:$radiusMeters,${center.lat},${center.lng});';

    // A set, so overlapping filters (e.g. "Food" + the always-on food filters)
    // are only queried once.
    final clauses = <String>{};

    // Always include basic food + sweets so every plan can have a meal,
    // including cheap options for low-budget groups.
    for (final f in const [
      '["amenity"="fast_food"]',
      '["amenity"="restaurant"]',
      '["amenity"="cafe"]',
      '["shop"="bakery"]',
      '["amenity"="ice_cream"]',
    ]) {
      clauses.add(clause(f));
    }

    // Things to DO, from the group's activity picks.
    for (final activity in activityTypes) {
      for (final f in _activityFilters[activity] ?? const <String>[]) {
        clauses.add(clause(f));
      }
    }

    // Cuisine-specific restaurants.
    for (final food in foodPreferences) {
      final cuisine = cuisineKeyByLabel[food];
      if (cuisine != null) {
        clauses.add(
          'nwr["amenity"="restaurant"]["cuisine"~'
          '"(^|;)${RegExp.escape(cuisine)}(;|\$)",i]'
          '(around:$radiusMeters,${center.lat},${center.lng});',
        );
      }
    }

    print('Searching Overpass with ${clauses.length} filters '
        'within ${radiusKm.toStringAsFixed(1)} km...');

    return _runQuery(
      center: center,
      radiusMeters: radiusMeters,
      clauses: clauses.toList(),
    );
  }

  // ============================================================
  // SPLIT LARGE OVERPASS REQUESTS
  // ============================================================

  Future<List<PlaceCandidate>> _runQuery({
    required LatLng center,
    required int radiusMeters,
    required List<String> clauses,
  }) async {
    // Overpass allows a small number of simultaneous queries per IP. 3 was
    // tried and the server answered "429 Too Many Requests - all query workers
    // are busy" on the very first batch of every search, so 2 it is.
    const maxConcurrent = 2;

    // Size batches from the filter count so the whole search fits in ONE
    // concurrent round no matter how many filters a group's picks produce
    // (5 for food-only, ~10 for three activities, more with cuisines).
    // Capped so a filter-heavy group doesn't build one enormous query.
    const maxBatchSize = 6;
    final batchSize =
        (clauses.length / maxConcurrent).ceil().clamp(1, maxBatchSize);

    final batches = <List<String>>[];
    for (var i = 0; i < clauses.length; i += batchSize) {
      batches.add(clauses.sublist(i, math.min(i + batchSize, clauses.length)));
    }

    print('Splitting ${clauses.length} filters into ${batches.length} '
        'batch(es) of up to $batchSize, max $maxConcurrent in flight...');

    final allPlaces = <PlaceCandidate>[];
    final seenPlaces = <String>{};

    // The batches are independent searches, so they run concurrently rather
    // than one after another. A null entry means that batch's request failed.
    final results = List<List<PlaceCandidate>?>.filled(batches.length, null);

    for (var start = 0; start < batches.length; start += maxConcurrent) {
      final inFlight = <Future<void>>[];
      final end = math.min(start + maxConcurrent, batches.length);

      for (var i = start; i < end; i++) {
        final index = i;
        print('Running Overpass batch ${index + 1}/${batches.length} '
            'with ${batches[index].length} filters...');

        inFlight.add(() async {
          final places = await _runOverpassBatch(clauses: batches[index]);
          print('Overpass batch ${index + 1}/${batches.length} -> '
              '${places == null ? 'FAILED' : '${places.length} named places'}');
          results[index] = places;
        }());
      }

      await Future.wait(inFlight);
    }

    // A failed batch drops a whole category of places, which quietly yields
    // plans that ignore what the group asked for (an "Outdoors" request coming
    // back with no parks). The usual cause is Overpass refusing simultaneous
    // queries, so retry the failures one at a time with nothing competing.
    final failed = [
      for (var i = 0; i < results.length; i++)
        if (results[i] == null) i,
    ];

    for (final i in failed) {
      print('Retrying failed Overpass batch ${i + 1}/${batches.length} '
          'on its own...');
      final places = await _runOverpassBatch(clauses: batches[i]);
      print('Overpass batch ${i + 1} serial retry -> '
          '${places == null ? 'FAILED AGAIN' : '${places.length} named places'}');
      results[i] = places;
    }

    // Merged in batch order, not completion order, so which copy of a
    // duplicated place wins does not depend on network timing.
    for (final places in results) {
      for (final place in places ?? const <PlaceCandidate>[]) {
        final key = '${place.name}|'
            '${place.location.lat.toStringAsFixed(6)}|'
            '${place.location.lng.toStringAsFixed(6)}';
        if (seenPlaces.add(key)) allPlaces.add(place);
      }
    }

    final stillFailed = results.where((r) => r == null).length;
    if (stillFailed > 0) {
      print('WARNING: $stillFailed of ${batches.length} Overpass batch(es) '
          'failed even on retry. The place list is INCOMPLETE, so some '
          'categories the group asked for may be missing from every plan.');
    }

    print('Combined Overpass result: ${allPlaces.length} unique named places '
        'from ${batches.length} batch(es)'
        '${failed.isEmpty ? '' : ', ${failed.length} needing a serial retry'}');
    return allPlaces;
  }

  // ============================================================
  // SINGLE OVERPASS REQUEST
  // ============================================================

  /// Returns null when the request itself failed, and an empty list when it
  /// succeeded but nothing matched. The caller needs that distinction: a failed
  /// batch means a whole category of places is missing from the search, which
  /// silently produces plans that ignore what the group asked for.
  Future<List<PlaceCandidate>?> _runOverpassBatch({
    required List<String> clauses,
  }) async {
    final query = '''
[out:json][timeout:35];
(
  ${clauses.join('\n')}
);
out center qt;
''';

    // Keep retries bounded: this is a public endpoint and long retry chains
    // make itinerary generation appear stuck when Overpass is overloaded.
    const maxRetries = 1;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final delaySeconds = 2 * (1 << attempt);

      try {
        final response = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': _userAgent,
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 45));

        print('Overpass batch HTTP status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;

          // Overpass can return HTTP 200 even when the query itself timed out.
          final remark = decoded['remark']?.toString().trim() ?? '';
          if (remark.isNotEmpty) {
            print('Overpass batch returned a remark: $remark');

            final lower = remark.toLowerCase();
            final isTimeout = lower.contains('timed out') || lower.contains('timeout');

            if (isTimeout && attempt < maxRetries) {
              print('Overpass batch timed out. Retrying in ${delaySeconds}s '
                  '(attempt ${attempt + 1}/$maxRetries)...');
              await Future.delayed(Duration(seconds: delaySeconds));
              continue;
            }

            if (isTimeout) {
              print('Overpass batch failed after $maxRetries retries.');
              return null;
            }
          }

          return _parseResponse(response.body);
        }

        final retryable = response.statusCode == 429 ||
            response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504;

        if (!retryable || attempt == maxRetries) {
          print('Overpass batch failed: ${response.statusCode}');
          print('Overpass response: ${response.body}');
          return null;
        }

        print('Overpass returned ${response.statusCode}. Retrying in ${delaySeconds}s...');
        await Future.delayed(Duration(seconds: delaySeconds));
      } catch (e) {
        print('Overpass batch request error: $e');
        if (attempt == maxRetries) return null;
        print('Retrying Overpass batch in ${delaySeconds}s...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    return null;
  }

  // ============================================================
  // PARSE OVERPASS RESPONSE
  // ============================================================

  List<PlaceCandidate> _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final elements = (decoded['elements'] as List?) ?? [];

    final places = <PlaceCandidate>[];

    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;

      final tags = (raw['tags'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{};

      final name = tags['name']?.trim() ?? '';
      if (name.isEmpty) continue;

      double? lat;
      double? lng;

      // Node
      if (raw['lat'] is num && raw['lon'] is num) {
        lat = (raw['lat'] as num).toDouble();
        lng = (raw['lon'] as num).toDouble();
      }

      // Way / relation
      final center = raw['center'];
      if ((lat == null || lng == null) && center is Map) {
        if (center['lat'] is num && center['lon'] is num) {
          lat = (center['lat'] as num).toDouble();
          lng = (center['lon'] as num).toDouble();
        }
      }

      if (lat == null || lng == null) continue;

      final addressParts = <String>[];
      for (final key in const [
        'addr:housenumber',
        'addr:street',
        'addr:city',
        'addr:postcode',
      ]) {
        final v = tags[key];
        if (v != null && v.isNotEmpty) addressParts.add(v);
      }

      places.add(
        PlaceCandidate(
          name: name,
          address: addressParts.isEmpty ? 'Address not available' : addressParts.join(', '),
          location: LatLng(lat, lng),
          tags: tags.entries.map((e) => '${e.key}=${e.value}').toList(),
        ),
      );
    }

    print('Parsed ${places.length} named places');
    return places;
  }
}