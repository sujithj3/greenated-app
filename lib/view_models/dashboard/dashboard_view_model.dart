import 'package:flutter/foundation.dart';
import '../../models/category/category_models.dart';
import '../../services/auth_service.dart';
import '../../services/form_config_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final AuthService _authService;
  final FormConfigService _formConfigService;

  DashboardViewModel(this._authService, this._formConfigService) {
    _authService.addListener(_onServiceChanged);
    _formConfigService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() => notifyListeners();

  String get displayPhone =>
      _authService.displayPhone.isNotEmpty ? _authService.displayPhone : 'User';

  bool get isCategoriesLoading => _formConfigService.isLoading;
  List<CategoryModel> get categories => _formConfigService.categories;
  String? get categoriesError => _formConfigService.error;

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    await _formConfigService.fetchCategories(forceRefresh: forceRefresh);
  }

  Future<void> logout() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _authService.removeListener(_onServiceChanged);
    _formConfigService.removeListener(_onServiceChanged);
    super.dispose();
  }
}
