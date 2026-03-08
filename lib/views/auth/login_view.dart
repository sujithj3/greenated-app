import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/auth/login_view_model.dart';
import 'login_with_phone_view.dart';
import 'otp_verification_view.dart';

/// Main authentication container screen.
///
/// Manages login steps and hosts the split background design.
/// Currently supports phone login; designed to be scalable for
/// future login methods (email, Google, Apple, etc.).
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final LoginViewModel _vm;
  String _fullPhoneNumber = '';

  @override
  void initState() {
    super.initState();
    _vm = LoginViewModel(context.read<AuthService>());
  }

  void _onOtpSent() {
    setState(() {
      _fullPhoneNumber =
          '${_vm.selectedCountryCode} ${_vm.lastPhoneNumber}';
    });
  }

  void _onVerified() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  void _onChangeNumber() {
    _vm.goBackToPhone();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = (screenWidth / 375).clamp(0.8, 1.3);
    final topSpacing = (screenHeight * 0.08).clamp(36.0, 64.0);
    final cardPadding = (28 * scale).clamp(20.0, 36.0);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        // Prevent Scaffold from resizing — background stays fixed
        resizeToAvoidBottomInset: false,
        body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => Stack(
          children: [
            // ── Fixed background layer ──
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.dark,
                      AppColors.primary,
                      Color(0xFFE8F0E4), // off-white/light green transition
                      Color(0xFFF5F7F2), // off-white bottom
                    ],
                    stops: [0.0, 0.30, 0.55, 0.70],
                  ),
                ),
              ),
            ),

            // ── Scrollable foreground content ──
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // ── Branding (slightly higher) ──
                      SizedBox(height: topSpacing),
                      Icon(Icons.eco,
                          size: 56 * scale, color: AppColors.light),
                      SizedBox(height: 10 * scale),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'GREENATED',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (28 * scale).clamp(20.0, 34.0),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        'Farmer Registration System',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: (13 * scale).clamp(11.0, 15.0),
                        ),
                      ),

                      // ── Gap between branding and modal (original spacing) ──
                   SizedBox(height: (80 * scale).clamp(60.0, 100.0)), 


                      // ── Modal Card ──
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.dark.withValues(alpha: 0.05),
                              blurRadius: 6,
                              spreadRadius: -1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
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
                          child: _vm.codeSent
                              ? OtpVerificationView(
                                  key: const ValueKey('otp'),
                                  viewModel: _vm,
                                  phoneNumber: _fullPhoneNumber,
                                  onVerified: _onVerified,
                                  onChangeNumber: _onChangeNumber,
                                )
                              : LoginWithPhoneView(
                                  key: const ValueKey('phone'),
                                  viewModel: _vm,
                                  onOtpSent: _onOtpSent,
                                ),
                        ),
                      ),
                      SizedBox(height: 32 * scale),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

