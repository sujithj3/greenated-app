import 'package:flutter/foundation.dart';
import '../models/farmer_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  DashboardViewModel(this._authService, this._firestoreService);

  String get displayPhone => _authService.displayPhone;

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Stream<int> get totalCount => _firestoreService.getTotalCount();
  Stream<int> get activeCount => _firestoreService.getActiveCount();
  Stream<Map<String, int>> get categoryCounts =>
      _firestoreService.getCategoryCounts();
  Stream<List<FarmerModel>> get recentFarmers => _firestoreService.getFarmers();

  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
}
