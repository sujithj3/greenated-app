import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';

class AuthService extends ChangeNotifier {
  late final FirebaseAuth _auth =
      EnvConfig.isDemoMode ? _DummyAuth() : FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  bool _isLoading = false;
  String? _error;

  // Demo mode state
  bool _demoLoggedIn = false;
  static const String _demoPhone = '+91 98765 43210';

  User? get currentUser =>
      EnvConfig.isDemoMode ? null : _auth.currentUser;

  String get displayPhone =>
      EnvConfig.isDemoMode ? _demoPhone : (_auth.currentUser?.phoneNumber ?? '');

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

  // ─── Demo Mode ────────────────────────────────────────────────────────────

  Future<void> _demoVerify({required VoidCallback onCodeSent}) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));
    _setLoading(false);
    onCodeSent();
  }

  Future<bool> _demoSignIn() async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 600));
    _demoLoggedIn = true;
    _setLoading(false);
    notifyListeners();
    return true;
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
          await _auth.signInWithCredential(credential);
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

  /// Step 2 – verify OTP
  Future<bool> signInWithOTP(String otp) async {
    if (EnvConfig.isDemoMode) return _demoSignIn();

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
      await _auth.signInWithCredential(credential);
      _setLoading(false);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      String msg = 'Invalid OTP. Please try again.';
      if (e.code == 'session-expired') {
        msg = 'OTP session expired. Please resend.';
      }
      _setError(msg);
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    if (EnvConfig.isDemoMode) {
      _demoLoggedIn = false;
      notifyListeners();
      return;
    }
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
    notifyListeners();
  }
}

// Stub so FirebaseAuth.instance is never called in demo mode at class init.
class _DummyAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
