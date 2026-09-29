import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'location_utils.dart';

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

  static const _userAgent =
      'TogetherIRL/1.0 (contact: mmorcos434@gmail.com)';

  static const Map<String, String> _activityFilters = {
    'restaurant': '["amenity"="restaurant"]',
    'fast_food': '["amenity"="fast_food"]',
    'cafe': '["amenity"="cafe"]',
    'bakery': '["shop"="bakery"]',
    'ice_cream': '["amenity"="ice_cream"]',
    'cinema': '["amenity"="cinema"]',
    'theatre': '["amenity"="theatre"]',
    'museum': '["tourism"="museum"]',
    'gallery': '["tourism"="gallery"]',
    'park': '["leisure"="park"]',
    'garden': '["leisure"="garden"]',
    'beach': '["natural"="beach"]',
    'bowling': '["sport"="10pin"]',
    'arts': '["amenity"="arts_centre"]',

    // This is intentionally NOT used as a broad nwr["shop"]
    // because that can make Overpass extremely slow.
  };

  static const Map<String, String> _cuisineMap = {
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

  Future<List<PlaceCandidate>> searchArea({
    required LatLng center,
    required double radiusKm,
    List<String> activityTypes = const [],
    List<String> foodPreferences = const [],
  }) async {
    final radiusMeters = (radiusKm * 1000).round();

    final clauses = <String>[];

    // ------------------------------------------------------------
    // ACTIVITIES
    // ------------------------------------------------------------

    for (final activity in activityTypes) {
      final filter = _activityFilters[activity];

      if (filter != null) {
        clauses.add(
          'nwr$filter'
          '(around:$radiusMeters,${center.lat},${center.lng});',
        );
      }
    }

    // ------------------------------------------------------------
    // FOOD
    // ------------------------------------------------------------

    // Always include fast food as an option.
    // This is important for low-budget / activity-heavy days.
    clauses.add(
      'nwr["amenity"="fast_food"]'
      '(around:$radiusMeters,${center.lat},${center.lng});',
    );

    // Normal restaurants.
    clauses.add(
      'nwr["amenity"="restaurant"]'
      '(around:$radiusMeters,${center.lat},${center.lng});',
    );

    // Cafes.
    clauses.add(
      'nwr["amenity"="cafe"]'
      '(around:$radiusMeters,${center.lat},${center.lng});',
    );

    // Bakeries.
    clauses.add(
      'nwr["shop"="bakery"]'
      '(around:$radiusMeters,${center.lat},${center.lng});',
    );

    // Ice cream.
    clauses.add(
      'nwr["amenity"="ice_cream"]'
      '(around:$radiusMeters,${center.lat},${center.lng});',
    );

    // ------------------------------------------------------------
    // CUISINE-SPECIFIC RESTAURANTS
    // ------------------------------------------------------------

    for (final food in foodPreferences) {
      final cuisine = _cuisineMap[food];

      if (cuisine != null) {
        clauses.add(
          'nwr["amenity"="restaurant"]["cuisine"~'
          '"(^|;)${RegExp.escape(cuisine)}(;|\$)",i]'
          '(around:$radiusMeters,${center.lat},${center.lng});',
        );
      }
    }

    // If nothing was requested, still give the AI useful options.
    if (clauses.isEmpty) {
      clauses.add(
        'nwr["amenity"="restaurant"]'
        '(around:$radiusMeters,${center.lat},${center.lng});',
      );

      clauses.add(
        'nwr["amenity"="fast_food"]'
        '(around:$radiusMeters,${center.lat},${center.lng});',
      );

      clauses.add(
        'nwr["amenity"="cafe"]'
        '(around:$radiusMeters,${center.lat},${center.lng});',
      );
    }

    print(
      'Searching Overpass with ${clauses.length} filters '
      'within ${radiusKm.toStringAsFixed(1)} km...',
    );

    return _runQuery(
      center: center,
      radiusMeters: radiusMeters,
      clauses: clauses,
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
    const batchSize = 3;

    final batches = <List<String>>[];

    for (var i = 0; i < clauses.length; i += batchSize) {
      final end = math.min(i + batchSize, clauses.length);

      batches.add(
        clauses.sublist(i, end),
      );
    }

    print(
      'Splitting Overpass search into '
      '${batches.length} smaller queries...',
    );

    final allPlaces = <PlaceCandidate>[];

    final seenPlaces = <String>{};

    for (var i = 0; i < batches.length; i++) {
      final batch = batches[i];

      print(
        'Running Overpass batch ${i + 1}/${batches.length} '
        'with ${batch.length} filters...',
      );

      final places = await _runOverpassBatch(
        center: center,
        radiusMeters: radiusMeters,
        clauses: batch,
      );

      print(
        'Batch ${i + 1} returned '
        '${places.length} named places',
      );

      for (final place in places) {
        final key =
            '${place.name}|'
            '${place.location.lat.toStringAsFixed(6)}|'
            '${place.location.lng.toStringAsFixed(6)}';

        if (seenPlaces.add(key)) {
          allPlaces.add(place);
        }
      }
    }

    print(
      'Combined Overpass result: '
      '${allPlaces.length} unique named places',
    );

    return allPlaces;
  }

  // ============================================================
  // SINGLE OVERPASS REQUEST
  // ============================================================

  Future<List<PlaceCandidate>> _runOverpassBatch({
    required LatLng center,
    required int radiusMeters,
    required List<String> clauses,
  }) async {
    final query = '''
[out:json][timeout:60];
(
  ${clauses.join('\n')}
);
out center qt;
''';

    const maxRetries = 3;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type':
                    'application/x-www-form-urlencoded',
                'User-Agent': _userAgent,
              },
              body: {
                'data': query,
              },
            )
            .timeout(
              const Duration(seconds: 90),
            );

        print(
          'Overpass batch HTTP status: '
          '${response.statusCode}',
        );

        // --------------------------------------------------------
        // HTTP SUCCESS
        // --------------------------------------------------------

        if (response.statusCode == 200) {
          final decoded =
              jsonDecode(response.body) as Map<String, dynamic>;

          // IMPORTANT:
          //
          // Overpass can return HTTP 200 even when the query
          // itself timed out.
          //
          // Example:
          // {
          //   "remark": "runtime error: Query timed out..."
          // }
          //
          final remark = decoded['remark'];

          if (remark != null &&
              remark.toString().trim().isNotEmpty) {
            final remarkText =
                remark.toString();

            print(
              'Overpass batch returned a remark: '
              '$remarkText',
            );

            final lower =
                remarkText.toLowerCase();

            final isTimeout =
                lower.contains('timed out') ||
                lower.contains('timeout');

            if (isTimeout &&
                attempt < maxRetries) {
              final delaySeconds =
                  2 * (1 << attempt);

              print(
                'Overpass batch timed out. '
                'Retrying in ${delaySeconds}s '
                '(attempt '
                '${attempt + 1}/$maxRetries)...',
              );

              await Future.delayed(
                Duration(seconds: delaySeconds),
              );

              continue;
            }

            // Do NOT treat a failed Overpass response
            // as an empty successful result.
            if (isTimeout) {
              print(
                'Overpass batch failed after '
                '$maxRetries retries.',
              );

              return [];
            }
          }

          return _parseResponse(
            response.body,
          );
        }

        // --------------------------------------------------------
        // RETRYABLE HTTP ERRORS
        // --------------------------------------------------------

        final retryable =
            response.statusCode == 429 ||
            response.statusCode == 503 ||
            response.statusCode == 504;

        if (!retryable ||
            attempt == maxRetries) {
          print(
            'Overpass batch failed: '
            '${response.statusCode}',
          );

          print(
            'Overpass response: '
            '${response.body}',
          );

          return [];
        }

        final delaySeconds =
            2 * (1 << attempt);

        print(
          'Overpass returned '
          '${response.statusCode}. '
          'Retrying in ${delaySeconds}s...',
        );

        await Future.delayed(
          Duration(seconds: delaySeconds),
        );
      } catch (e) {
        print(
          'Overpass batch request error: $e',
        );

        if (attempt == maxRetries) {
          return [];
        }

        final delaySeconds =
            2 * (1 << attempt);

        print(
          'Retrying Overpass batch in '
          '${delaySeconds}s...',
        );

        await Future.delayed(
          Duration(seconds: delaySeconds),
        );
      }
    }

    return [];
  }

  // ============================================================
  // PARSE OVERPASS RESPONSE
  // ============================================================

  List<PlaceCandidate> _parseResponse(
    String responseBody,
  ) {
    final decoded =
        jsonDecode(responseBody)
            as Map<String, dynamic>;

    final elements =
        (decoded['elements'] as List?) ?? [];

    final places = <PlaceCandidate>[];

    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final tags =
          (raw['tags'] as Map?)?.map(
                (key, value) =>
                    MapEntry(
                  key.toString(),
                  value.toString(),
                ),
              ) ??
              <String, String>{};

      final name =
          tags['name']?.trim() ?? '';

      if (name.isEmpty) {
        continue;
      }

      double? lat;
      double? lng;

      // Node
      if (raw['lat'] is num &&
          raw['lon'] is num) {
        lat = (raw['lat'] as num).toDouble();
        lng = (raw['lon'] as num).toDouble();
      }

      // Way / relation
      final center =
          raw['center'];

      if ((lat == null || lng == null) &&
          center is Map) {
        if (center['lat'] is num &&
            center['lon'] is num) {
          lat =
              (center['lat'] as num).toDouble();

          lng =
              (center['lon'] as num).toDouble();
        }
      }

      if (lat == null || lng == null) {
        continue;
      }

      final addressParts = <String>[];

      final houseNumber =
          tags['addr:housenumber'];

      final street =
          tags['addr:street'];

      final city =
          tags['addr:city'];

      final postcode =
          tags['addr:postcode'];

      if (houseNumber != null &&
          houseNumber.isNotEmpty) {
        addressParts.add(houseNumber);
      }

      if (street != null &&
          street.isNotEmpty) {
        addressParts.add(street);
      }

      if (city != null &&
          city.isNotEmpty) {
        addressParts.add(city);
      }

      if (postcode != null &&
          postcode.isNotEmpty) {
        addressParts.add(postcode);
      }

      final address =
          addressParts.isEmpty
              ? 'Address not available'
              : addressParts.join(', ');

      places.add(
        PlaceCandidate(
          name: name,
          address: address,
          location: LatLng(lat, lng),
          tags: tags.entries
              .map(
                (entry) =>
                    '${entry.key}=${entry.value}',
              )
              .toList(),
        ),
      );
    }

    print(
      'Parsed ${places.length} named places',
    );

    return places;
  }
}