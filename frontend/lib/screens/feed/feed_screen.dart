import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/api_config.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/media_upload_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final captionController = TextEditingController(text: 'My safe CircleUp story');

  bool loading = false;
  bool uploading = false;

  String selectedType = 'text';
  String selectedAge = 'adult';
  int durationHours = 24;

  Map<String, dynamic>? uploadedMedia;

  final List<String> ages = const ['kids', 'teen', 'adult', 'senior'];
  final List<int> durations = const [6, 12, 24, 48, 72];

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  Future<void> chooseStoryType(String type) async {
    setState(() {
      selectedType = type;
    });

    if (type == 'text') {
      setState(() {
        uploadedMedia = null;
      });
      return;
    }

    FileType pickerType = FileType.any;

    if (type == 'photo') {
      pickerType = FileType.image;
    } else if (type == 'video') {
      pickerType = FileType.video;
    } else {
      pickerType = FileType.any;
    }

    await uploadMedia(pickerType);
  }

  Future<void> uploadMedia(FileType pickerType) async {
    setState(() {
      uploading = true;
    });

    try {
      final media = await MediaUploadService.pickAndUpload(type: pickerType);

      if (!mounted) return;

      setState(() {
        uploadedMedia = media;
        selectedType = media['mediaType']?.toString() ?? selectedType;
      });

      showMessage('Upload successful.');
    } catch (e) {
      if (!mounted) return;
      showMessage('Upload failed: ${cleanError(e)}');
    }

    if (mounted) {
      setState(() {
        uploading = false;
      });
    }
  }

  Future<void> createStory() async {
    final user = AppSession.currentUser;

    if (user == null || user['id'] == null) {
      showMessage('Please login first.');
      return;
    }

    final caption = captionController.text.trim();
    final mediaUrl = uploadedMedia?['url']?.toString();
    final mediaType = uploadedMedia?['mediaType']?.toString() ?? selectedType;

    if (caption.isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) {
      showMessage('Write something or upload an image/video/file.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await ApiService.post('/stories', {
        'userId': user['id'],
        'caption': caption,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'ageGroup': selectedAge,
        'durationHours': durationHours,
      });

      if (!mounted) return;

      showMessage(result['message']?.toString() ?? 'Story created successfully.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showMessage('Create story failed: ${cleanError(e)}');
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  String cleanError(Object e) {
    return e.toString().replaceFirst('Exception: ', '');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget typeButton({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = selectedType == value;

    return ChoiceChip(
      selected: selected,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? AppTheme.primary : Colors.grey.shade700,
      ),
      label: Text(label),
      onSelected: uploading ? null : (_) => chooseStoryType(value),
    );
  }

  Widget mediaPreview() {
    final media = uploadedMedia;
    if (media == null) {
      return const SizedBox.shrink();
    }

    final mediaType = media['mediaType']?.toString() ?? 'file';
    final mediaUrl = media['url']?.toString();
    final originalName = media['originalName']?.toString() ?? 'Uploaded file';

    if (mediaUrl == null || mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final fullUrl = ApiConfig.fullMediaUrl(mediaUrl);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primary.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploaded ${mediaType.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (mediaType == 'photo')
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                fullUrl,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return filePreview(originalName);
                },
              ),
            )
          else
            filePreview(originalName),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: uploading
                ? null
                : () {
                    setState(() {
                      uploadedMedia = null;
                      selectedType = 'text';
                    });
                  },
            icon: const Icon(Icons.close),
            label: const Text('Remove upload'),
          ),
        ],
      ),
    );
  }

  Widget filePreview(String name) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff3f4ff),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fc),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Create Real Story',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload image, video or file and choose how long it will stay active.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: captionController,
              minLines: 4,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: 'Write your safe CircleUp story...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Story type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                typeButton(value: 'text', label: 'Text', icon: Icons.notes),
                typeButton(value: 'photo', label: 'Photo', icon: Icons.image),
                typeButton(value: 'video', label: 'Video', icon: Icons.play_circle_fill),
                typeButton(value: 'file', label: 'File', icon: Icons.attach_file),
              ],
            ),
            if (uploading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Uploading... Please wait.'),
            ],
            mediaPreview(),
            const SizedBox(height: 24),
            const Text(
              'Story audience age',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ages.map((age) {
                return ChoiceChip(
                  selected: selectedAge == age,
                  label: Text(age[0].toUpperCase() + age.substring(1)),
                  onSelected: (_) {
                    setState(() {
                      selectedAge = age;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Story duration',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: durationHours,
              items: durations.map((hour) {
                return DropdownMenuItem<int>(
                  value: hour,
                  child: Text('$hour hours'),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  durationHours = value;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: loading || uploading ? null : createStory,
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
      ),
    );
  }
}
