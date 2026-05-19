import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/app_session.dart';
import '../core/app_theme.dart';
import '../core/media_upload_service.dart';

class ProfilePhotoUploader extends StatefulWidget {
  const ProfilePhotoUploader({super.key});

  @override
  State<ProfilePhotoUploader> createState() => _ProfilePhotoUploaderState();
}

class _ProfilePhotoUploaderState extends State<ProfilePhotoUploader> {
  bool uploading = false;

  String get imageUrl {
    final user = AppSession.currentUser;
    final raw = user?['profilePic']?.toString();

    if (raw == null || raw.isEmpty) return '';

    return ApiConfig.fullMediaUrl(raw);
  }

  Future<void> updateProfilePicture() async {
    final user = AppSession.currentUser;

    if (user == null || user['id'] == null) {
      showMessage('Please login first.');
      return;
    }

    setState(() => uploading = true);

    try {
      final uploaded = await MediaUploadService.pickAndUpload(
        type: FileType.image,
      );

      final result = await ApiService.post('/profile/picture', {
        'userId': user['id'],
        'profilePic': uploaded['url'],
      });

      final updatedUser = result['data'];

      if (updatedUser is Map) {
        await AppSession.updateCurrentUser(
          Map<String, dynamic>.from(updatedUser),
        );
      }

      if (!mounted) return;

      setState(() {});
      showMessage(result['message'] ?? 'Profile picture updated.');
    } catch (e) {
      showMessage('Profile picture update failed: $e');
    }

    if (mounted) setState(() => uploading = false);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final name = user?['nickname'] ?? user?['name'] ?? 'CircleUp User';
    final ageGroup = user?['ageGroup'] ?? 'member';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppTheme.primary.withOpacity(.12),
                backgroundImage:
                    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl.isEmpty
                    ? Text(
                        name.toString().trim().isEmpty
                            ? 'C'
                            : name.toString().trim()[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: AppTheme.primary,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$ageGroup account • update your profile photo',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: uploading ? null : updateProfilePicture,
            icon: uploading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}
