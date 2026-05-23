import 'package:flutter/foundation.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/registration_form_service.dart';

class FarmerDetailViewModel extends ChangeNotifier {
  FarmerDetailViewModel({
    required RegistrationFormService service,
    required AuthService authService,
  })  : _service = service,
        _authService = authService;

  final RegistrationFormService _service;
  final AuthService _authService;

  bool isLoading = false;
  String? error;
  String formName = '';
  List<DynamicFieldModel> fields = [];
  List<LandDetail> landDetails = [];

  Future<void> loadFormDetail(
      {required int subcategoryId, required int farmerId}) async {
    final userId = _authService.userId;
    if (userId == null) {
      error = 'User not authenticated.';
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result =
          await _service.fetchFormDetail(subcategoryId, farmerId, userId);
      formName = result.formName;
      fields = result.fields;
      landDetails = result.landDetails;
    } catch (e) {
      error = e.toString();
      fields = [];
      landDetails = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
