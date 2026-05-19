import 'package:flutter/material.dart';
import '../screens/auth/auth_screen.dart';
import 'app_session.dart';

class LogoutHelper {
  static Future<void> logout(BuildContext context) async {
    await AppSession.logout();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }
}
