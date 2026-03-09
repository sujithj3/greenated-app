import '../../config/env_config.dart';

/// Centralised configuration for the HTTP client.
///
/// Reads base URL from [EnvConfig] and provides sensible defaults
/// for timeouts and common headers. All values are accessible as
/// static getters so they stay in sync with the `.env` file.
class ApiConfig {
  ApiConfig._();

  // ── Base URL ────────────────────────────────────────────────────────────
  static String get baseUrl => EnvConfig.apiBaseUrl;

  // ── Timeouts ────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── API versioning ──────────────────────────────────────────────────────
  static const String apiVersion = 'v1';
  static String get versionedBaseUrl => '$baseUrl/api/$apiVersion';

  // ── Default headers applied to every request ────────────────────────────
  static Map<String, String> get defaultHeaders => <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
