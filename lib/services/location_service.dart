import 'dart:async';
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
  static const Duration _positionTimeout = Duration(seconds: 20);
  static const Duration _reverseGeocodeTimeout = Duration(seconds: 15);

  /// Returns the device's current GPS position.
  /// Handles permission checks internally.
  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException(
        'Location services are disabled. Please enable them and try again.',
        type: LocationFailureType.servicesDisabled,
      );
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const LocationException(
        'Location permission denied.',
        type: LocationFailureType.permissionDenied,
      );
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it from app settings.',
        type: LocationFailureType.permissionDeniedForever,
      );
    }

    Future<Position?> tryLastKnownPosition() async {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _positionTimeout,
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        'Location services are disabled. Please enable them and try again.',
        type: LocationFailureType.servicesDisabled,
      );
    } on TimeoutException {
      final fallback = await tryLastKnownPosition();
      if (fallback != null) return fallback;
      throw const LocationException(
        'Timed out while fetching your current location. Please try again in an open area.',
        type: LocationFailureType.timeout,
      );
    } catch (e) {
      final fallback = await tryLastKnownPosition();
      if (fallback != null) return fallback;
      throw LocationException('Failed to fetch current location: $e');
    }
  }

  /// Reverse geocodes lat/lng into an address using Google Maps API.
  Future<AddressResult> reverseGeocode(double lat, double lng) async {
    final apiKey = EnvConfig.googleMapsApiKey.trim();
    if (apiKey.isEmpty) {
      throw const LocationException(
        'Google Maps API key is missing. Reverse geocoding is unavailable.',
      );
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng&key=$apiKey',
    );

    http.Response res;
    try {
      res = await http.get(uri).timeout(_reverseGeocodeTimeout);
    } on TimeoutException {
      throw const LocationException('Timed out while resolving your address.');
    } catch (e) {
      throw LocationException('Failed to resolve your address: $e');
    }

    if (res.statusCode != 200) {
      throw LocationException('Reverse geocoding failed (${res.statusCode}).');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != 'OK') {
      final message = data['error_message'] as String?;
      throw LocationException(
        message != null && message.isNotEmpty
            ? 'Could not resolve your address: $message'
            : 'Could not resolve your address from the current location.',
      );
    }

    final results = (data['results'] as List?) ?? const [];
    if (results.isEmpty) {
      throw const LocationException(
        'Could not resolve your address from the current location.',
      );
    }

    final firstResult = results.first as Map<String, dynamic>;
    final comps = (firstResult['address_components'] as List?) ?? const [];
    final village = _firstMatchingComponent(comps, const [
      'sublocality',
      'locality',
      'administrative_area_level_4',
      'administrative_area_level_3',
    ]);
    final district = _firstMatchingComponent(comps, const [
      'administrative_area_level_2',
      'administrative_area_level_3',
      'locality',
    ]);
    final state =
        _firstMatchingComponent(comps, const ['administrative_area_level_1']);
    final address = firstResult['formatted_address'] as String? ?? '';

    return AddressResult(
      address: address,
      village: village,
      district: district,
      state: state,
    );
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  String _firstMatchingComponent(
    List<dynamic> components,
    List<String> preferredTypes,
  ) {
    for (final type in preferredTypes) {
      for (final component in components) {
        final map = component as Map<String, dynamic>;
        final types = List<String>.from(map['types'] as List? ?? const []);
        if (types.contains(type)) {
          return map['long_name'] as String? ?? '';
        }
      }
    }
    return '';
  }
}

enum LocationFailureType {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationException implements Exception {
  final String message;
  final LocationFailureType type;

  const LocationException(
    this.message, {
    this.type = LocationFailureType.unknown,
  });

  bool get isServiceDisabled => type == LocationFailureType.servicesDisabled;
  bool get isPermissionDenied =>
      type == LocationFailureType.permissionDenied ||
      type == LocationFailureType.permissionDeniedForever;

  @override
  String toString() => message;
}
