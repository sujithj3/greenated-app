// SETUP REQUIRED FOR GOOGLE MAPS:
// Android — add inside <application> in android/app/src/main/AndroidManifest.xml:
//   <meta-data android:name="com.google.android.geo.API_KEY"
//              android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
//
// iOS — add to ios/Runner/AppDelegate.swift:
//   import GoogleMaps
//   GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/tools/land_measurement_view_model.dart';

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
    super.dispose();
  }

  // ─── Location ────────────────────────────────────────────────────────────

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
      if (mounted) context.showSnack('Location services are disabled.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) context.showSnack('Location permission denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) context.showSnack('Location permission permanently denied.');
      return false;
    }

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
                    child: GoogleMap(
                      onMapCreated: (ctrl) {
                        _mapController = ctrl;
                        // Initialize VM camera state
                        final initialPos = points.isNotEmpty
                            ? CameraPosition(target: points.first, zoom: 18)
                            : _defaultCamera;
                        _vm.updateCamera(initialPos);
                      },
                      initialCameraPosition: points.isNotEmpty
                          ? CameraPosition(target: points.first, zoom: 18)
                          : _defaultCamera,
                      mapType: _mapType,
                      myLocationEnabled: true,
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
                  );
                },
              ),

              // ── Top Info Panel ────────────────────────────────────────
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildInfoPanel(points),
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
