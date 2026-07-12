import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app version together with the date that version first ran on this
/// device — i.e. when the app was installed or last updated.
class AppVersionInfo {
  final String version;
  final DateTime updatedAt;

  const AppVersionInfo({required this.version, required this.updatedAt});
}

/// Tracks when the installed app version last changed.
///
/// [load] compares the current [PackageInfo.version] against the version
/// persisted in [SharedPreferences]. When they differ (or nothing is stored
/// yet, e.g. a fresh install), today's date is recorded as the update date.
/// Rebuilding the same version therefore never moves the date — only an
/// actual version bump does.
///
/// [load] is idempotent and safe to call from anywhere; it is invoked once at
/// startup in `main()` so the update date is captured on the first launch of
/// a new version, not on the first visit to the About screen.
class VersionInfoService {
  static const String _versionKey = 'app_installed_version';
  static const String _updatedAtKey = 'app_version_updated_at';

  /// The known release date of the initial 1.0 release. Seeding it here makes
  /// existing installs show the true release date rather than the day this
  /// tracking code first ran on the device. Versions after 1.0 take the
  /// normal path below and get stamped with the date they first launch.
  static final DateTime _initialReleaseDate = DateTime(2026, 7, 11);
  static const Set<String> _initialVersions = {'1.0', '1.0.0'};

  static Future<AppVersionInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();

    if (_initialVersions.contains(info.version)) {
      await prefs.setString(_versionKey, info.version);
      await prefs.setString(
          _updatedAtKey, _initialReleaseDate.toIso8601String());
      return AppVersionInfo(
          version: info.version, updatedAt: _initialReleaseDate);
    }

    final storedVersion = prefs.getString(_versionKey);
    final storedUpdatedAt =
        DateTime.tryParse(prefs.getString(_updatedAtKey) ?? '');

    if (storedVersion == info.version && storedUpdatedAt != null) {
      return AppVersionInfo(version: info.version, updatedAt: storedUpdatedAt);
    }

    final now = DateTime.now();
    await prefs.setString(_versionKey, info.version);
    await prefs.setString(_updatedAtKey, now.toIso8601String());
    return AppVersionInfo(version: info.version, updatedAt: now);
  }
}
