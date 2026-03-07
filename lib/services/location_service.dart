import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Result from reverse geocoding.
class AddressResult {
  final String address;
  final String village;
  final String district;
  final String state;

  const AddressResult({
    this.address = '',
    this.village = '',
    this.district = '',
    this.state = '',
  });
}

/// Handles geolocation and reverse geocoding.
class LocationService {
  /// Returns the device's current GPS position.
  /// Handles permission checks internally.
  Future<Position> getCurrentPosition() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw LocationException('Please enable location services.');
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw LocationException('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Reverse geocodes lat/lng into an address using Google Maps API.
  Future<AddressResult> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng&key=${EnvConfig.googleMapsApiKey}',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return const AddressResult();

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return const AddressResult();

    final comps =
        (data['results'] as List).first['address_components'] as List;
    String village = '', district = '', state = '';
    for (final c in comps) {
      final types = List<String>.from(c['types'] as List);
      final name = c['long_name'] as String;
      if (types.contains('sublocality') || types.contains('locality')) {
        village = name;
      }
      if (types.contains('administrative_area_level_2')) district = name;
      if (types.contains('administrative_area_level_1')) state = name;
    }

    final address =
        (data['results'] as List).first['formatted_address'] as String? ?? '';

    return AddressResult(
      address: address,
      village: village,
      district: district,
      state: state,
    );
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}
