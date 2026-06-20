import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:greenated/view_models/tools/land_measurement_view_model.dart';

void main() {
  group('LandMeasurementViewModel', () {
    test('calculates polygon area in acres', () {
      final vm = LandMeasurementViewModel();

      vm
        ..addPoint(const LatLng(0, 0))
        ..addPoint(const LatLng(0, 0.001))
        ..addPoint(const LatLng(0.001, 0.001))
        ..addPoint(const LatLng(0.001, 0));

      expect(vm.areaInAcres, closeTo(3.0553, 0.0001));
      expect(vm.getResult()['area'], closeTo(3.0553, 0.0001));
    });

    test('returns zero acres until at least 3 points are marked', () {
      final vm = LandMeasurementViewModel();

      vm
        ..addPoint(const LatLng(0, 0))
        ..addPoint(const LatLng(0, 0.001));

      expect(vm.areaInAcres, 0);
      expect(vm.getResult()['area'], 0);
    });
  });
}
