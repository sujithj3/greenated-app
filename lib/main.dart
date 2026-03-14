import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/env_config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/form_config_service.dart';
import 'utils/app_colors.dart';
import 'views/auth/splash_view.dart';
import 'views/auth/login_view.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/category/category_screen.dart';
import 'screens/category/subcategory_screen.dart';
import 'screens/farmer/farmer_form_screen.dart';
import 'screens/tools/land_measurement_screen.dart';
import 'screens/farmer/farmer_list_screen.dart';
import 'screens/farmer/farmer_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  if (!EnvConfig.isDemoMode) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init failed (running in demo mode): $e');
    }
  }

  // Pre-initialize AuthService to ensure SharedPreferences is ready
  final authService = AuthService();
  await authService.init();

  runApp(FarmerRegistrationApp(authService: authService));
}
class FarmerRegistrationApp extends StatelessWidget {
  final AuthService authService;
  
  const FarmerRegistrationApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => FormConfigService()),
      ],
      child: MaterialApp(
        title: 'Greenated',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              // Demo mode banner
              if (EnvConfig.isDemoMode)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'DEMO MODE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        initialRoute: '/',
        onGenerateRoute: (settings) {
          Widget page;
          switch (settings.name) {
            case '/':
              page = const SplashView();
            case '/login':
              page = const LoginView();
            case '/dashboard':
              page = const DashboardScreen();
            case '/categories':
              page = const CategoryScreen();
            case '/subcategories':
              page = const SubcategoryScreen();
            case '/farmer-form':
              page = const FarmerFormScreen();
            case '/land-measurement':
              page = const LandMeasurementScreen();
            case '/farmer-list':
              page = const FarmerListScreen();
            case '/farmer-detail':
              page = FarmerDetailScreen(
                  farmerId: settings.arguments as String);
            default:
              page = const SplashView();
          }

          // ── Splash screen: no animation ──
          if (settings.name == '/') {
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => page,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (_, __, ___, child) => child,
            );
          }

          // ── Splash → Login: smooth fade transition ──
          if (settings.name == '/login') {
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => page,
              transitionDuration: const Duration(milliseconds: 500),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ),
                  child: child,
                );
              },
            );
          }

          // ── All other routes: platform-adaptive transitions ──
          return _buildAdaptiveRoute(page, settings);
        },
      ),
    );
  }

  /// Returns a platform-adaptive page route:
  /// - iOS: CupertinoPageRoute (native slide-from-right)
  /// - Android/other: custom fade + slide PageRouteBuilder
  static Route<dynamic> _buildAdaptiveRoute(
      Widget page, RouteSettings settings) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      return CupertinoPageRoute(
        builder: (_) => page,
        settings: settings,
      );
    }

    // Android / default: fade + slide
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

