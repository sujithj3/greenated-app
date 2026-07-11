import 'dart:math' as math;

/// Area (in acres) and perimeter (in meters) of a lat/lng polygon.
///
/// The formulas mirror those in `LandMeasurementViewModel` (spherical-excess
/// for area, haversine for edge lengths, sharing the same mean Earth radius) so
/// the metrics shown on a saved `MAP_POLYGON` field match the figures the user
/// saw on the live land-measurement screen exactly.
class LandPolygonMetrics {
  const LandPolygonMetrics({
    required this.areaInAcres,
    required this.perimeterInMeters,
  });

  final double areaInAcres;
  final double perimeterInMeters;

  /// Mean Earth radius in meters — identical to the value used by the
  /// land-measurement view model.
  static const double _earthRadius = 6371008.8;

  /// Builds metrics from the raw value stored by a `MAP_POLYGON` field: a list
  /// of `{'lat': .., 'lng': ..}` maps. Returns null when fewer than 3 valid
  /// vertices are present, i.e. there is no closed polygon to measure.
  static LandPolygonMetrics? fromCoordinates(List<dynamic>? coordinates) {
    if (coordinates == null) return null;
    final lat = <double>[];
    final lng = <double>[];
    for (final coordinate in coordinates) {
      if (coordinate is Map) {
        final rawLat = (coordinate['lat'] as num?)?.toDouble();
        final rawLng = (coordinate['lng'] as num?)?.toDouble();
        if (rawLat != null && rawLng != null) {
          lat.add(rawLat);
          lng.add(rawLng);
        }
      }
    }
    if (lat.length < 3) return null;
    return LandPolygonMetrics(
      areaInAcres: _areaInAcres(lat, lng),
      perimeterInMeters: _perimeterInMeters(lat, lng),
    );
  }

  /// Area to 4 decimal places of acres, abbreviated, e.g. `1.2345 Ac`.
  String get formattedArea => '${areaInAcres.toStringAsFixed(4)} Ac';

  /// Perimeter as km above 1000 m, otherwise m — matching the formatting used
  /// on the land-measurement screen.
  String get formattedPerimeter {
    if (perimeterInMeters >= 1000) {
      return '${(perimeterInMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${perimeterInMeters.toStringAsFixed(2)} m';
  }

  // ── Geometry ────────────────────────────────────────────────────────────

  /// Spherical-excess area of the closed polygon, converted to acres.
  static double _areaInAcres(List<double> lat, List<double> lng) {
    final int n = lat.length;
    double area = 0;
    for (int i = 0; i < n; i++) {
      final int j = (i + 1) % n;
      final double xi = lng[i] * math.pi / 180;
      final double yi = lat[i] * math.pi / 180;
      final double xj = lng[j] * math.pi / 180;
      final double yj = lat[j] * math.pi / 180;
      area += (xj - xi) * (2 + math.sin(yi) + math.sin(yj));
    }
    final double areaM2 = (area * _earthRadius * _earthRadius / 2).abs();
    return areaM2 * 0.000247105; // m² → acres
  }

  /// Sum of the great-circle lengths of every edge of the closed polygon.
  static double _perimeterInMeters(List<double> lat, List<double> lng) {
    final int n = lat.length;
    double total = 0;
    for (int i = 0; i < n; i++) {
      final int j = (i + 1) % n;
      total += _distanceBetween(lat[i], lng[i], lat[j], lng[j]);
    }
    return total;
  }

  /// Haversine great-circle distance between two coordinates, in meters.
  static double _distanceBetween(
    double lat1deg,
    double lng1deg,
    double lat2deg,
    double lng2deg,
  ) {
    final double lat1 = lat1deg * math.pi / 180;
    final double lat2 = lat2deg * math.pi / 180;
    final double deltaLat = (lat2deg - lat1deg) * math.pi / 180;
    final double deltaLng = (lng2deg - lng1deg) * math.pi / 180;

    final double haversine = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final double normalizedHaversine = haversine.clamp(0, 1).toDouble();
    final double centralAngle = 2 *
        math.atan2(
          math.sqrt(normalizedHaversine),
          math.sqrt(1 - normalizedHaversine),
        );
    return _earthRadius * centralAngle;
  }
}
