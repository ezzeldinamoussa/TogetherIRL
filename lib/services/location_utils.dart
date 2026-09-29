import 'dart:math';

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

double haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(a.lat)) * cos(_rad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(h), sqrt(1 - h));
}

double _rad(double deg) => deg * (pi / 180);

LatLng centroidOf(List<LatLng> points) {
  final lat = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
  final lng = points.map((p) => p.lng).reduce((a, b) => a + b) / points.length;
  return LatLng(lat, lng);
}