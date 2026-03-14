import 'package:flutter/foundation.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/firestore_service.dart';

class FarmerDetailViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;

  FarmerDetailViewModel(this._firestoreService);

  FarmerModel? _farmer;
  bool _isLoading = true;

  FarmerModel? get farmer => _farmer;
  bool get isLoading => _isLoading;

  Future<void> loadFarmer(String id) async {
    _isLoading = true;
    notifyListeners();

    _farmer = await _firestoreService.getFarmerById(id);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteFarmer() async {
    if (_farmer?.id == null) return;
    await _firestoreService.deleteFarmer(_farmer!.id!);
  }

  Future<void> toggleStatus() async {
    if (_farmer == null) return;
    final newStatus = _farmer!.status == 'Active' ? 'Inactive' : 'Active';
    final updated = _farmer!.copyWith(status: newStatus);
    await _firestoreService.updateFarmer(updated);
    _farmer = updated;
    notifyListeners();
  }
}
