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
        context.showSnack('Timed out while fetching location. Please try again.');
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

  void _onTap(LatLng position) => _vm.addPoint(position);

  void _done() {
    if (!_vm.canComplete) {
      context.showSnack('Mark at least 3 points to define a land boundary.');
      return;
    }
    Navigator.pop(context, _vm.getResult());
  }

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
              GoogleMap(
                onMapCreated: (ctrl) => _mapController = ctrl,
                initialCameraPosition: points.isNotEmpty
                    ? CameraPosition(target: points.first, zoom: 18)
                    : _defaultCamera,
                mapType: _mapType,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                onTap: _viewOnly ? null : _onTap,
                markers: _vm.buildMarkers(),
                polylines: _vm.buildPolylines(),
                polygons: _vm.buildPolygon(),
                zoomControlsEnabled: false,
              ),

              // ── Top Info Panel ────────────────────────────────────────
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _viewOnly
                                    ? (points.isEmpty
                                        ? 'No boundary points recorded'
                                        : points.length < 3
                                            ? '${points.length} point(s) recorded'
                                            : 'Area: ${_vm.areaInAcres.toStringAsFixed(4)} Acres')
                                    : (points.isEmpty
                                        ? 'Tap on the map to mark land boundary points'
                                        : points.length < 3
                                            ? 'Add ${3 - points.length} more point(s) to form polygon'
                                            : 'Area: ${_vm.areaInAcres.toStringAsFixed(4)} Acres'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dark,
                                ),
                              ),
                              if (points.isNotEmpty)
                                Text(
                                  '${points.length} point(s) marked',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMedium),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom Controls ───────────────────────────────────────
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'maptype',
                      onPressed: () => setState(() {
                        _mapType = _mapType == MapType.hybrid
                            ? MapType.normal
                            : MapType.hybrid;
                      }),
                      backgroundColor: Colors.white,
                      child: Icon(
                        _mapType == MapType.hybrid
                            ? Icons.map
                            : Icons.satellite_alt,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          : const Icon(Icons.my_location,
                              color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    if (!_viewOnly) ...[
                      FloatingActionButton.small(
                        heroTag: 'undo',
                        onPressed:
                            points.isEmpty ? null : _vm.undoLastPoint,
                        backgroundColor: points.isEmpty
                            ? Colors.grey.shade300
                            : Colors.white,
                        child: Icon(Icons.undo,
                            color: points.isEmpty
                                ? Colors.grey
                                : AppColors.warning),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'clear',
                        onPressed: points.isEmpty
                            ? null
                            : () {
                                _vm.clearAll();
                                final args = ModalRoute.of(context)
                                    ?.settings.arguments as Map?;
                                if (args != null && args['onClear'] != null) {
                                  args['onClear']();
                                }
                              },
                        backgroundColor: points.isEmpty
                            ? Colors.grey.shade300
                            : Colors.white,
                        child: Icon(Icons.delete_outline,
                            color: points.isEmpty
                                ? Colors.grey
                                : AppColors.error),
                      ),
                    ],
                  ],
                ),
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
}
