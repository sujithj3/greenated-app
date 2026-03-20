import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/env_config.dart';

class AuthService extends ChangeNotifier {
  late final FirebaseAuth _auth =
      EnvConfig.isDemoMode ? _DummyAuth() : FirebaseAuth.instance;
  SharedPreferences? _prefs;

  static const String _userIdKey = 'app_user_id';
  static const String _fullNameKey = 'app_user_name';
  static const String _phoneKey = 'app_user_phone';
  static const String _tokenKey = 'app_auth_token';
  static const String _refreshTokenKey = 'app_refresh_token';

  String? _verificationId;
  int? _resendToken;
  bool _isLoading = false;
  String? _error;

  // Demo mode state
  bool _demoLoggedIn = false;
  String _demoPhone = '';

  User? get currentUser => EnvConfig.isDemoMode ? null : _auth.currentUser;

  /// Retrieves the stored user ID. Falls back to Firebase UID if present,
  /// otherwise uses the ID stored in SharedPreferences.
  /// Retrieves the stored user ID. Falls back to Firebase UID if present,
  /// otherwise uses the ID stored in SharedPreferences.
  String? get userId {
    if (!EnvConfig.isDemoMode && _auth.currentUser != null) {
      return _auth.currentUser!.uid;
    }
    return _prefs?.getString(_userIdKey);
  }

  String? get fullName => _prefs?.getString(_fullNameKey);

  String get displayPhone {
    if (EnvConfig.isDemoMode) {
      return _prefs?.getString(_phoneKey) ?? _demoPhone;
    }
    return _auth.currentUser?.phoneNumber ?? _prefs?.getString(_phoneKey) ?? '';
  }

  bool get isLoggedIn =>
      EnvConfig.isDemoMode ? _demoLoggedIn : _auth.currentUser != null;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<User?> get authStateChanges =>
      EnvConfig.isDemoMode ? const Stream.empty() : _auth.authStateChanges();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Initialize SharedPreferences. Should be called early in the app lifecycle.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _saveUserId({String? id, String? name, String? phone}) async {
    if (_prefs == null) await init();
    
    // Save or generate User ID
    if (id != null) {
      await _prefs!.setString(_userIdKey, id);
    } else if (userId == null) {
      final String newId = const Uuid().v4();
      await _prefs!.setString(_userIdKey, newId);
    }
    
    // Save additional user details
    if (name != null) {
      await _prefs!.setString(_fullNameKey, name);
    }
    if (phone != null) {
      await _prefs!.setString(_phoneKey, phone);
    }
    
    debugPrint('🔑 [AuthService] User Details Saved: ID=$userId, Name=$fullName, Phone=$displayPhone');
  }

  // ─── Demo Mode ────────────────────────────────────────────────────────────

  Future<void> _demoVerify({required VoidCallback onCodeSent}) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));
    _setLoading(false);
    onCodeSent();
  }

  // ─── API Token SignIn ─────────────────────────────────────────────────────

  /// Ingests token data from the real backend verify-otp endpoint and stores it.
  Future<void> signInWithApiTokens(Map<String, dynamic> data) async {
    final String? token = data['token'] as String?;
    final String? refreshToken = data['refreshToken'] as String?;
    final Map<String, dynamic>? user = data['user'] as Map<String, dynamic>?;

    if (_prefs == null) await init();

    if (token != null) await _prefs!.setString(_tokenKey, token);
    if (refreshToken != null) await _prefs!.setString(_refreshTokenKey, refreshToken);

    await _saveUserId(
      id: user?['userId'] as String?,
      name: user?['fullName'] as String?,
      phone: user?['phoneNumber'] as String?,
    );

    _demoLoggedIn = true; // Use this to tell app we are authenticated
    _logOtpVerificationResponse(success: true);
    notifyListeners();
  }

  // ─── Phone OTP ────────────────────────────────────────────────────────────

  /// Step 1 – send OTP
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required VoidCallback onCodeSent,
    required Function(String) onError,
    Function(PhoneAuthCredential)? onAutoVerified,
  }) async {
    if (EnvConfig.isDemoMode) {
      _demoPhone = phoneNumber;
      await _demoVerify(onCodeSent: onCodeSent);
      return;
    }

    _setLoading(true);
    _setError(null);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCredential = await _auth.signInWithCredential(credential);
          
          // Fallback parsing for phone/name from Firebase if needed
          await _saveUserId(
            id: userCredential.user?.uid,
            name: userCredential.user?.displayName,
            phone: userCredential.user?.phoneNumber ?? phoneNumber,
          );
          
          _logOtpVerificationResponse(success: true);
          notifyListeners();
          if (onAutoVerified != null) onAutoVerified(credential);
        } catch (e) {
          _setError(e.toString());
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        _setLoading(false);
        String msg = e.message ?? 'Verification failed.';
        if (e.code == 'invalid-phone-number') {
          msg = 'The phone number format is invalid.';
        } else if (e.code == 'too-many-requests') {
          msg = 'Too many attempts. Please try again later.';
        }
        _setError(msg);
        onError(msg);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        _setLoading(false);
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Step 2 – verify OTP fallback
  Future<bool> signInWithOTP(String otp) async {
    if (_verificationId == null) {
      _setError('Verification session expired. Please retry.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      
      await _saveUserId(
        id: userCredential.user?.uid,
        name: userCredential.user?.displayName,
        phone: userCredential.user?.phoneNumber,
      );
      
      _logOtpVerificationResponse(success: true);
      _setLoading(false);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      String msg = 'Invalid OTP. Please try again.';
      if (e.code == 'session-expired') {
        msg = 'OTP session expired. Please resend.';
      }
      _logOtpVerificationResponse(success: false);
      _setError(msg);
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    if (_prefs != null) {
      await _prefs!.remove(_userIdKey);
      await _prefs!.remove(_fullNameKey);
      await _prefs!.remove(_phoneKey);
      await _prefs!.remove(_tokenKey);
      await _prefs!.remove(_refreshTokenKey);
    }

    if (EnvConfig.isDemoMode) {
      _demoLoggedIn = false;
      _demoPhone = '';
      notifyListeners();
      return;
    }
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
    notifyListeners();
  }

  void _logOtpVerificationResponse({required bool success}) {
    final payload = <String, dynamic>{
      'userId': userId,
      'fullName': fullName,
      'phone': displayPhone,
      'timestamp': DateTime.now().toIso8601String(),
      'success': success,
    };

    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('=== OTP VERIFICATION RESPONSE ===');
    debugPrint(pretty);
    debugPrint('===============================');
  }
}

// Stub so FirebaseAuth.instance is never called in demo mode at class init.
class _DummyAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
