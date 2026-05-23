import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_session.dart';

class MediaUploadService {
  static Future<Map<String, dynamic>> pickAndUpload({
    required FileType type,
  }) async {
    final result = await FilePicker.pickFiles(
      type: type,
      allowMultiple: false,
      withData: kIsWeb,
      withReadStream: !kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected.');
    }

    final file = result.files.first;

    final safeName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : 'circleup_upload_${DateTime.now().millisecondsSinceEpoch}.bin';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/media/upload'),
    );

    final token = AppSession.authToken;
    if (token != null && token.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (!kIsWeb && file.path != null && file.path!.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: safeName,
        ),
      );
    } else if (file.bytes != null && file.bytes!.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: safeName,
        ),
      );
    } else if (file.readStream != null && file.size > 0) {
      request.files.add(
        http.MultipartFile(
          'file',
          file.readStream!,
          file.size,
          filename: safeName,
        ),
      );
    } else {
      throw Exception('Selected file could not be read. Please choose another image/video/file.');
    }

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
            : 'Upload failed with status ${response.statusCode}',
      );
    }

    if (decoded is! Map || decoded['data'] is! Map) {
      throw Exception('Upload response is invalid.');
    }

    final data = Map<String, dynamic>.from(decoded['data']);

    final url = data['url']?.toString();
    if (url == null || url.trim().isEmpty || url == 'null') {
      throw Exception('Uploaded file URL is missing.');
    }

    data['url'] = url;
    data['mediaType'] = _safeMediaType(data['mediaType'], safeName);
    data['originalName'] = data['originalName']?.toString() ?? safeName;
    data['fileName'] = data['fileName']?.toString() ?? safeName;

    return data;
  }

  static String _safeMediaType(dynamic value, String fileName) {
    final fromServer = value?.toString().trim();
    if (fromServer != null && fromServer.isNotEmpty && fromServer != 'null') {
      return fromServer;
    }

    final lower = fileName.toLowerCase();

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return 'photo';
    }

    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp')) {
      return 'video';
    }

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac')) {
      return 'audio';
    }

    return 'file';
  }
}
