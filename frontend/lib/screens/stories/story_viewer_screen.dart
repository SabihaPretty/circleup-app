import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController controller;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  IconData mediaIcon(String type) {
    if (type == 'image') return Icons.image;
    if (type == 'video') return Icons.play_circle;
    return Icons.notes;
  }

  Color ageColor(String age) {
    if (age == 'kids') return Colors.orange;
    if (age == 'teen') return Colors.indigo;
    if (age == 'senior') return Colors.green;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No stories')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PageView.builder(
          controller: controller,
          itemCount: widget.stories.length,
          onPageChanged: (index) {
            setState(() => currentIndex = index);
          },
          itemBuilder: (context, index) {
            final story = widget.stories[index];
            final user = Map<String, dynamic>.from(story['user'] ?? {});
            final circle = Map<String, dynamic>.from(story['circle'] ?? {});
            final age = story['ageGroup'] ?? 'adult';
            final mediaType = story['mediaType'] ?? 'text';
            final color = ageColor(age);

            return Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(.95),
                    AppTheme.secondary,
                    AppTheme.accent,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -25,
                    top: 130,
                    child: Icon(
                      mediaIcon(mediaType),
                      size: 180,
                      color: Colors.white.withOpacity(.12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: List.generate(widget.stories.length, (barIndex) {
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: barIndex <= currentIndex
                                      ? Colors.white
                                      : Colors.white.withOpacity(.25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white,
                              child: Text(
                                (user['name'] ?? 'U')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['name'] ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${circle['name'] ?? 'Public'} • $age safe',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(
                          mediaIcon(mediaType),
                          size: 96,
                          color: Colors.white.withOpacity(.9),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          story['caption'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.16),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withOpacity(.20)),
                          ),
                          child: Text(
                            mediaType == 'text'
                                ? 'Text Story'
                                : mediaType == 'image'
                                    ? 'Photo Story Placeholder'
                                    : 'Video Story Placeholder',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.favorite_border),
                                label: const Text('React'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.send),
                                label: const Text('Share'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
