import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/env_config.dart';
import 'core/network/api_client.dart';
import 'core/network/http_client_impl.dart';
import 'core/network/interceptor/auth_interceptor.dart';
import 'core/network/interceptor/logging_interceptor.dart';
import 'repositories/category_repository.dart';
import 'services/auth_service.dart';
import 'services/category_api_service.dart';
import 'services/form_config_service.dart';
import 'services/image_upload_service.dart';
import 'services/registration_form_service.dart';
import 'utils/app_colors.dart';
import 'views/auth/splash_view.dart';
import 'views/auth/login_view.dart';
import 'views/dashboard/dashboard_view.dart';
import 'views/category/category_view.dart';
import 'views/category/subcategory_view.dart';
import 'views/farmer/farmer_form_view.dart';
import 'views/farmer/farmer_detail_view.dart';
import 'views/farmer/edit_farmer_details_view.dart';
import 'views/tools/land_measurement_view.dart';
import 'views/tools/camera_capture_view.dart';
import 'repositories/registered_list_repository.dart';
import 'view_models/registered_list_view_model.dart';
import 'views/farmer/registered_list_view.dart';
import 'models/flow_type.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

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
        Provider<ApiClient>(
          create: (_) => HttpClientImpl(
            interceptors: [
              LoggingInterceptor(),
              AuthInterceptor(tokenProvider: () => authService.accessToken),
            ],
          ),
        ),
        Provider<CategoryApiService>(
          create: (context) => CategoryApiService(
            apiClient: context.read<ApiClient>(),
            userIdProvider: () => context.read<AuthService>().userId,
          ),
        ),
        Provider<CategoryRepository>(
          create: (context) => CategoryRepositoryImpl(
            apiService: context.read<CategoryApiService>(),
          ),
        ),
        Provider<RegistrationFormService>(
          create: (context) => RegistrationFormService(
            apiClient: context.read<ApiClient>(),
          ),
        ),
        Provider<ImageUploadService>(
          create: (context) => ImageUploadService(
            apiClient: context.read<ApiClient>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => FormConfigService(
            categoryRepository: context.read<CategoryRepository>(),
            registrationFormService: context.read<RegistrationFormService>(),
          ),
        ),
        Provider<RegisteredListRepository>(
          create: (context) => RegisteredListRepositoryImpl(
            apiClient: context.read<ApiClient>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => RegisteredListViewModel(
            repository: context.read<RegisteredListRepository>(),
            authService: context.read<AuthService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Greenated',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'GB'),
        ],
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
              page = const DashboardView();
            case '/categories':
              page = const CategoryView();
            case '/subcategories':
              page = const SubcategoryView();
            case '/farmer-form':
              page = const FarmerFormView();
            case '/land-measurement':
              page = const LandMeasurementView();
            case '/camera-capture':
              page = const CameraCaptureView();
            case '/registered-farmers':
              final args = settings.arguments as Map<String, dynamic>? ?? {};
              page = RegisteredListView(
                flowType: args['flowType'] as FlowType? ?? FlowType.listing,
                subcategoryId: args['subcategoryId'] as int? ?? 0,
                category: args['category'] as String? ?? '',
                subcategory: args['subcategory'] as String? ?? '',
              );
            case '/farmer-detail':
              final detailArgs =
                  settings.arguments as Map<String, dynamic>? ?? {};
              page = FarmerDetailView(
                subcategoryId: detailArgs['subcategoryId'] as int? ?? 0,
                submissionId: detailArgs['submissionId'] as int? ?? 0,
              );
            case '/edit-farmer-details':
              final editArgs =
                  settings.arguments as Map<String, dynamic>? ?? {};
              page = EditFarmerDetailsView(
                subcategoryId: editArgs['subcategoryId'] as int? ?? 0,
                submissionId: editArgs['submissionId'] as int? ?? 0,
              );
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
