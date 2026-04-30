import 'dart:math' as math;
import 'dart:ui' show Offset, Size;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../utils/polygon_marker_icons.dart';

/// Production-grade polygon editor state.
///
/// Manages an ordered list of vertices, computes midpoints, handles
/// undo / redo, and builds the [Marker], [Polyline], and [Polygon] sets
/// consumed by [GoogleMap].
class LandMeasurementViewModel extends ChangeNotifier {
  // ── Primary state ─────────────────────────────────────────────────────────

  final List<LatLng> _points = [];
  double _areaInAcres = 0;
  bool _isLocating = false;
  int? _activeIndex;

  /// Immediate dragging state
  int? _draggingVertexIndex;
  int? _draggingMidpointIndex;
  bool _isManualDragging = false;
  Offset? _dragOffset;

  final ValueNotifier<CameraPosition> cameraNotifier = ValueNotifier(const CameraPosition(target: LatLng(0, 0), zoom: 0));
  Size _mapSize = Size.zero;

  /// Index of the vertex currently being dragged (null when idle).
  /// We track this so we only push to the undo stack once per drag gesture.
  int? _draggingIndex;

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  final List<List<LatLng>> _undoStack = [];
  final List<List<LatLng>> _redoStack = [];
  static const int _maxUndoHistory = 50;

  // ── Cached marker icons ───────────────────────────────────────────────────

  BitmapDescriptor? _iconVertex;
  BitmapDescriptor? _iconVertexActive;
  BitmapDescriptor? _iconVertexFirst;
  BitmapDescriptor? _iconMidpoint;
  BitmapDescriptor? _iconCustomPin;

  bool _iconsReady = false;

  // ── Public getters ────────────────────────────────────────────────────────

  List<LatLng> get points => List.unmodifiable(_points);
  double get areaInAcres => _areaInAcres;
  bool get isLocating => _isLocating;
  bool get canComplete => _points.length >= 3;
  int? get activeIndex => _activeIndex;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isManualDragging => _isManualDragging;

  Offset? get activePointScreenPos {
    if (_activeIndex == null || _activeIndex! < 0 || _activeIndex! >= _points.length) {
      return null;
    }
    return _latLngToScreen(_points[_activeIndex!]);
  }

  bool isTapOnActivePoint(LatLng position) {
    if (_activeIndex == null) return false;
    final screenPos = _latLngToScreen(position);
    final activePos = _latLngToScreen(_points[_activeIndex!]);
    final dx = screenPos.dx - activePos.dx;
    final dy = screenPos.dy - activePos.dy;
    // Bounding box for CustomMapPin (width 48, height 64)
    return dx >= -24 && dx <= 24 && dy >= 0 && dy <= 64;
  }

  void updateCamera(CameraPosition pos) {
    cameraNotifier.value = pos;
  }

  void updateMapSize(Size size) {
    _mapSize = size;
  }

  set isLocating(bool value) {
    _isLocating = value;
    notifyListeners();
  }

  // ── Icon preloading ───────────────────────────────────────────────────────

  /// Must be called once (e.g. from the widget's [initState]) before the first
  /// frame that reads markers.
  Future<void> loadIcons() async {
    await PolygonMarkerIcons.preload();
    _iconVertex = await PolygonMarkerIcons.vertex();
    _iconVertexActive = await PolygonMarkerIcons.vertexActive();
    _iconVertexFirst = await PolygonMarkerIcons.vertexFirst();
    _iconMidpoint = await PolygonMarkerIcons.midpoint();
    _iconCustomPin = await PolygonMarkerIcons.customPin();
    _iconsReady = true;
    notifyListeners();
  }

  // ── Point CRUD ────────────────────────────────────────────────────────────

  /// Append a new vertex at the end of the polygon.
  void addPoint(LatLng point) {
    _pushUndo();
    _points.add(point);
    _activeIndex = null; // Do not automatically select the new point
    _recalculate();
    notifyListeners();
  }

  /// Insert a vertex at [index], splitting the edge between
  /// `_points[index - 1]` and `_points[index]`.
  void insertPointAt(int index, LatLng point) {
    _pushUndo();
    _points.insert(index, point);
    _activeIndex = index;
    _recalculate();
    notifyListeners();
  }

  /// Move an existing vertex during a drag gesture.
  /// Does **not** push to the undo stack (that happens on drag-end).
  void updatePoint(int index, LatLng position) {
    if (index < 0 || index >= _points.length) return;
    _points[index] = position;
    _activeIndex = index;
    _recalculate();
    notifyListeners();
  }

  /// Call when a vertex drag **starts** — snapshots the pre-drag state.
  void beginDrag(int index) {
    if (_draggingIndex == null) {
      _pushUndo();
      _draggingIndex = index;
    }
    _activeIndex = index;
    notifyListeners();
  }

