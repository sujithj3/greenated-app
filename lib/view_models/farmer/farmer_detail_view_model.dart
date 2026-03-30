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

  Future<void> loadFormDetail(
      {required int subcategoryId, required int submissionId}) async {
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
          await _service.fetchFormDetail(subcategoryId, submissionId, userId);
      formName = result.formName;
      fields = result.fields;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
