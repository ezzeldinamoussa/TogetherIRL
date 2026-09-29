import 'dart:convert';
import 'package:http/http.dart' as http;

class GeoPoint {
  final double lat;
  final double lng;
  GeoPoint(this.lat, this.lng);
}

/// Free, keyless zip-code geocoding via zippopotam.us.
/// US zip codes only — good enough for MVP. No billing, no API key.
class GeocodingService {
  Future<GeoPoint?> geocodeZip(String zip, {String countryCode = 'us'}) async {
    final cleaned = zip.trim();
    if (cleaned.isEmpty) return null;

    final uri = Uri.parse('https://api.zippopotam.us/$countryCode/$cleaned');
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) {
      print('Zippopotam returned ${res.statusCode} for $cleaned');
      return null;
    }
    
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final places = body['places'] as List?;
      if (places == null || places.isEmpty) return null;

      final place = places.first as Map<String, dynamic>;
      final lat = double.tryParse(place['latitude'] as String? ?? '');
      final lng = double.tryParse(place['longitude'] as String? ?? '');
      if (lat == null || lng == null) return null;

      return GeoPoint(lat, lng);
    } catch (e) {
  print('Geocode error for $cleaned: $e');
  return null;
  }
  }
}