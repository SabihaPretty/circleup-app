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
      withReadStream: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected.');
    }

    final file = result.files.first;

    final fileName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : 'circleup_upload_${DateTime.now().millisecondsSinceEpoch}.bin';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/media/upload'),
    );

    final token = AppSession.authToken;

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: fileName,
        ),
      );
    } else if (file.readStream != null && file.size > 0) {
      request.files.add(
        http.MultipartFile(
          'file',
          file.readStream!,
          file.size,
          filename: fileName,
        ),
      );
    } else {
      throw Exception('Selected file data could not be read. Please choose another file.');
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
            : response.body,
      );
    }

    if (decoded is! Map) {
      throw Exception('Upload response is invalid.');
    }

    final rawData = decoded['data'];

    if (rawData is! Map) {
      throw Exception('Upload response data is invalid.');
    }

    final data = Map<String, dynamic>.from(rawData);

    final rawUrl = data['url']?.toString();

    if (rawUrl == null || rawUrl.trim().isEmpty) {
      final fileNameFromServer = data['fileName']?.toString();

      if (fileNameFromServer == null || fileNameFromServer.trim().isEmpty) {
        throw Exception('Uploaded file URL is missing.');
      }

      data['url'] = '/uploads/$fileNameFromServer';
    }

    data['mediaType'] = (data['mediaType']?.toString().isNotEmpty ?? false)
        ? data['mediaType'].toString()
        : _detectMediaType(fileName);

    data['originalName'] = data['originalName']?.toString() ?? fileName;

    return data;
  }

  static String _detectMediaType(String fileName) {
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
        lower.endsWith('.webm')) {
      return 'video';
    }

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a')) {
      return 'audio';
    }

    return 'file';
  }
}
