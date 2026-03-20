import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  SharedPreferences? _prefs;

  static const String _userIdKey = 'app_user_id';
  static const String _nameKey = 'app_user_name';
  static const String _mobileNumberKey = 'app_user_phone';
  static const String _createdAtKey = 'app_user_created_at';
  static const String _lastLoginAtKey = 'app_user_last_login_at';
  static const String _tokenKey = 'app_auth_token';
  static const String _refreshTokenKey = 'app_refresh_token';

  int? get userId {
    if (_prefs == null) return null;
    final value = _prefs!.get(_userIdKey);
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String? get fullName => _prefs?.getString(_nameKey);

  String get displayPhone => _prefs?.getString(_mobileNumberKey) ?? '';

  String? get createdAt => _prefs?.getString(_createdAtKey);

  String? get lastLoginAt => _prefs?.getString(_lastLoginAtKey);

  String? get accessToken => _prefs?.getString(_tokenKey);

  bool get isLoggedIn => userId != null;

  /// Initialize SharedPreferences. Should be called early in the app lifecycle.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── API Token SignIn ─────────────────────────────────────────────────────

  /// Ingests user data from the real backend verify-otp endpoint and stores it.
  ///
  /// Accepts the `data` map from the API response which contains:
  /// - userId (int)
  /// - name (String)
  /// - mobileNumber (String)
  /// - createdAt (String, ISO 8601)
  /// - lastLoginAt (String, ISO 8601)
  /// - token (String, optional)
  /// - refreshToken (String, optional)
  Future<void> signInWithApiTokens(Map<String, dynamic> data) async {
    if (_prefs == null) await init();

    // Extract and store auth tokens if present
    final String? token = data['token'] as String?;
    final String? refreshToken = data['refreshToken'] as String?;
    if (token != null) await _prefs!.setString(_tokenKey, token);
    if (refreshToken != null) {
      await _prefs!.setString(_refreshTokenKey, refreshToken);
    }

    // Extract user data — the data map may contain user fields directly,
    // or nested under a 'user' key for backward compatibility.
    final Map<String, dynamic> userData = data.containsKey('user')
        ? (data['user'] as Map<String, dynamic>? ?? data)
        : data;

    final int? userId = userData['userId'] is int
        ? userData['userId'] as int
        : int.tryParse(userData['userId']?.toString() ?? '');
    final String? name = userData['name'] as String?;
    final String? mobileNumber = userData['mobileNumber'] as String?;
    final String? createdAt = userData['createdAt'] as String?;
    final String? lastLoginAt = userData['lastLoginAt'] as String?;

    debugPrint('[AuthService] Parsing API response: '
        'userId=$userId, name=$name, mobileNumber=$mobileNumber');

    await _saveUserData(
      userId: userId,
      name: name,
      mobileNumber: mobileNumber,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );

    notifyListeners();
  }

  /// Persists user data to SharedPreferences.
  Future<void> _saveUserData({
    int? userId,
    String? name,
    String? mobileNumber,
    String? createdAt,
    String? lastLoginAt,
  }) async {
    if (_prefs == null) await init();

    if (userId != null) {
      await _prefs!.setInt(_userIdKey, userId);
    }
    if (name != null) {
      await _prefs!.setString(_nameKey, name);
    }
    if (mobileNumber != null) {
      await _prefs!.setString(_mobileNumberKey, mobileNumber);
    }
    if (createdAt != null) {
      await _prefs!.setString(_createdAtKey, createdAt);
    }
    if (lastLoginAt != null) {
      await _prefs!.setString(_lastLoginAtKey, lastLoginAt);
    }

    debugPrint('[AuthService] User data saved: '
        'ID=$userId, Name=$name, Phone=$mobileNumber');
  }

  Future<void> signOut() async {
    if (_prefs != null) {
      await _prefs!.remove(_userIdKey);
      await _prefs!.remove(_nameKey);
      await _prefs!.remove(_mobileNumberKey);
      await _prefs!.remove(_createdAtKey);
      await _prefs!.remove(_lastLoginAtKey);
      await _prefs!.remove(_tokenKey);
      await _prefs!.remove(_refreshTokenKey);
    }

    notifyListeners();
  }
}
