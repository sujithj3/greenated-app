import 'package:flutter/foundation.dart';
import '../../models/category/category_models.dart';
import '../../services/form_config_service.dart';

class CategoryViewModel extends ChangeNotifier {
  final FormConfigService _formConfigService;

  CategoryViewModel(this._formConfigService) {
    _formConfigService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() => notifyListeners();

  bool get isLoading => _formConfigService.isLoading;
  List<CategoryModel> get categories => _formConfigService.categories;
  String? get error => _formConfigService.error;

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    await _formConfigService.fetchCategories(forceRefresh: forceRefresh);
  }

  @override
  void dispose() {
    _formConfigService.removeListener(_onServiceChanged);
    super.dispose();
  }
}
