import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';

/// Splash screen — only responsible for:
/// 1. Animated branding (fade-in, scale, slide)
/// 2. Timed navigation to the login screen
///
/// Contains NO authentication UI or login logic.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)),
    );
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );

    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // 2-second splash duration
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthService>();
    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.8, 1.3);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.dark, AppColors.primary, AppColors.medium],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Animated Logo ──
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        width: (100 * scale).clamp(80.0, 130.0),
                        height: (100 * scale).clamp(80.0, 130.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.eco,
                          size: (54 * scale).clamp(40.0, 70.0),
                          color: AppColors.light,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 28 * scale),

                  // ── Animated Title ──
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'GREENATED',
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    (34 * scale).clamp(24.0, 44.0),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          SizedBox(height: 6 * scale),
                          Text(
                            'Farmer Registration System',
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.85),
                              fontSize:
                                  (14 * scale).clamp(12.0, 17.0),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: (70 * scale).clamp(50.0, 90.0)),

                  // ── Loading Indicator ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28 * scale,
                          height: 28 * scale,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        SizedBox(height: 14 * scale),
                        Text(
                          'Empowering Farmers',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: (12 * scale).clamp(11.0, 15.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
