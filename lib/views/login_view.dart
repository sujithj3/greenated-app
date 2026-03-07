import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../view_models/login_view_model.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final LoginViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = LoginViewModel(context.read<AuthService>());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await _vm.sendOTP(_phoneCtrl.text.trim());
    if (success && mounted) {
      _showSnack('OTP sent to ${_vm.selectedCountryCode}${_phoneCtrl.text.trim()}');
    } else if (_vm.error != null && mounted) {
      _showSnack(_vm.error!, isError: true);
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpCtrl.text.length < 6) {
      _showSnack('Please enter the 6-digit OTP', isError: true);
      return;
    }
    final success = await _vm.verifyOTP(_otpCtrl.text.trim());
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (_vm.error != null && mounted) {
      _showSnack(_vm.error!, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.dark, AppColors.primary],
              stops: [0.0, 0.45],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  const Icon(Icons.eco, size: 64, color: AppColors.light),
                  const SizedBox(height: 12),
                  const Text(
                    'FARMER REGISTRATION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Farmer Registration System',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.dark.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: _vm.codeSent
                          ? _buildOtpView()
                          : _buildPhoneView(),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Login with Phone',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark)),
        const SizedBox(height: 6),
        const Text('Enter your mobile number to receive a verification code.',
            style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
        const SizedBox(height: 28),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.veryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.light),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vm.selectedCountryCode,
                  isDense: true,
                  items: _vm.countryCodes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => _vm.setCountryCode(v!),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 7) return 'Invalid number';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _vm.isLoading ? null : _sendOTP,
            child: _vm.isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Send OTP'),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpView() {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.dark),
      decoration: BoxDecoration(
        color: AppColors.veryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.light),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter OTP',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark)),
        const SizedBox(height: 6),
        Text('Code sent to ${_vm.selectedCountryCode} ${_phoneCtrl.text}',
            style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
        const SizedBox(height: 32),
        Center(
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
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _vm.isLoading ? null : _verifyOTP,
            child: _vm.isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Verify & Login'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: _vm.isLoading
                ? null
                : () {
                    _vm.goBackToPhone();
                    _otpCtrl.clear();
                  },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Change Number'),
          ),
        ),
      ],
    );
  }
}