  /// Call when a vertex drag **ends**.
  void endDrag(int index, LatLng finalPosition) {
    if (index < 0 || index >= _points.length) return;
    _points[index] = finalPosition;
    _draggingIndex = null;
    _recalculate();
    notifyListeners();
  }

  /// Remove a vertex. Returns `true` if the point was removed.
  bool removePoint(int index) {
    if (index < 0 || index >= _points.length) return false;
    _pushUndo();
    _points.removeAt(index);
    // Adjust active index
    if (_activeIndex != null) {
      if (_activeIndex == index) {
        _activeIndex = _points.isEmpty ? null : index.clamp(0, _points.length - 1);
      } else if (_activeIndex! > index) {
        _activeIndex = _activeIndex! - 1;
      }
    }
    _recalculate();
    notifyListeners();
    return true;
  }

  void setActiveIndex(int? index) {
    _activeIndex = index;
    notifyListeners();
  }

  // ── Manual Dragging (Listener-based) ──────────────────────────────────────

  /// Attempts to start a drag gesture from a screen position.
  /// Returns true if a point was captured.
  bool handlePointerDown(Offset localPos) {
    if (_points.isEmpty || _mapSize == Size.zero) return false;

    const double hitRadius = 24.0; // pixels

    // 1. Check vertices first (higher priority)
    for (int i = 0; i < _points.length; i++) {
      final screenPos = _latLngToScreen(_points[i]);
      
      bool isHit = false;
      if (i == _activeIndex) {
        // Active point uses CustomMapPin bounds (width 48, height 64, hanging down from tip)
        final dx = localPos.dx - screenPos.dx;
        final dy = localPos.dy - screenPos.dy;
        if (dx >= -24 && dx <= 24 && dy >= 0 && dy <= 64) {
          isHit = true;
        }
      } else {
        // Normal point uses circle radius
        if ((screenPos - localPos).distance < hitRadius) {
          isHit = true;
        }
      }

      if (isHit) {
        _dragOffset = localPos - screenPos;
        _draggingVertexIndex = i;
        _isManualDragging = true;
        _activeIndex = i;
        _pushUndo();
        notifyListeners();
        return true;
      }
    }

    // 2. Check midpoints
    final mids = midpoints;
    for (int i = 0; i < mids.length; i++) {
      final screenPos = _latLngToScreen(mids[i]);
      if ((screenPos - localPos).distance < hitRadius) {
        // Promote midpoint to vertex
        final insertIndex = i + 1;
        _pushUndo();
        _points.insert(insertIndex, mids[i]);
        _dragOffset = localPos - screenPos;
        _draggingVertexIndex = insertIndex;
        _isManualDragging = true;
        _activeIndex = insertIndex;
        _recalculate();
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  void handlePointerMove(Offset localPos) {
    if (!_isManualDragging || _draggingVertexIndex == null) return;

    final targetScreenPos = localPos - (_dragOffset ?? Offset.zero);
    final newLatLng = _screenToLatLng(targetScreenPos);
    _points[_draggingVertexIndex!] = newLatLng;
    _activeIndex = _draggingVertexIndex;
    _recalculate();
    notifyListeners();
  }

  void handlePointerUp() {
    if (_isManualDragging) {
      _isManualDragging = false;
      _draggingVertexIndex = null;
      _draggingMidpointIndex = null;
      _dragOffset = null;
      _recalculate();
      notifyListeners();
    }
  }

  // ── Projection Math ───────────────────────────────────────────────────────

  Offset _latLngToScreen(LatLng latLng) {
    if (_mapSize == Size.zero) return Offset.zero;

    final worldSize = math.pow(2, cameraNotifier.value.zoom) * 256.0;
    final centerPoint = _project(cameraNotifier.value.target);
    final targetPoint = _project(latLng);

    double dx = (targetPoint.dx - centerPoint.dx) * worldSize;
    double dy = (targetPoint.dy - centerPoint.dy) * worldSize;

    // Handle rotation (bearing)
    if (cameraNotifier.value.bearing != 0) {
      final angle = -cameraNotifier.value.bearing * math.pi / 180;
      final rx = dx * math.cos(angle) - dy * math.sin(angle);
      final ry = dx * math.sin(angle) + dy * math.cos(angle);
      dx = rx;
      dy = ry;
    }

    return Offset(_mapSize.width / 2 + dx, _mapSize.height / 2 + dy);
  }

  LatLng _screenToLatLng(Offset offset) {
    if (_mapSize == Size.zero) return const LatLng(0, 0);

    final worldSize = math.pow(2, cameraNotifier.value.zoom) * 256.0;
    double dx = offset.dx - _mapSize.width / 2;
    double dy = offset.dy - _mapSize.height / 2;

    // Handle rotation (inverse bearing)
    if (cameraNotifier.value.bearing != 0) {
      final angle = cameraNotifier.value.bearing * math.pi / 180;
      final rx = dx * math.cos(angle) - dy * math.sin(angle);
      final ry = dx * math.sin(angle) + dy * math.cos(angle);
      dx = rx;
      dy = ry;
    }

    final centerPoint = _project(cameraNotifier.value.target);
    final x = centerPoint.dx + dx / worldSize;
    final y = centerPoint.dy + dy / worldSize;

    // Unproject Web Mercator
    final lng = x * 360 - 180;
    final n = math.pi - 2 * math.pi * y;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));

    return LatLng(lat, lng);
  }

  Offset _project(LatLng latLng) {
    final sinLat = math.sin(latLng.latitude * math.pi / 180);
    final x = (latLng.longitude + 180) / 360;
    final y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi));
    return Offset(x, y);
  }

  /// Set initial points (e.g. when viewing a saved polygon).
  void setInitialPoints(Iterable<dynamic> coords) {
    _points.clear();
    _undoStack.clear();
    _redoStack.clear();
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

  void clearAll() {
    if (_points.isNotEmpty) _pushUndo();
    _points.clear();
    _activeIndex = null;
    _areaInAcres = 0;
    notifyListeners();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.of(_points));
    _points
      ..clear()
      ..addAll(_undoStack.removeLast());
    _activeIndex = null;
    _recalculate();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.of(_points));
    _points
      ..clear()
      ..addAll(_redoStack.removeLast());
    _activeIndex = null;
    _recalculate();
    notifyListeners();
  }

  void _pushUndo() {
    _undoStack.add(List.of(_points));
    if (_undoStack.length > _maxUndoHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  // ── Result ────────────────────────────────────────────────────────────────

  Map<String, dynamic> getResult() {
    return {
      'area': _areaInAcres,
      'coordinates': _points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };
  }

  // ── Midpoint helpers ──────────────────────────────────────────────────────

  /// Computes the midpoint positions between consecutive vertices.
  /// When ≥ 3 points exist the list wraps around (last → first).
  List<LatLng> get midpoints {
    if (_points.length < 2) return const [];
    final mids = <LatLng>[];
    final n = _points.length;
    final wrap = n >= 3;
    final count = wrap ? n : n - 1;
    for (int i = 0; i < count; i++) {
      final a = _points[i];
      final b = _points[(i + 1) % n];
      mids.add(LatLng(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      ));
    }
    return mids;
  }

  // ── Area calculation ──────────────────────────────────────────────────────

  void _recalculate() {
    _areaInAcres = _points.length >= 3 ? _calculateArea(_points) : 0;
  }

  /// Spherical excess formula — returns area in acres.
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

  // ── Marker / Polygon / Polyline builders ──────────────────────────────────

  /// Builds the complete marker set: vertex markers + midpoint markers.
  Set<Marker> buildMarkers({bool viewOnly = false}) {
    final markers = <Marker>{};

    // ── Vertex markers ──────────────────────────────────────────────────────
    for (int i = 0; i < _points.length; i++) {
      final isActive = i == _activeIndex;
      final isFirst = i == 0;

      BitmapDescriptor icon;
      Offset anchor = const Offset(0.5, 0.5);

      if (!_iconsReady) {
        // Fallback while icons load
        icon = BitmapDescriptor.defaultMarkerWithHue(
          isFirst ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
        );
      } else if (isActive && !viewOnly) {
        icon = _iconCustomPin!;
        anchor = const Offset(0.5, 0.0); // Upside-down pin anchor is top-center
      } else if (isFirst) {
        icon = _iconVertexFirst!;
      } else {
        icon = _iconVertex!;
      }

      final index = i; // capture for closures
      markers.add(Marker(
        markerId: MarkerId('vertex_$index'),
        position: _points[index],
        icon: icon,
        anchor: anchor,
        draggable: false, // We handle dragging manually for immediate response
        zIndexInt: isActive ? 3 : 2,
        onTap: () => setActiveIndex(index),
      ));
    }

    // ── Midpoint markers (edit-mode only) ───────────────────────────────────
    if (!viewOnly && _points.length >= 2) {
      final mids = midpoints;
      for (int i = 0; i < mids.length; i++) {
        final insertIndex = i + 1;

        markers.add(Marker(
          markerId: MarkerId('mid_$i'),
          position: mids[i],
          icon: _iconsReady
              ? _iconMidpoint!
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
          draggable: false, // Handled manually
          zIndexInt: 1,
        ));
      }
    }

    return markers;
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
