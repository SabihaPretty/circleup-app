import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static const String _tokenKey = 'circleup_auth_token';
  static const String _userKey = 'circleup_current_user';
  static const String _selectedCircleKey = 'circleup_selected_circle';

  static String? _authToken;
  static Map<String, dynamic>? _currentUser;
  static Map<String, dynamic>? _selectedCircle;
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

  static Map<String, dynamic>? get selectedCircle => _selectedCircle;

  static set selectedCircle(Map<String, dynamic>? value) {
    _selectedCircle = value == null ? null : Map<String, dynamic>.from(value);
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

    final circleText = prefs.getString(_selectedCircleKey);
    if (circleText != null && circleText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(circleText);
        if (decoded is Map) {
          _selectedCircle = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        _selectedCircle = null;
      }
    }

    _loadingFromStorage = false;
  }

  // Flexible compatibility method.
  // It supports both:
  // AppSession.setAuth(user, token)
  // AppSession.setAuth(token, user)
  static Future<void> setAuth(
    dynamic first,
    dynamic second,
  ) async {
    String? token;
    Map<String, dynamic>? user;

    if (first is Map && second is String) {
      user = Map<String, dynamic>.from(first);
      token = second;
    } else if (first is String && second is Map) {
      token = first;
      user = Map<String, dynamic>.from(second);
    } else {
      throw Exception('Invalid setAuth arguments. Expected user/token or token/user.');
    }

    _authToken = token;
    _currentUser = user;

    await _persistQuietly();
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
    _selectedCircle = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_selectedCircleKey);
  }

  static Future<void> logout() async {
    await clearSession();
  }

  static Future<void> _persistQuietly() async {
    final prefs = await SharedPreferences.getInstance();

    final token = _authToken;
    final user = _currentUser;
    final circle = _selectedCircle;

    if (token == null || token.trim().isEmpty || user == null) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } else {
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(user));
    }

    if (circle == null) {
      await prefs.remove(_selectedCircleKey);
    } else {
      await prefs.setString(_selectedCircleKey, jsonEncode(circle));
    }
  }
}
