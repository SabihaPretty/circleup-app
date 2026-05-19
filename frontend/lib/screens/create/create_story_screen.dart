import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/api_config.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/media_upload_service.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final captionController = TextEditingController();

  bool loading = false;
  bool uploading = false;

  String selectedAge = 'adult';
  int durationHours = 24;
  Map<String, dynamic>? media;

  final ages = const ['kids', 'teen', 'adult', 'senior'];
  final durations = const [6, 12, 24, 48, 72];

  @override
  void dispose() {
    captionController.dispose();
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

  Future<void> createStory() async {
    final user = AppSession.currentUser;

    if (user == null) {
      showMessage('Please login first.');
      return;
    }

    final caption = captionController.text.trim();

    if (caption.isEmpty && media == null) {
      showMessage('Write a caption or upload photo/video/file.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.post('/stories', {
        'userId': user['id'],
        'caption': caption,
        'mediaUrl': media?['url'],
        'mediaType': media?['mediaType'] ?? (media == null ? 'text' : 'file'),
        'ageGroup': selectedAge,
        'durationHours': durationHours,
      });

      if (!mounted) return;

      showMessage(result['message'] ?? 'Story created successfully.');
      Navigator.pop(context, true);
    } catch (e) {
      showMessage('Create story failed: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Story'),
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
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.auto_awesome, color: AppTheme.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create safe story with duration and age audience.',
                    style: TextStyle(
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
            controller: captionController,
            minLines: 4,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'Write story caption...',
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
          const SizedBox(height: 18),
          const Text(
            'Story audience age',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ages.map((age) {
              return ChoiceChip(
                selected: selectedAge == age,
                label: Text(age.toUpperCase()),
                onSelected: (_) => setState(() => selectedAge = age),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Text(
            'Story duration',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: durationHours,
            items: durations.map((hour) {
              return DropdownMenuItem<int>(
                value: hour,
                child: Text('$hour hours'),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => durationHours = value);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: loading ? null : createStory,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('Create Story'),
          ),
        ],
      ),
    );
  }
}
