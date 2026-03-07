import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/env_config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/form_config_service.dart';
import 'utils/app_colors.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/category_screen.dart';
import 'screens/subcategory_screen.dart';
import 'screens/farmer_form_screen.dart';
import 'screens/land_measurement_screen.dart';
import 'screens/farmer_list_screen.dart';
import 'screens/farmer_detail_screen.dart';

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

  runApp(const FarmerRegistrationApp());
}

class FarmerRegistrationApp extends StatelessWidget {
  const FarmerRegistrationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => FormConfigService()),
      ],
      child: MaterialApp(
        title: 'Farmer Registration',
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
        routes: {
          '/': (ctx) => const SplashScreen(),
          '/login': (ctx) => const LoginScreen(),
          '/dashboard': (ctx) => const DashboardScreen(),
          '/categories': (ctx) => const CategoryScreen(),
          '/subcategories': (ctx) => const SubcategoryScreen(),
          '/farmer-form': (ctx) => const FarmerFormScreen(),
          '/land-measurement': (ctx) => const LandMeasurementScreen(),
          '/farmer-list': (ctx) => const FarmerListScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/farmer-detail') {
            return MaterialPageRoute(
              builder: (_) => FarmerDetailScreen(
                  farmerId: settings.arguments as String),
            );
          }
          return null;
        },
      ),
    );
  }
}
