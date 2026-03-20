import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables loaded from `.env`.
///
/// Call `await dotenv.load()` in `main()` before using these getters.
class EnvConfig {
  EnvConfig._();

  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://preprod-marketplace.hrgreenated.com';

  static bool get isDemoMode =>
      (dotenv.env['DEMO_MODE'] ?? 'true').toLowerCase() == 'true';
}
