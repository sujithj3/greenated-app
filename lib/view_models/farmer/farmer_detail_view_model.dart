import 'package:flutter/foundation.dart';
import '../../models/farmer/farmer_model.dart';

/// Placeholder ViewModel for farmer detail.
/// Firestore data loading removed. Will be wired to a real API when available.
class FarmerDetailViewModel extends ChangeNotifier {
  FarmerDetailViewModel();

  FarmerModel? get farmer => null;
  bool get isLoading => false;

  // No-op until a real farmers API is integrated.
  Future<void> loadFarmer(String id) async {}
  Future<void> deleteFarmer() async {}
  Future<void> toggleStatus() async {}
}
