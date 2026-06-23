// SETUP REQUIRED FOR GOOGLE MAPS:
// Android — add inside <application> in android/app/src/main/AndroidManifest.xml:
//   <meta-data android:name="com.google.android.geo.API_KEY"
//              android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
//
// iOS — add to ios/Runner/AppDelegate.swift:
//   import GoogleMaps
//   GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/tools/land_measurement_view_model.dart';
import '../../widgets/custom_map_pin.dart';

class LandMeasurementView extends StatefulWidget {
  const LandMeasurementView({super.key});

  @override
  State<LandMeasurementView> createState() => _LandMeasurementViewState();
}

class _LandMeasurementViewState extends State<LandMeasurementView> {
  // Flutter-owned map controller stays in View
  GoogleMapController? _mapController;
  Position? _cachedPosition;
  MapType _mapType = MapType.hybrid;

  late final LandMeasurementViewModel _vm;
  bool _didAutoLocate = false;
  bool _hasLocationPermission = false;

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629), // India center
    zoom: 5,
  );

  @override
  void initState() {
    super.initState();
    _vm = LandMeasurementViewModel();
    _vm.loadIcons(); // Pre-warm custom marker icon cache
  }

  bool _isInit = false;
  bool _viewOnly = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _viewOnly = args['viewOnly'] as bool? ?? false;
        if (args['initialPolygon'] != null) {
          final initialPolygons = args['initialPolygon'] as Iterable<dynamic>;
          _vm.setInitialPoints(initialPolygons);
        }
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ─── Location ────────────────────────────────────────────────────────────

  void _setLocationPermissionGranted(bool granted) {
    if (!mounted || _hasLocationPermission == granted) return;
    setState(() => _hasLocationPermission = granted);
  }

  Future<void> _goToMyLocation() async {
    if (_vm.isLocating) return;
    _vm.isLocating = true;

    try {
      final hasAccess = await _ensureLocationAccess();
      if (!hasAccess) {
        _vm.isLocating = false;
        return;
      }

      final cachedPosition =
          _cachedPosition ?? await Geolocator.getLastKnownPosition();
      if (cachedPosition != null) {
        _cachedPosition = cachedPosition;
        _moveCameraToPosition(cachedPosition, zoom: 17);
        _vm.isLocating = false;
        unawaited(_refreshCurrentLocation(fallbackPosition: cachedPosition));
        return;
      }

      await _refreshCurrentLocation();
    } catch (e) {
      _vm.isLocating = false;
      if (mounted) context.showSnack('Could not get location: $e');
    }
  }

  Future<bool> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setLocationPermissionGranted(false);
      if (mounted) context.showSnack('Location services are disabled.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setLocationPermissionGranted(false);
        if (mounted) context.showSnack('Location permission denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setLocationPermissionGranted(false);
      if (mounted) context.showSnack('Location permission permanently denied.');
      return false;
    }

    _setLocationPermissionGranted(true);
    return true;
  }

  Future<void> _refreshCurrentLocation({Position? fallbackPosition}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      _cachedPosition = position;
      _moveCameraToPosition(position, zoom: 18);
    } on TimeoutException {
      if (fallbackPosition == null && mounted) {
        context
            .showSnack('Timed out while fetching location. Please try again.');
      }
    } catch (e) {
      if (fallbackPosition == null && mounted) {
        context.showSnack('Could not get location: $e');
      }
    } finally {
      _vm.isLocating = false;
    }
  }

  void _moveCameraToPosition(Position position, {double zoom = 18}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  // ─── Map interactions ─────────────────────────────────────────────────────

  void _onTap(LatLng position) {
    if (_vm.activeIndex != null) {
      if (_vm.isTapOnActivePoint(position)) {
        return; // Ignore the native tap event if it was actually on the active marker
      }
      _vm.setActiveIndex(null); // Hide the custom pin by deselecting
    } else {
      _vm.addPoint(position);
    }
  }

  void _done() {
    if (!_vm.canComplete) {
      context.showSnack('Mark at least 3 points to define a land boundary.');
      return;
    }
    Navigator.pop(context, _vm.getResult());
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final points = _vm.points;
        return Scaffold(
          appBar: AppBar(
            title: Text(_viewOnly ? 'View Land Boundary' : 'Land Measurement'),
            actions: [
              if (!_viewOnly && _vm.canComplete)
                TextButton.icon(
                  onPressed: _done,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Done',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          body: Stack(
            children: [
              // ── Google Map ──────────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  // Keep map size in sync for projection math
                  _vm.updateMapSize(
                      Size(constraints.maxWidth, constraints.maxHeight));

                  return Listener(
                    onPointerDown: (event) {
                      if (!_viewOnly) {
                        _vm.handlePointerDown(event.localPosition);
                      }
                    },
                    onPointerMove: (event) {
                      if (!_viewOnly && _vm.isManualDragging) {
                        _vm.handlePointerMove(event.localPosition);
                      }
                    },
                    onPointerUp: (event) {
                      if (!_viewOnly) {
                        _vm.handlePointerUp();
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GoogleMap(
                          onMapCreated: (ctrl) {
                            _mapController = ctrl;
                            // Initialize VM camera state
                            final initialPos = points.isNotEmpty
                                ? CameraPosition(target: points.first, zoom: 18)
                                : _defaultCamera;
                            _vm.updateCamera(initialPos);
                            if (points.isEmpty && !_didAutoLocate) {
                              _didAutoLocate = true;
                              unawaited(_goToMyLocation());
                            }
                          },
                          initialCameraPosition: points.isNotEmpty
                              ? CameraPosition(target: points.first, zoom: 18)
                              : _defaultCamera,
                          mapType: _mapType,
                          myLocationEnabled: _hasLocationPermission,
                          myLocationButtonEnabled: false,
                          onTap: _viewOnly ? null : _onTap,
                          onCameraMove: (pos) => _vm.updateCamera(pos),
                          markers: _vm.buildMarkers(viewOnly: _viewOnly),
                          polylines: _vm.buildPolylines(),
                          polygons: _vm.buildPolygon(),
                          zoomControlsEnabled: false,
                          scrollGesturesEnabled: !_vm.isManualDragging,
                          rotateGesturesEnabled: !_vm.isManualDragging,
                          tiltGesturesEnabled: !_vm.isManualDragging,
                          zoomGesturesEnabled: !_vm.isManualDragging,
                        ),
                        if (!_vm.isManualDragging)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ValueListenableBuilder<CameraPosition>(
                                valueListenable: _vm.cameraNotifier,
                                builder: (context, _, __) {
                                  return CustomPaint(
                                    painter: _LandDistanceLabelPainter(
                                      edges: _vm.edgeMeasurements,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (_vm.isManualDragging)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ValueListenableBuilder<int>(
                                valueListenable: _vm.dragOverlayNotifier,
                                builder: (context, _, __) {
                                  final activePoint = _vm.activePointScreenPos;
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CustomPaint(
                                        painter: _LandDragOverlayPainter(
                                          points: _vm.pointScreenPositions,
                                          midpoints:
                                              _vm.midpointScreenPositions,
                                          activeIndex: _vm.activeIndex,
                                        ),
                                      ),
                                      CustomPaint(
                                        painter: _LandDistanceLabelPainter(
                                          edges: _vm.edgeMeasurements,
                                        ),
                                      ),
                                      if (activePoint != null)
                                        Positioned(
                                          left: activePoint.dx - 24,
                                          top: activePoint.dy,
                                          child: const CustomMapPin(
                                            width: 48,
                                            height: 64,
                                            iconSize: 36,
                                            isUpsideDown: true,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // ── Top Info Panel ────────────────────────────────────────
              Positioned(
                top: _vm.canComplete ? 0 : 12,
                left: _vm.canComplete ? 0 : 12,
                right: _vm.canComplete ? 0 : 12,
                child: ValueListenableBuilder<int>(
                  valueListenable: _vm.dragOverlayNotifier,
                  builder: (context, _, __) => _buildInfoPanel(points),
                ),
              ),

              // ── Bottom Controls ───────────────────────────────────────
              Positioned(
                bottom: 16,
                right: 16,
                child: _buildControlButtons(points),
              ),

              // ── Done FAB (bottom-left) ────────────────────────────────
              if (!_viewOnly && _vm.canComplete)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'done',
                    onPressed: _done,
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      '${_vm.areaInAcres.toStringAsFixed(3)} Ac',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Info Panel ───────────────────────────────────────────────────────────

  Widget _buildInfoPanel(List<LatLng> points) {
    String primary;
    String? secondary;

    if (points.length >= 3) {
      return Container(
        color: Colors.black.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Area ${_vm.areaInAcres.toStringAsFixed(4)} Acres',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Perimeter ${_formatPerimeter(_vm.perimeterInMeters)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_viewOnly) {
      if (points.isEmpty) {
        primary = 'No boundary points recorded';
      } else if (points.length < 3) {
        primary = '${points.length} point(s) recorded';
      } else {
        primary = 'Area: ${_vm.areaInAcres.toStringAsFixed(4)} Acres';
      }
    } else {
      if (points.isEmpty) {
        primary = 'Tap on the map to start drawing';
      } else if (points.length < 3) {
        primary = 'Add ${3 - points.length} more point(s) to form polygon';
      } else {
        primary = 'Area: ${_vm.areaInAcres.toStringAsFixed(4)} Acres';
        secondary = 'Drag points to adjust • Drag gray dots to add vertices';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    primary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  if (points.isNotEmpty)
                    Text(
                      '${points.length} point(s) marked',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMedium),
                    ),
                  if (secondary != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        secondary,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.medium,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPerimeter(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(2)} m';
  }

  // ─── Control Buttons ──────────────────────────────────────────────────────

  Widget _buildControlButtons(List<LatLng> points) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Map type toggle
        FloatingActionButton.small(
          heroTag: 'maptype',
          onPressed: () => setState(() {
            _mapType =
                _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
          }),
          backgroundColor: Colors.white,
          child: Icon(
            _mapType == MapType.hybrid ? Icons.map : Icons.satellite_alt,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),

        // My location
        FloatingActionButton.small(
          heroTag: 'locate',
          onPressed: _vm.isLocating ? null : _goToMyLocation,
          backgroundColor: Colors.white,
          child: _vm.isLocating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, color: AppColors.primary),
        ),

        if (!_viewOnly) ...[
          const SizedBox(height: 8),

          // Undo
          FloatingActionButton.small(
            heroTag: 'undo',
            onPressed: _vm.canUndo ? _vm.undo : null,
            backgroundColor: _vm.canUndo ? Colors.white : Colors.grey.shade300,
            child: Icon(
              Icons.undo,
              color: _vm.canUndo ? AppColors.warning : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          // Redo
          FloatingActionButton.small(
            heroTag: 'redo',
            onPressed: _vm.canRedo ? _vm.redo : null,
            backgroundColor: _vm.canRedo ? Colors.white : Colors.grey.shade300,
            child: Icon(
              Icons.redo,
              color: _vm.canRedo ? AppColors.warning : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          // Clear all
          FloatingActionButton.small(
            heroTag: 'clear',
            onPressed: points.isEmpty
                ? null
                : () {
                    _vm.clearAll();
                    final args =
                        ModalRoute.of(context)?.settings.arguments as Map?;
                    if (args != null && args['onClear'] != null) {
                      args['onClear']();
                    }
                  },
            backgroundColor:
                points.isEmpty ? Colors.grey.shade300 : Colors.white,
            child: Icon(Icons.delete_outline,
                color: points.isEmpty ? Colors.grey : AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _LandDistanceLabelPainter extends CustomPainter {
  const _LandDistanceLabelPainter({
    required this.edges,
  });

  final List<EdgeMeasurement> edges;

  static const Color _labelFill = Color(0x8F000000);
  static const double _horizontalPadding = 7;
  static const double _verticalPadding = 3;
  static const double _midpointHandleRadius = 6.5;
  static const double _labelCircleGap = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final label = _formatDistance(edge.distanceInMeters);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelWidth = textPainter.width + (_horizontalPadding * 2);
      final labelHeight = textPainter.height + (_verticalPadding * 2);
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: labelWidth,
          height: labelHeight,
        ),
        const Radius.circular(3),
      );

      double angle = edge.screenAngle;
      if (angle > math.pi / 2 || angle < -math.pi / 2) {
        angle += math.pi;
      }

      final labelCenter = _labelCenterForEdge(
        edge: edge,
        labelSize: Size(labelWidth, labelHeight),
      );

      canvas
        ..save()
        ..translate(labelCenter.dx, labelCenter.dy)
        ..rotate(angle)
        ..drawRRect(
          labelRect,
          Paint()
            ..color = _labelFill
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );

      textPainter.paint(
        canvas,
        Offset(
          -textPainter.width / 2,
          -textPainter.height / 2,
        ),
      );
      canvas.restore();
    }
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(2)} m';
  }

  Offset _labelCenterForEdge({
    required EdgeMeasurement edge,
    required Size labelSize,
  }) {
    final normal = Offset(
      -math.sin(edge.screenAngle),
      math.cos(edge.screenAngle),
    );
    final inwardDirection = edge.edgeCenter;
    final normalPointsInward = inwardDirection != Offset.zero &&
        (normal.dx * inwardDirection.dx + normal.dy * inwardDirection.dy) > 0;
    final pointsOutside = normalPointsInward ? -normal : normal;
    final clearance =
        _midpointHandleRadius + (labelSize.height / 2) + _labelCircleGap;
    return edge.screenMidpoint + pointsOutside * clearance;
  }

  @override
  bool shouldRepaint(covariant _LandDistanceLabelPainter oldDelegate) {
    return oldDelegate.edges != edges;
  }
}

class _LandDragOverlayPainter extends CustomPainter {
  const _LandDragOverlayPainter({
    required this.points,
    required this.midpoints,
    required this.activeIndex,
  });

  final List<Offset> points;
  final List<Offset> midpoints;
  final int? activeIndex;

  static const Color _polygonGreen = Color(0xFF00FF2A);
  static const Color _handleFill = Color(0xE6F2F4F0);
  static const Color _handleBorder = Color(0xB8D4DAD2);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (points.length >= 3) path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = _polygonGreen
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }

    final handleFillPaint = Paint()
      ..color = _handleFill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final handleBorderPaint = Paint()
      ..color = _handleBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..isAntiAlias = true;

    for (int i = 0; i < points.length; i++) {
      if (i == activeIndex) continue;
      final point = points[i];
      canvas
        ..drawCircle(point, 9.5, handleFillPaint)
        ..drawCircle(point, 9.5, handleBorderPaint);
    }

    handleBorderPaint.strokeWidth = 1.5;
    for (final midpoint in midpoints) {
      canvas
        ..drawCircle(midpoint, 6.5, handleFillPaint)
        ..drawCircle(midpoint, 6.5, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LandDragOverlayPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.midpoints != midpoints ||
        oldDelegate.activeIndex != activeIndex;
  }
}
