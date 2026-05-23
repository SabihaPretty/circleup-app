import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class MediaPreview extends StatelessWidget {
  final String? mediaUrl;
  final String? mediaType;
  final String? title;
  final VoidCallback? onRemove;

  const MediaPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.title,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaUrl == null || mediaUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (mediaType == 'image') {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              mediaUrl!,
              width: double.infinity,
              height: 210,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return fallbackPreview(Icons.broken_image, 'Image failed to load');
              },
            ),
          ),
          if (onRemove != null) removeButton(),
        ],
      );
    }

    if (mediaType == 'video') {
      return Stack(
        children: [
          fallbackPreview(Icons.play_circle, title ?? 'Video uploaded'),
          if (onRemove != null) removeButton(),
        ],
      );
    }

    if (mediaType == 'audio') {
      return Stack(
        children: [
          fallbackPreview(Icons.graphic_eq, title ?? 'Audio uploaded'),
          if (onRemove != null) removeButton(),
        ],
      );
    }

    return Stack(
      children: [
        fallbackPreview(Icons.insert_drive_file, title ?? 'File uploaded'),
        if (onRemove != null) removeButton(),
      ],
    );
  }

  Widget fallbackPreview(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(.12),
            AppTheme.accent.withOpacity(.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withOpacity(.10)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget removeButton() {
    return Positioned(
      right: 10,
      top: 10,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.58),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
