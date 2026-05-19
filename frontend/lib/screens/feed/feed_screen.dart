import 'package:flutter/material.dart';
import 'package:frontend/core/api_service.dart';
import 'package:frontend/core/app_session.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/core/media_service.dart';
import 'package:frontend/widgets/media_preview.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  final VoidCallback? onCreated;
  final VoidCallback? onStoryCreated;
  final dynamic userId;
  final dynamic circleId;
  final dynamic initialAge;

  const FeedScreen({
    super.key,
    this.onChanged,
    this.onCreated,
    this.onStoryCreated,
    this.userId,
    this.circleId,
    this.initialAge,
  });

  @override
  State<FeedScreen> createState() => _CreateStoryDynamicState();
}

class _CreateStoryDynamicState extends State<FeedScreen> {
  final captionController = TextEditingController(text: 'My safe CircleUp story');

  String storyType = 'text';
  String audienceAge = 'adult';
  int durationHours = 24;

  bool uploading = false;
  bool creating = false;

  MediaUploadResult? uploadedMedia;

  final durationOptions = const [
    {'label': '6 hours', 'value': 6},
    {'label': '12 hours', 'value': 12},
    {'label': '24 hours', 'value': 24},
    {'label': '2 days', 'value': 48},
    {'label': '7 days', 'value': 168},
  ];

  @override
  void initState() {
    super.initState();

    final userAge = AppSession.currentUser?['ageGroup'] ?? 'adult';

    if (widget.initialAge != null) {
      audienceAge = widget.initialAge.toString();
    } else {
      audienceAge = userAge;
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  Future<void> pickMedia(String type) async {
    setState(() {
      storyType = type;
      uploadedMedia = null;
      uploading = true;
    });

    try {
      MediaUploadResult? result;

      if (type == 'image') {
        result = await MediaService.pickAndUploadImage();
      } else if (type == 'video') {
        result = await MediaService.pickAndUploadVideo();
      } else if (type == 'file') {
        result = await MediaService.pickAndUploadAnyFile();
      }

      if (!mounted) return;

      if (result == null) {
        setState(() {
          uploading = false;
        });
        showMessage('No file selected.');
        return;
      }

      setState(() {
        uploadedMedia = result;
        storyType = result!.mediaType;
        uploading = false;
      });

      showMessage('Upload successful.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        uploading = false;
        uploadedMedia = null;
      });

      showMessage('Upload failed: $e');
    }
  }

  Future<void> createStory() async {
    final user = AppSession.currentUser;

    if (user == null) {
      showMessage('Please login first.');
      return;
    }

    if (storyType != 'text' && uploadedMedia == null) {
      showMessage('Please upload media first.');
      return;
    }

    setState(() => creating = true);

    try {
      final response = await ApiService.post('/stories', {
        'userId': user['id'],
        'caption': captionController.text.trim(),
        'mediaType': storyType,
        'mediaUrl': uploadedMedia?.url,
        'ageGroup': audienceAge,
        'durationHours': durationHours,
        'circleId': widget.circleId,
      });

      widget.onChanged?.call();
      widget.onCreated?.call();
      widget.onStoryCreated?.call();

      if (!mounted) return;

      setState(() => creating = false);

      showMessage(response['message'] ?? 'Story created successfully.');

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() => creating = false);

      showMessage('Create story failed: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget typeChip({
    required String value,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: storyType == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: uploading || creating ? null : (_) => onTap(),
    );
  }

  Widget ageChip(String value, String label) {
    return ChoiceChip(
      selected: audienceAge == value,
      label: Text(label),
      onSelected: uploading || creating
          ? null
          : (_) {
              setState(() => audienceAge = value);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = uploading || creating;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox(
                width: 40,
                child: Divider(thickness: 4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create Real Story',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dark,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload image, video or file and choose how long it will stay active.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: captionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write story caption...',
                filled: true,
                fillColor: const Color(0xfff8fafc),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Story type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                typeChip(
                  value: 'text',
                  label: 'Text',
                  icon: Icons.notes,
                  onTap: () {
                    setState(() {
                      storyType = 'text';
                      uploadedMedia = null;
                    });
                  },
                ),
                typeChip(
                  value: 'image',
                  label: 'Photo',
                  icon: Icons.image,
                  onTap: () => pickMedia('image'),
                ),
                typeChip(
                  value: 'video',
                  label: 'Video',
                  icon: Icons.play_circle,
                  onTap: () => pickMedia('video'),
                ),
                typeChip(
                  value: 'file',
                  label: 'File',
                  icon: Icons.attach_file,
                  onTap: () => pickMedia('file'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (uploading)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffeef2ff),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Uploading media. Please wait...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (uploadedMedia != null && !uploading) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.success.withOpacity(.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        uploadedMedia!.originalName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              MediaPreview(
                mediaUrl: uploadedMedia!.url,
                mediaType: uploadedMedia!.mediaType,
                title: uploadedMedia!.originalName,
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Story audience age',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ageChip('kids', 'Kids'),
                ageChip('teen', 'Teen'),
                ageChip('adult', 'Adult'),
                ageChip('senior', 'Senior'),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Story duration',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: durationHours,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xfff8fafc),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
              items: durationOptions.map((item) {
                return DropdownMenuItem<int>(
                  value: item['value'] as int,
                  child: Text(item['label'].toString()),
                );
              }).toList(),
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => durationHours = value);
                    },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: isBusy ? null : createStory,
              icon: creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(creating ? 'Creating Story...' : 'Create Story'),
            ),
          ],
        ),
      ),
    );
  }
}
