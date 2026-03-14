import 'package:flutter/foundation.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/firestore_service.dart';

class FarmerListViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;

  FarmerListViewModel(this._firestoreService);

  String _searchQuery = '';
  String? _filterStatus;

  // Set from navigation arguments
  String? navCategory;
  String? navSubcategory;

  String get searchQuery => _searchQuery;
  String? get filterStatus => _filterStatus;

  void init(Map? args) {
    navCategory = args?['category'] as String?;
    navSubcategory = args?['subcategory'] as String?;
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

  Stream<List<FarmerModel>> get farmersStream {
    if (navCategory != null && navSubcategory != null) {
      return _firestoreService.getFarmersByCategoryAndSub(
          navCategory!, navSubcategory!);
    } else if (navCategory != null) {
      return _firestoreService.getFarmersByCategory(navCategory!);
    } else if (_searchQuery.isNotEmpty) {
      return _firestoreService.searchFarmers(_searchQuery);
    }
    return _firestoreService.getFarmers();
  }

  List<FarmerModel> applyFilters(List<FarmerModel> farmers) {
    if (_filterStatus != null) {
      return farmers.where((f) => f.status == _filterStatus).toList();
    }
    return farmers;
  }
}
