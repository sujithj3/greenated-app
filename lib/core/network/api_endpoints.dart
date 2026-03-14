/// Single source of truth for every API endpoint path.
///
/// Organising endpoints as static constants keeps route strings out of
/// repository / service code and makes refactoring painless.
///
/// Paths are relative — the HTTP client prepends [ApiConfig.versionedBaseUrl].
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String requestOtp = '/auth/request-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh-token';

  // ── Categories ───────────────────────────────────────────────────────────
  static const String categories = '/categories';
  static String subcategories(int categoryId) =>
      '/categories/$categoryId/subcategories';

  // ── Registration ─────────────────────────────────────────────────────────
  static String registrationFields(int subcategoryId) =>
      '/subcategories/$subcategoryId/registration-fields';

  // ── Farmers ──────────────────────────────────────────────────────────────
  static const String farmers = '/farmers';
  static String farmerById(String id) => '/farmers/$id';
}
