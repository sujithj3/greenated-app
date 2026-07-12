import 'package:flutter/foundation.dart';
import '../../models/category/category_models.dart';
import '../../services/auth_service.dart';
import '../../services/form_config_service.dart';
import '../registered_list_view_model.dart';

class DashboardViewModel extends ChangeNotifier {
  final AuthService _authService;
  final FormConfigService _formConfigService;
  final RegisteredListViewModel _registeredListViewModel;

  DashboardViewModel(
    this._authService,
    this._formConfigService,
    this._registeredListViewModel,
  ) {
    _authService.addListener(_onServiceChanged);
    _formConfigService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() => notifyListeners();

  String get displayPhone =>
      _authService.displayPhone.isNotEmpty ? _authService.displayPhone : 'User';

  String get displayName => _authService.fullName?.isNotEmpty ?? false
      ? _authService.fullName!
      : 'User';

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

  /// Signs the user out and clears every cache holding user-scoped data
  /// (categories and registered-farmer lists), so nothing from this session
  /// leaks into the next user's session.
  Future<void> logout() async {
    _formConfigService.clear();
    _registeredListViewModel.clear();
    await _authService.signOut();
  }

  @override
  void dispose() {
    _authService.removeListener(_onServiceChanged);
    _formConfigService.removeListener(_onServiceChanged);
    super.dispose();
  }
}
