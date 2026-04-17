import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart'; // contains navigatorKey
import '../screens/auth/login_screen.dart'; // adjust path/class

class SessionHandler {
  static bool _isLoggingOut = false;

  static Future<void> forceLogout([String message = 'Session expired. Please sign in again.']) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    await AuthService.logout();

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    _isLoggingOut = false;
  }
}
