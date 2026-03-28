/// Single source of truth for every API endpoint path.
///
/// Organising endpoints as static constants keeps route strings out of
/// repository / service code and makes refactoring painless.
///
/// Paths are relative — the HTTP client prepends [ApiConfig.versionedBaseUrl].
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String requestOtp = 'login/request-otp';
  static const String verifyOtp = 'login/verify-otp';
  static const String refreshToken = 'auth/refresh-token';

  // ── Categories ───────────────────────────────────────────────────────────
  static const String categories = 'categorylist';
  // static String subcategories(int categoryId) =>
  //     'categories/$categoryId/subcategories';

  // ── Registration ─────────────────────────────────────────────────────────
  static String registrationFields(int subcategoryId) =>
      'subcategories/$subcategoryId/form';

  static String registeredList(int subcategoryId) =>
      'subcategories/$subcategoryId/registration-list';

  static String formDetail(int subcategoryId) =>
      'subcategories/$subcategoryId/form-detail';

  // ── Image Upload ────────────────────────────────────────────────────
  static const String imageUpload = 'image/upload';

  // ── Farmers ──────────────────────────────────────────────────────────────
  static const String listFarmers = 'list-farmers';
  static const String registerFarmer = 'register-farmer';
  static String farmerById(String id) => 'farmer/$id';
}
