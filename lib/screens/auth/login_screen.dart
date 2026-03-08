import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _codeSent = false;
  String _selectedCountryCode = '+91';

  final List<String> _countryCodes = ['+91', '+1', '+44', '+61', '+971'];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthService>();
    final phone = '$_selectedCountryCode${_phoneCtrl.text.trim()}';

    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      onCodeSent: () {
        setState(() => _codeSent = true);
        _showSnack('OTP sent to $phone');
      },
      onError: (msg) => _showSnack(msg, isError: true),
    );
  }

  Future<void> _verifyOTP() async {
    if (_otpCtrl.text.length < 6) {
      _showSnack('Please enter the 6-digit OTP', isError: true);
      return;
    }
    final auth = context.read<AuthService>();
    final success = await auth.signInWithOTP(_otpCtrl.text.trim());
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (mounted && auth.error != null) {
      _showSnack(auth.error!, isError: true);
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
    final auth = context.watch<AuthService>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive scale factor based on screen width (reference: 375px)
    final scale = (screenWidth / 375).clamp(0.8, 1.3);

    // Responsive spacing
    final topSpacing = (screenHeight * 0.05).clamp(24.0, 48.0);
    final cardMargin = 10.0; // 10px horizontal padding as required
    final cardPadding = (28 * scale).clamp(20.0, 36.0);

    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final availableHeight = screenHeight - safeAreaTop - safeAreaBottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.dark, AppColors.primary, AppColors.medium],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // -- Header --
                    SizedBox(height: topSpacing),
                    Icon(Icons.eco, size: 56 * scale, color: AppColors.light),
                    SizedBox(height: (10 * scale)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'FARMER REGISTRATION',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (24 * scale).clamp(18.0, 30.0),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      'Farmer Registration System',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: (13 * scale).clamp(11.0, 15.0),
                      ),
                    ),
                    SizedBox(height: (32 * scale).clamp(20.0, 40.0)),

                    // -- Card --
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: cardMargin),
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.dark.withOpacity(0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _codeSent
                              ? _buildOtpView(auth, scale)
                              : _buildPhoneView(auth, scale),
                        ),
                      ),
                    ),
                    SizedBox(height: 32 * scale),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneView(AuthService auth, double scale) {
    return Column(
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
            // Country code picker - compact width
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
                  value: _selectedCountryCode,
                  isDense: true,
                  style: TextStyle(
                    fontSize: (14 * scale).clamp(12.0, 16.0),
                    color: AppColors.dark,
                  ),
                  items: _countryCodes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCountryCode = v!),
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
                    color: AppColors.textMedium.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.phone,
                    size: (20 * scale).clamp(18.0, 24.0),
                  ),
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

        SizedBox(height: (28 * scale).clamp(20.0, 34.0)),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _sendOTP,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14 * scale),
            ),
            child: auth.isLoading
                ? SizedBox(
                    width: 22 * scale,
                    height: 22 * scale,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Send OTP',
                    style: TextStyle(
                      fontSize: (15 * scale).clamp(13.0, 17.0),
                    ),
                  ),
          ),
        ),
        SizedBox(height: 6 * scale),
      ],
    );
  }

  Widget _buildOtpView(AuthService auth, double scale) {
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
          'Code sent to $_selectedCountryCode ${_phoneCtrl.text}',
          style: TextStyle(
            color: AppColors.textMedium,
            fontSize: (12 * scale).clamp(11.0, 14.0),
          ),
        ),
        SizedBox(height: (32 * scale).clamp(22.0, 38.0)),
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _verifyOTP,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14 * scale),
            ),
            child: auth.isLoading
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
        Center(
          child: TextButton.icon(
            onPressed: auth.isLoading
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _otpCtrl.clear();
                    }),
            icon: Icon(Icons.arrow_back, size: (16 * scale).clamp(14.0, 20.0)),
            label: Text(
              'Change Number',
              style: TextStyle(
                fontSize: (13 * scale).clamp(11.0, 15.0),
              ),
            ),
          ),
        ),
        SizedBox(height: 4 * scale),
      ],
    );
  }
}
