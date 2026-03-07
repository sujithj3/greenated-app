import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class SplashViewModel extends ChangeNotifier {
  final AuthService _authService;

  SplashViewModel(this._authService);

  bool get isLoggedIn => _authService.isLoggedIn;
}
