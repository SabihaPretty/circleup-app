import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static const String _tokenKey = 'circleup_auth_token';
  static const String _userKey = 'circleup_current_user';

  static String? _authToken;
  static Map<String, dynamic>? _currentUser;
  static bool _loadingFromStorage = false;

  static String? get authToken => _authToken;

  static set authToken(String? value) {
    _authToken = value;
    if (!_loadingFromStorage) {
      unawaited(_persistQuietly());
    }
  }

  static Map<String, dynamic>? get currentUser => _currentUser;

  static set currentUser(Map<String, dynamic>? value) {
    _currentUser = value == null ? null : Map<String, dynamic>.from(value);
    if (!_loadingFromStorage) {
      unawaited(_persistQuietly());
    }
  }

  static bool get isLoggedIn {
    return _authToken != null &&
        _authToken!.trim().isNotEmpty &&
        _currentUser != null;
  }

  static Future<void> loadSession() async {
    _loadingFromStorage = true;

    final prefs = await SharedPreferences.getInstance();

    _authToken = prefs.getString(_tokenKey);

    final userText = prefs.getString(_userKey);

    if (userText != null && userText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(userText);
        if (decoded is Map) {
          _currentUser = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        _currentUser = null;
      }
    }

    _loadingFromStorage = false;
  }

  static Future<void> saveSession({
    required String? token,
    required Map<String, dynamic>? user,
  }) async {
    _authToken = token;
    _currentUser = user == null ? null : Map<String, dynamic>.from(user);
    await _persistQuietly();
  }

  static Future<void> updateCurrentUser(Map<String, dynamic> user) async {
    _currentUser = Map<String, dynamic>.from(user);
    await _persistQuietly();
  }

  static Future<void> clearSession() async {
    _authToken = null;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<void> logout() async {
    await clearSession();
  }

  static Future<void> _persistQuietly() async {
    final prefs = await SharedPreferences.getInstance();

    final token = _authToken;
    final user = _currentUser;

    if (token == null || token.trim().isEmpty || user == null) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      return;
    }

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }
}
