import 'package:flutter/foundation.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/registration_form_service.dart';

/// ViewModel for the Edit Farmer Details flow.
///
/// Maintains independent state from the create and detail view models.
/// Fetches prefilled form data via the `form-edit` GET endpoint and
/// exposes it for rendering in [EditFarmerDetailsView].
class EditFarmerDetailsViewModel extends ChangeNotifier {
  EditFarmerDetailsViewModel({
    required RegistrationFormService service,
    required AuthService authService,
  })  : _service = service,
        _authService = authService;

  final RegistrationFormService _service;
  final AuthService _authService;

  // ── State ────────────────────────────────────────────────────────────────
  bool isLoading = false;
  String? error;
  String formName = '';
  List<DynamicFieldModel> fields = [];

  /// Fetches the edit form data for a given submission.
  ///
  /// Calls the GET `form-edit` endpoint with [subcategoryId], [submissionId],
  /// and the authenticated user's ID.
  Future<void> loadEditForm({
    required int subcategoryId,
    required int submissionId,
  }) async {
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
          await _service.fetchFormEdit(subcategoryId, submissionId, userId);
      formName = result.formName;
      fields = result.fields;
    } catch (e) {
      error = e.toString();
      fields = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Updates a dynamic field value by key.
  ///
  /// Used when the user edits a field in the form.
  void updateFieldValue(String key, dynamic value) {
    final idx = fields.indexWhere((df) => df.field.key == key);
    if (idx != -1) {
      fields[idx].value = value;
      notifyListeners();
    }
  }
}
