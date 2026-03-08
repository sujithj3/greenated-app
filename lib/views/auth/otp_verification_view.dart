import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../utils/app_colors.dart';
import '../../view_models/auth/login_view_model.dart';

/// OTP verification view — part of the login flow.
///
/// Displays a 6-digit pin input, Verify button, Resend OTP option, and
/// a Change Number button. Calls [onVerified] after successful verification
/// and [onChangeNumber] to return to the phone input step.
class OtpVerificationView extends StatefulWidget {
  const OtpVerificationView({
    super.key,
    required this.viewModel,
    required this.phoneNumber,
    required this.onVerified,
    required this.onChangeNumber,
  });

  final LoginViewModel viewModel;
  final String phoneNumber;
  final VoidCallback onVerified;
  final VoidCallback onChangeNumber;

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final _otpCtrl = TextEditingController();

  LoginViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (_otpCtrl.text.length < 6) {
      _showSnack('Please enter the 6-digit OTP', isError: true);
      return;
    }
    final success = await _vm.verifyOTP(_otpCtrl.text.trim());
    if (success && mounted) {
      widget.onVerified();
    } else if (_vm.error != null && mounted) {
      _showSnack(_vm.error!, isError: true);
    }
  }

  Future<void> _resendOTP() async {
    final success = await _vm.resendOTP();
    if (mounted) {
      if (success) {
        _showSnack('OTP resent to ${widget.phoneNumber}');
      } else if (_vm.error != null) {
        _showSnack(_vm.error!, isError: true);
      }
    }
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

    final pinSize = (44 * scale).clamp(36.0, 52.0);
    final defaultPinTheme = PinTheme(
      width: pinSize,
      height: pinSize * 1.12,
      textStyle: TextStyle(
        fontSize: (20 * scale).clamp(16.0, 24.0),
        fontWeight: FontWeight.w600,
        color: AppColors.dark,
      ),
      decoration: BoxDecoration(
        color: AppColors.veryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.light),
      ),
    );

    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 4 * scale),
        Text(
          'Enter OTP',
          style: TextStyle(
            fontSize: (20 * scale).clamp(16.0, 24.0),
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          'Code sent to ${widget.phoneNumber}',
          style: TextStyle(
            color: AppColors.textMedium,
            fontSize: (12 * scale).clamp(11.0, 14.0),
          ),
        ),
        SizedBox(height: (32 * scale).clamp(22.0, 38.0)),

        // OTP pin input
        Center(
          child: FittedBox(
            child: Pinput(
              controller: _otpCtrl,
              length: 6,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme.copyDecorationWith(
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              submittedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  color: AppColors.veryLight,
                ),
              ),
              onCompleted: (_) => _verifyOTP(),
            ),
          ),
        ),

        SizedBox(height: (32 * scale).clamp(22.0, 38.0)),

        // Verify button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _vm.isLoading ? null : _verifyOTP,
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
                    'Verify & Login',
                    style: TextStyle(
                      fontSize: (15 * scale).clamp(13.0, 17.0),
                    ),
                  ),
          ),
        ),

        SizedBox(height: 14 * scale),

        // Resend OTP + Change Number row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _vm.isLoading ? null : widget.onChangeNumber,
              icon: Icon(Icons.arrow_back,
                  size: (16 * scale).clamp(14.0, 20.0)),
              label: Text(
                'Change Number',
                style: TextStyle(
                  fontSize: (13 * scale).clamp(11.0, 15.0),
                ),
              ),
            ),
            TextButton(
              onPressed: _vm.isLoading ? null : _resendOTP,
              child: Text(
                'Resend OTP',
                style: TextStyle(
                  fontSize: (13 * scale).clamp(11.0, 15.0),
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 4 * scale),
      ],
    );
  }
}
