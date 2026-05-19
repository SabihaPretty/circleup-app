import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_session.dart';

class ApiService {
  static Map<String, String> headers() {
    final token = AppSession.authToken;

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic parseResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map && decoded['message'] != null) {
      final message = decoded['message'];

      if (message is List) {
        throw Exception(message.join(', '));
      }

      throw Exception(message.toString());
    }

    throw Exception(response.body);
  }

  static Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: headers(),
    );

    return parseResponse(response);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: headers(),
      body: jsonEncode(body),
    );

    return parseResponse(response);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: headers(),
      body: jsonEncode(body),
    );

    return parseResponse(response);
  }

  static Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: headers(),
    );

    return parseResponse(response);
  }
}
