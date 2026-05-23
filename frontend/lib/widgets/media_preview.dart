import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/api_config.dart';

class MediaPreview extends StatefulWidget {
  final String? url;
  final String? mediaType;
  final String? title;
  final VoidCallback? onRemove;

  const MediaPreview({
    super.key,
    this.url,
    this.mediaType,
    this.title,
    this.onRemove,
  });

  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  VideoPlayerController? controller;
  bool videoReady = false;

  String get fullUrl {
    final raw = widget.url;

    if (raw == null || raw.trim().isEmpty) {
      return '';
    }

    return ApiConfig.fullMediaUrl(raw);
  }

  String get type {
    final t = widget.mediaType?.toLowerCase().trim();

    if (t != null && t.isNotEmpty) {
      return t;
    }

    final lower = fullUrl.toLowerCase();

    if (lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('/video/')) {
      return 'video';
    }

    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('/image/')) {
      return 'photo';
    }

    return 'file';
  }

  @override
  void initState() {
    super.initState();
    initVideoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url || oldWidget.mediaType != widget.mediaType) {
      disposeVideo();
      initVideoIfNeeded();
    }
  }

  void initVideoIfNeeded() {
    if (fullUrl.isEmpty || type != 'video') {
      return;
    }

    controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl))
      ..initialize().then((_) {
        if (!mounted) return;

        controller?.setLooping(true);

        setState(() => videoReady = true);
      }).catchError((_) {
        if (!mounted) return;

        setState(() => videoReady = false);
      });
  }

  void disposeVideo() {
    controller?.dispose();
    controller = null;
    videoReady = false;
  }

  @override
  void dispose() {
    disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (fullUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff5546f2).withOpacity(.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.title!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: buildMedia(),
          ),
          if (widget.onRemove != null)
            TextButton.icon(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.close),
              label: const Text('Remove'),
            ),
        ],
      ),
    );
  }

  Widget buildMedia() {
    if (type == 'photo') {
      return Image.network(
        fullUrl,
        height: 210,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loading) {
          if (loading == null) return child;

          return const SizedBox(
            height: 210,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (_, __, ___) => fileBox(),
      );
    }

    if (type == 'video') {
      if (!videoReady || controller == null) {
        return Container(
          height: 210,
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        );
      }

      return Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: VideoPlayer(controller!),
          ),
          IconButton.filled(
            onPressed: () {
              setState(() {
                if (controller!.value.isPlaying) {
                  controller!.pause();
                } else {
                  controller!.play();
                }
              });
            },
            icon: Icon(
              controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
        ],
      );
    }

    return fileBox();
  }

  Widget fileBox() {
    return Container(
      height: 90,
      color: const Color(0xfff3f4ff),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.insert_drive_file,
            color: Color(0xff5546f2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title ?? fullUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
