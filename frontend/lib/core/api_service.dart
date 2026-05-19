import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_session.dart';

class ApiService {
  static Uri _uri(String endpoint) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('${ApiConfig.baseUrl}$cleanEndpoint');
  }

  static Map<String, String> _headers({bool jsonBody = true}) {
    final headers = <String, String>{};

    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }

    final token = AppSession.authToken;

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      _uri(endpoint),
      headers: _headers(jsonBody: false),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      _uri(endpoint),
      headers: _headers(),
      body: jsonEncode(body),
    );

    final decoded = _handleResponse(response);
    await _autoSaveSession(endpoint, decoded);
    return decoded;
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      _uri(endpoint),
      headers: _headers(),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final response = await http.patch(
      _uri(endpoint),
      headers: _headers(),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      _uri(endpoint),
      headers: _headers(jsonBody: false),
    );

    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = response.body;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map && decoded['message'] != null) {
        throw Exception(decoded['message'].toString());
      }

      throw Exception(response.body.isEmpty
          ? 'Request failed with status ${response.statusCode}'
          : response.body);
    }

    return decoded;
  }

  static Future<void> _autoSaveSession(String endpoint, dynamic decoded) async {
    if (decoded is! Map) return;

    final lowerEndpoint = endpoint.toLowerCase();

    final looksLikeAuthResponse =
        lowerEndpoint.contains('/auth/login') ||
        lowerEndpoint.contains('/auth/register') ||
        lowerEndpoint.contains('/auth/login-2fa/verify') ||
        lowerEndpoint.endsWith('/login') ||
        lowerEndpoint.endsWith('/register');

    if (!looksLikeAuthResponse) return;

    final token = decoded['token']?.toString();
    final user = decoded['user'];

    if (token != null && token.isNotEmpty && user is Map) {
      await AppSession.saveSession(
        token: token,
        user: Map<String, dynamic>.from(user),
      );
    }
  }
}
