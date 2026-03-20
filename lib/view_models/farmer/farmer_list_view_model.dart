import 'package:flutter/foundation.dart';
import '../../models/farmer/farmer_model.dart';

/// Placeholder ViewModel for farmer list.
/// Firestore stream logic removed. Will be wired to a real API when available.
class FarmerListViewModel extends ChangeNotifier {
  FarmerListViewModel();

  String _searchQuery = '';
  String? _filterStatus;

  // Set from navigation arguments
  String? navCategory;
  String? navSubcategory;
  bool viewOnly = false;

  String get searchQuery => _searchQuery;
  String? get filterStatus => _filterStatus;

  void init(Map? args) {
    navCategory = args?['category'] as String?;
    navSubcategory = args?['subcategory'] as String?;
    viewOnly = args?['viewOnly'] as bool? ?? false;
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _filterStatus = status;
    notifyListeners();
  }

  String get title => navSubcategory ?? navCategory ?? 'All Farmers';
  bool get hasNavFilter => navCategory != null;

  List<FarmerModel> applyFilters(List<FarmerModel> farmers) {
    if (_filterStatus != null) {
      return farmers.where((f) => f.status == _filterStatus).toList();
    }
    return farmers;
  }
}
