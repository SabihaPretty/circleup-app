import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_session.dart';

class MediaUploadService {
  static Future<Map<String, dynamic>> pickAndUpload({
    required FileType type,
  }) async {
    final result = await FilePicker.pickFiles(
      type: type,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected.');
    }

    final file = result.files.first;

    if (file.bytes == null) {
      throw Exception('Selected file data could not be read.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/media/upload'),
    );

    final token = AppSession.authToken;

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    dynamic decoded;

    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = response.body;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : response.body,
      );
    }

    return Map<String, dynamic>.from(decoded['data'] ?? {});
  }
}
