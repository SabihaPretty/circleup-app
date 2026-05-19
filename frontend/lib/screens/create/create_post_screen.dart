import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/api_config.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/media_upload_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final contentController = TextEditingController();

  bool loading = false;
  bool uploading = false;

  Map<String, dynamic>? media;

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  Future<void> pickMedia(FileType type) async {
    setState(() => uploading = true);

    try {
      final uploaded = await MediaUploadService.pickAndUpload(type: type);
      setState(() => media = uploaded);
      showMessage('File uploaded successfully.');
    } catch (e) {
      showMessage('Upload failed: $e');
    }

    if (mounted) setState(() => uploading = false);
  }

  Future<void> createPost() async {
    final user = AppSession.currentUser;

    if (user == null) {
      showMessage('Please login first.');
      return;
    }

    final content = contentController.text.trim();

    if (content.isEmpty && media == null) {
      showMessage('Write something or upload a file.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.post('/posts/create', {
        'userId': user['id'],
        'content': content,
        'mediaUrl': media?['url'],
        'mediaType': media?['mediaType'] ?? (media == null ? 'text' : 'file'),
      });

      if (!mounted) return;

      showMessage(result['message'] ?? 'Post created successfully.');
      Navigator.pop(context, true);
    } catch (e) {
      showMessage('Create post failed: $e');
    }

    if (mounted) setState(() => loading = false);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget mediaPreview() {
    if (media == null) return const SizedBox.shrink();

    final mediaType = media!['mediaType'];
    final url = '${ApiConfig.baseUrl}${media!['url']}';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primary.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected ${mediaType ?? 'file'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (mediaType == 'photo')
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.insert_drive_file, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    media!['originalName'] ?? 'Uploaded file',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => media = null),
            icon: const Icon(Icons.close),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget mediaButton({
    required IconData icon,
    required String label,
    required FileType type,
  }) {
    return OutlinedButton.icon(
      onPressed: uploading ? null : () => pickMedia(type),
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.darkGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.edit, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Share useful update as ${user?['nickname'] ?? user?['name'] ?? 'CircleUp user'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: contentController,
            minLines: 5,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Write update, news, information, study tip, local help...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              mediaButton(icon: Icons.image, label: 'Photo', type: FileType.image),
              mediaButton(icon: Icons.video_file, label: 'Video', type: FileType.video),
              mediaButton(icon: Icons.attach_file, label: 'File', type: FileType.any),
            ],
          ),
          if (uploading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Uploading file...'),
          ],
          mediaPreview(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: loading ? null : createPost,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Publish Post'),
          ),
        ],
      ),
    );
  }
}
