import 'package:flutter/foundation.dart';
import '../../core/network/network.dart';
import '../../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;
  final ApiClient _apiClient;

  LoginViewModel(this._authService, {ApiClient? apiClient})
      : _apiClient =
            apiClient ?? HttpClientImpl(interceptors: [LoggingInterceptor()]);

  bool _isLoading = false;
  String? _error;
  bool _codeSent = false;
  String _selectedCountryCode = '+91';
  String _lastPhoneNumber = '';
  String? _verificationId;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get codeSent => _codeSent;
  String get selectedCountryCode => _selectedCountryCode;
  String get lastPhoneNumber => _lastPhoneNumber;

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
    // final fullPhone = '$_selectedCountryCode$phone';
    final fullPhone = phone;
    _lastPhoneNumber = phone;
    bool success = false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requestBody = {'phoneNumber': fullPhone};

      final response = await _apiClient.send<Map<String, dynamic>>(
        ApiRequest(
          method: ApiMethod.post,
          path: ApiEndpoints.requestOtp,
          body: requestBody,
        ),
        decoder: (raw) => raw is Map<String, dynamic> ? raw : null,
      );

      if (response.isSuccess) {
        _codeSent = true;
        success = true;
        
        if (response.data != null && response.data!['verificationId'] != null) {
          _verificationId = response.data!['verificationId'] as String;
        }
      } else {
        _error = response.message;
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      // Bypassing Firebase auth for this test as per user request
      _isLoading = false;
      notifyListeners();
    }

    return success;
  }

  /// Resend OTP using the previously stored phone number.
  Future<bool> resendOTP() async {
    if (_lastPhoneNumber.isEmpty) return false;
    return sendOTP(_lastPhoneNumber);
  }

  Future<bool> verifyOTP(String otp) async {
    _isLoading = true;
    _error = null;
    bool success = false;
    notifyListeners();

    try {
      final requestBody = {
        'phoneNumber': _lastPhoneNumber,
        'otp': otp,
        if (_verificationId != null) 'verificationId': _verificationId,
      };

      final response = await _apiClient.send<Map<String, dynamic>>(
        ApiRequest(
          method: ApiMethod.post,
          path: ApiEndpoints.verifyOtp,
          body: requestBody,
        ),
        decoder: (raw) => raw is Map<String, dynamic> ? raw : null,
      );

      if (response.isSuccess) {
        success = true;
        if (response.data != null) {
          await _authService.signInWithApiTokens(response.data!);
        }
      } else {
        _error = response.message;
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return success;
  }
}
