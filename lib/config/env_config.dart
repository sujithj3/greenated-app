import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central, typed accessor for the app's environment configuration.
///
/// Wraps the raw key/value pairs loaded from `.env.<environment>` (via
/// `flutter_dotenv`) behind named getters so the rest of the app never reads
/// environment strings directly. Covers the build-time [appEnvironment] flag,
/// the backend [apiBaseUrl], third-party keys such as [googleMapsApiKey], and
/// feature switches like [isDemoMode].
///
/// Call `await dotenv.load(fileName: '.env.<environment>')` in `main()`
/// before using these getters. The private constructor prevents instantiation
/// — all members are static.
class EnvConfig {
  EnvConfig._();

  /// The active environment name, injected at build time via
  /// `--dart-define=APP_ENV=...` and defaulting to `development`.
  static const String appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Whether the app is running in the development environment.
  static bool get isDevelopment =>
      appEnvironment.toLowerCase() == 'development';

  /// Google Maps API key from the loaded `.env` file, or an empty string when
  /// unset.
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Base URL for all backend API calls, falling back to the pre-prod host
  /// when `API_BASE_URL` is not defined.
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ??
      'http://preprod-marketplace.hrgreenated.com';

  /// Whether demo mode is enabled (defaults to true when unset), used to serve
  /// sample/mock data instead of live backend calls.
  static bool get isDemoMode =>
      (dotenv.env['DEMO_MODE'] ?? 'true').toLowerCase() == 'true';
}
