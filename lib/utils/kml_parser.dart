// KML parsing helper for the land measurement flow.
//
// Extracts a plot boundary from an uploaded `.kml` file so it can be shown as
// an editable polygon on the map. KML stores geometry as whitespace-separated
// `longitude,latitude[,altitude]` tuples (note the lng-before-lat order), so
// this converts them into [LatLng] vertices the editor understands.

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Parses [kml] and returns the vertices of its first polygon boundary.
///
/// Looks for the outer boundary of the first `<Polygon>`; if the document has
/// no polygon it falls back to the first `<coordinates>` block (covers KML
/// exported as a `LineString` / `LinearRing`). Tags with a namespace prefix
/// (e.g. `<kml:Polygon>`) are matched too. The closing vertex that KML repeats
/// to close a linear ring is dropped, since the editor closes the ring itself.
///
/// Returns an empty list when no usable coordinates are found.
List<LatLng> parseKmlPolygon(String kml) {
  final coordsBlock = _extractCoordinatesBlock(kml);
  if (coordsBlock == null) return const [];

  final points = <LatLng>[];
  for (final tuple in coordsBlock.trim().split(RegExp(r'\s+'))) {
    final parts = tuple.split(',');
    if (parts.length < 2) continue;
    final lng = double.tryParse(parts[0].trim());
    final lat = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) continue;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
    points.add(LatLng(lat, lng));
  }

  // Drop the duplicated closing vertex of a linear ring.
  if (points.length > 1 &&
      points.first.latitude == points.last.latitude &&
      points.first.longitude == points.last.longitude) {
    points.removeLast();
  }

  return points;
}

String? _extractCoordinatesBlock(String kml) {
  // Prefer the outer boundary of the first polygon, if present.
  final polygon = _firstGroup(kml, 'Polygon');
  final scope = polygon ?? kml;

  final outer = _firstGroup(scope, 'outerBoundaryIs');
  final searchIn = outer ?? scope;

  return _firstGroup(searchIn, 'coordinates');
}

/// Returns the inner content of the first `<[tag]>...</[tag]>` element,
/// tolerating an optional namespace prefix and attributes.
String? _firstGroup(String source, String tag) {
  final match = RegExp(
    '<(?:\\w+:)?$tag\\b[^>]*>(.*?)</(?:\\w+:)?$tag>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(source);
  return match?.group(1);
}
