import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LandMeasurementViewModel extends ChangeNotifier {
  final List<LatLng> _points = [];
  double _areaInAcres = 0;
  bool _isLocating = false;

  List<LatLng> get points => List.unmodifiable(_points);
  double get areaInAcres => _areaInAcres;
  bool get isLocating => _isLocating;
  bool get canComplete => _points.length >= 3;

  set isLocating(bool value) {
    _isLocating = value;
    notifyListeners();
  }

  void addPoint(LatLng point) {
    _points.add(point);
    _recalculate();
    notifyListeners();
  }

  void setInitialPoints(Iterable<dynamic> coords) {
    _points.clear();
    for (var c in coords) {
      if (c is Map) {
        final lat = (c['lat'] as num?)?.toDouble();
        final lng = (c['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _points.add(LatLng(lat, lng));
        }
      }
    }
    _recalculate();
  }

  void undoLastPoint() {
    if (_points.isEmpty) return;
    _points.removeLast();
    _recalculate();
    notifyListeners();
  }

  void clearAll() {
    _points.clear();
    _areaInAcres = 0;
    notifyListeners();
  }

  void _recalculate() {
    _areaInAcres = _points.length >= 3 ? _calculateArea(_points) : 0;
  }

  Map<String, dynamic> getResult() {
    return {
      'area': _areaInAcres,
      'coordinates': _points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };
  }

  /// Spherical excess formula - returns area in acres.
  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    const double earthRadius = 6371008.8;
    double area = 0;
    final int n = points.length;

    for (int i = 0; i < n; i++) {
      final int j = (i + 1) % n;
      final double xi = points[i].longitude * math.pi / 180;
      final double yi = points[i].latitude * math.pi / 180;
      final double xj = points[j].longitude * math.pi / 180;
      final double yj = points[j].latitude * math.pi / 180;
      area += (xj - xi) * (2 + math.sin(yi) + math.sin(yj));
    }

    final double areaM2 = (area * earthRadius * earthRadius / 2).abs();
    return areaM2 * 0.000247105;
  }

  Set<Marker> buildMarkers() {
    return _points.asMap().entries.map((e) {
      return Marker(
        markerId: MarkerId('pt_${e.key}'),
        position: e.value,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          e.key == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(title: 'Point ${e.key + 1}'),
      );
    }).toSet();
  }

  Set<Polyline> buildPolylines() {
    if (_points.length < 2) return {};
    final List<LatLng> path = [..._points];
    if (_points.length >= 3) path.add(_points.first);

    return {
      Polyline(
        polylineId: const PolylineId('boundary'),
        points: path,
        color: const Color(0xFF8BC34A),
        width: 3,
      ),
    };
  }

  Set<Polygon> buildPolygon() {
    if (_points.length < 3) return {};
    return {
      Polygon(
        polygonId: const PolygonId('land'),
        points: _points,
        fillColor: const Color(0xFF2E7D32).withValues(alpha: 0.25),
        strokeColor: const Color(0xFF2E7D32),
        strokeWidth: 2,
      ),
    };
  }
}
