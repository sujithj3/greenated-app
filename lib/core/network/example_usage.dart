// ignore_for_file: unused_local_variable
/// ════════════════════════════════════════════════════════════════════════════
/// EXAMPLE: How to use the networking layer
///
/// This file is NOT shipped in the app — it serves as living documentation
/// for developers integrating new API calls.
/// ════════════════════════════════════════════════════════════════════════════
library;

import '../network/network.dart';
import '../../repositories/category_repository.dart';
import '../../services/category_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. REPOSITORY PATTERN (recommended)
//
//    Repositories own the ApiClient and expose domain-specific methods.
//    Services / ViewModels never touch ApiClient directly.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// 2. ERROR HANDLING PATTERN
//
//    Catch [ApiException] and switch on subtype for fine-grained UX.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> exampleErrorHandling(CategoryRepository repo) async {
  try {
    final categories = await repo.fetchCategories();
    // ...use categories...
  } on UnauthorizedException {
    // Navigate to login screen
  } on NetworkException {
    // Show offline banner
  } on ServerException {
    // Show "try again later" dialog
  } on ValidationException catch (e) {
    // Highlight invalid form fields
    final fieldErrors = e.errors; // Map<String, List<String>>
  } on ApiException catch (e) {
    // Generic API error fallback
    final message = e.message;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. POST REQUEST WITH BODY
// ─────────────────────────────────────────────────────────────────────────────

Future<void> examplePostRequest(ApiClient client) async {
  final response = await client.send<Map<String, dynamic>>(
    const ApiRequest(
      method: ApiMethod.post,
      path: ApiEndpoints.requestOtp,
      body: {'phoneNumber': '+919876543210'},
    ),
    decoder: (raw) => raw is Map<String, dynamic> ? raw : null,
  );

  if (response.isSuccess) {
    // OTP sent
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. WIRING IT UP (in main.dart or a DI module)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows how to create the client and inject it into repositories.
void exampleWiring() {
  // Create the client (picks Mock or Real based on EnvConfig.isDemoMode)
  final ApiClient client = ApiClientFactory.create(
    tokenProvider: () => null, // Replace with real token provider later
  );

  // Inject into repositories
  final CategoryRepository categoryRepo = CategoryRepositoryImpl(
    apiService: CategoryApiService(apiClient: client),
  );

  // Repositories are then provided to services / view models via Provider.
}
