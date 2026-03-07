import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;

  LoginViewModel(this._authService);

  bool _isLoading = false;
  String? _error;
  bool _codeSent = false;
  String _selectedCountryCode = '+91';

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get codeSent => _codeSent;
  String get selectedCountryCode => _selectedCountryCode;

  final List<String> countryCodes = const ['+91', '+1', '+44', '+61', '+971'];

  void setCountryCode(String code) {
    _selectedCountryCode = code;
    notifyListeners();
  }

  void goBackToPhone() {
    _codeSent = false;
    notifyListeners();
  }

  Future<bool> sendOTP(String phone) async {
    final fullPhone = '$_selectedCountryCode$phone';
    bool success = false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    await _authService.verifyPhoneNumber(
      phoneNumber: fullPhone,
      onCodeSent: () {
        _codeSent = true;
        success = true;
      },
      onError: (msg) {
        _error = msg;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> verifyOTP(String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final success = await _authService.signInWithOTP(otp);
    if (!success) {
      _error = _authService.error ?? 'Invalid OTP. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }
}
