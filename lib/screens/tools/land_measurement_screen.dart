// SETUP REQUIRED FOR GOOGLE MAPS:
// Android — add inside <application> in android/app/src/main/AndroidManifest.xml:
//   <meta-data android:name="com.google.android.geo.API_KEY"
//              android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
//
// iOS — add to ios/Runner/AppDelegate.swift:
//   import GoogleMaps
//   GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_colors.dart';

class LandMeasurementScreen extends StatefulWidget {
  const LandMeasurementScreen({super.key});

  @override
  State<LandMeasurementScreen> createState() => _LandMeasurementScreenState();
}

class _LandMeasurementScreenState extends State<LandMeasurementScreen> {
  GoogleMapController? _mapController;

  final List<LatLng> _points = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Polygon> _polygons = {};

  double _areaInAcres = 0;
  bool _locating = false;
  MapType _mapType = MapType.hybrid;

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629), // India center
    zoom: 5,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Location ──────────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 18,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Could not get location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ─── Map Interactions ──────────────────────────────────────────────────

  void _onTap(LatLng position) {
    setState(() {
      _points.add(position);
      _rebuild();
    });
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;
    setState(() {
      _points.removeLast();
      _rebuild();
    });
  }

  void _clearAll() {
    setState(() {
      _points.clear();
      _markers = {};
      _polylines = {};
      _polygons = {};
      _areaInAcres = 0;
    });
  }

  void _rebuild() {
    _buildMarkers();
    _buildPolylines();
    if (_points.length >= 3) {
      _buildPolygon();
      _areaInAcres = _calculateArea(_points);
    } else {
      _polygons = {};
      _areaInAcres = 0;
    }
  }

  void _buildMarkers() {
    _markers = _points.asMap().entries.map((e) {
      final idx = e.key;
      final pos = e.value;
      return Marker(
        markerId: MarkerId('pt_$idx'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          idx == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(title: 'Point ${idx + 1}'),
      );
    }).toSet();
  }

  void _buildPolylines() {
    if (_points.length < 2) {
      _polylines = {};
      return;
    }
    final List<LatLng> path = [..._points];
    if (_points.length >= 3) path.add(_points.first); // close the loop

    _polylines = {
      Polyline(
        polylineId: const PolylineId('boundary'),
        points: path,
        color: AppColors.accent,
        width: 3,
      ),
    };
  }

  void _buildPolygon() {
    _polygons = {
      Polygon(
        polygonId: const PolygonId('land'),
        points: _points,
        fillColor: AppColors.primary.withOpacity(0.25),
        strokeColor: AppColors.primary,
        strokeWidth: 2,
      ),
    };
  }

  /// Spherical excess formula – returns area in acres.
  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    const double earthRadius = 6371008.8; // metres
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
    return areaM2 * 0.000247105; // convert to acres
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _done() {
    if (_points.length < 3) {
      _showSnack('Mark at least 3 points to define a land boundary.');
      return;
    }
    Navigator.pop(context, {
      'area': _areaInAcres,
      'coordinates':
          _points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Land Measurement'),
        actions: [
          if (_points.length >= 3)
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
          // ── Google Map ─────────────────────────────────────────────
          GoogleMap(
            onMapCreated: (ctrl) => _mapController = ctrl,
            initialCameraPosition: _defaultCamera,
            mapType: _mapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: _onTap,
            markers: _markers,
            polylines: _polylines,
            polygons: _polygons,
            zoomControlsEnabled: false,
          ),

          // ── Top Info Panel ─────────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            _points.isEmpty
                                ? 'Tap on the map to mark land boundary points'
                                : _points.length < 3
                                    ? 'Add ${3 - _points.length} more point(s) to form polygon'
                                    : 'Area: ${_areaInAcres.toStringAsFixed(4)} Acres',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.dark,
                            ),
                          ),
                          if (_points.isNotEmpty)
                            Text(
                              '${_points.length} point(s) marked',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Controls ────────────────────────────────────────
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map type toggle
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

                // My location
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: _locating ? null : _goToMyLocation,
                  backgroundColor: Colors.white,
                  child: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, color: AppColors.primary),
                ),
                const SizedBox(height: 8),

                // Undo
                FloatingActionButton.small(
                  heroTag: 'undo',
                  onPressed: _points.isEmpty ? null : _undoLastPoint,
                  backgroundColor:
                      _points.isEmpty ? Colors.grey.shade300 : Colors.white,
                  child: Icon(Icons.undo,
                      color: _points.isEmpty ? Colors.grey : AppColors.warning),
                ),
                const SizedBox(height: 8),

                // Clear all
                FloatingActionButton.small(
                  heroTag: 'clear',
                  onPressed: _points.isEmpty ? null : _clearAll,
                  backgroundColor:
                      _points.isEmpty ? Colors.grey.shade300 : Colors.white,
                  child: Icon(Icons.delete_outline,
                      color: _points.isEmpty ? Colors.grey : AppColors.error),
                ),
              ],
            ),
          ),

          // ── Done FAB (bottom-left) ─────────────────────────────────
          if (_points.length >= 3)
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton.extended(
                heroTag: 'done',
                onPressed: _done,
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text(
                  '${_areaInAcres.toStringAsFixed(3)} Ac',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
