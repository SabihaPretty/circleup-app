import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_session.dart';

class MediaUploadResult {
  final String url;
  final String mediaType;
  final String filename;
  final String originalName;

  MediaUploadResult({
    required this.url,
    required this.mediaType,
    required this.filename,
    required this.originalName,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'mediaType': mediaType,
      'filename': filename,
      'originalName': originalName,
    };
  }
}

class MediaService {
  static Map<String, String> _headers() {
    final headers = <String, String>{};

    final token = AppSession.authToken;

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Future<MediaUploadResult?> _pickAndUpload({
    required FileType fileType,
    required String mediaType,
  }) async {
    final result = await FilePicker.pickFiles(
      type: fileType,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not read selected file.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/media/upload'),
    );

    request.headers.addAll(_headers());
    request.fields['mediaType'] = mediaType;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ),
    );

    final streamedResponse = await request.send().timeout(
          const Duration(minutes: 3),
        );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(response.body);
    }

    final data = jsonDecode(response.body);

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Upload failed.');
    }

    return MediaUploadResult(
      url: data['url'],
      mediaType: data['mediaType'] ?? mediaType,
      filename: data['filename'] ?? file.name,
      originalName: data['originalName'] ?? file.name,
    );
  }

  static Future<MediaUploadResult?> pickAndUploadImage() {
    return _pickAndUpload(
      fileType: FileType.image,
      mediaType: 'image',
    );
  }

  static Future<MediaUploadResult?> pickAndUploadVideo() {
    return _pickAndUpload(
      fileType: FileType.video,
      mediaType: 'video',
    );
  }

  static Future<MediaUploadResult?> pickAndUploadAnyFile() {
    return _pickAndUpload(
      fileType: FileType.any,
      mediaType: 'file',
    );
  }
}
