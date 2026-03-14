import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../utils/app_colors.dart';
import '../../view_models/auth/login_view_model.dart';

/// Phone number input view — part of the login flow.
///
/// Displays country code selector, phone number field, and Continue button.
/// Calls [onOtpSent] when OTP is successfully dispatched so the parent
/// can switch to the OTP verification step.
class LoginWithPhoneView extends StatefulWidget {
  const LoginWithPhoneView({
    super.key,
    required this.viewModel,
    required this.onOtpSent,
  });

  final LoginViewModel viewModel;
  final VoidCallback onOtpSent;

  @override
  State<LoginWithPhoneView> createState() => _LoginWithPhoneViewState();
}

class _LoginWithPhoneViewState extends State<LoginWithPhoneView> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  LoginViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phoneNumber = _phoneCtrl.text.trim();
    if (!_isValidPhoneNumber(phoneNumber)) {
      _showValidationToast();
      return;
    }
    FocusScope.of(context).unfocus();

    final success = await _vm.sendOTP(phoneNumber);
    if (success && mounted) {
      _showSnack('OTP sent to ${_vm.selectedCountryCode}$phoneNumber');
      widget.onOtpSent();
    } else if (_vm.error != null && mounted) {
      _showSnack(_vm.error!, isError: true);
    }
  }

  bool _isValidPhoneNumber(String value) => RegExp(r'^\d{10}$').hasMatch(value);

  void _showValidationToast() {
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: 'Enter a valid 10-digit phone number',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppColors.error,
      textColor: Colors.white,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.dark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.8, 1.3);

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('phone'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4 * scale),
          Text(
            'Login with Phone',
            style: TextStyle(
              fontSize: (20 * scale).clamp(16.0, 24.0),
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            'Enter your mobile number to receive a verification code.',
            style: TextStyle(
              color: AppColors.textMedium,
              fontSize: (12 * scale).clamp(11.0, 14.0),
            ),
          ),
          SizedBox(height: (28 * scale).clamp(20.0, 34.0)),

          // Phone row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country code picker
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.veryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.light),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _vm.selectedCountryCode,
                    isDense: true,
                    style: TextStyle(
                      fontSize: (14 * scale).clamp(12.0, 16.0),
                      color: AppColors.dark,
                    ),
                    items: _vm.countryCodes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => _vm.setCountryCode(v!),
                  ),
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  style: TextStyle(
                    fontSize: (15 * scale).clamp(13.0, 17.0),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'Enter mobile number',
                    hintStyle: TextStyle(
                      fontSize: (13 * scale).clamp(11.0, 15.0),
                      color: AppColors.textMedium.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.phone,
                      size: (20 * scale).clamp(18.0, 24.0),
                    ),
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: (28 * scale).clamp(20.0, 34.0)),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _vm.isLoading ? null : _sendOTP,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14 * scale),
              ),
              child: _vm.isLoading
                  ? SizedBox(
                      width: 22 * scale,
                      height: 22 * scale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: (15 * scale).clamp(13.0, 17.0),
                      ),
                    ),
            ),
          ),
          SizedBox(height: 6 * scale),
        ],
      ),
    );
  }
}
