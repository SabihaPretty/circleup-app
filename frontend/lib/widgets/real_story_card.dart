import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class AddStoryCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddStoryCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 112,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          border: Border.all(color: AppTheme.primary.withOpacity(.20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'Add Story',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Safe share',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RealStoryCard extends StatelessWidget {
  final Map<String, dynamic> story;
  final VoidCallback onTap;

  const RealStoryCard({
    super.key,
    required this.story,
    required this.onTap,
  });

  Color getAgeColor(String age) {
    if (age == 'kids') return Colors.orange;
    if (age == 'teen') return Colors.indigo;
    if (age == 'senior') return Colors.green;
    return AppTheme.primary;
  }

  IconData getMediaIcon(String mediaType) {
    if (mediaType == 'image') return Icons.image;
    if (mediaType == 'video') return Icons.play_circle;
    return Icons.notes;
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(story['user'] ?? {});
    final circle = Map<String, dynamic>.from(story['circle'] ?? {});
    final age = story['ageGroup'] ?? 'adult';
    final mediaType = story['mediaType'] ?? 'text';
    final color = getAgeColor(age);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 118,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(.95),
              AppTheme.secondary.withOpacity(.75),
              AppTheme.accent.withOpacity(.70),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.20),
              blurRadius: 16,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: 20,
              child: Icon(
                getMediaIcon(mediaType),
                size: 62,
                color: Colors.white.withOpacity(.18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withOpacity(.16),
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
                  ),
                  const Spacer(),
                  Text(
                    user['name'] ?? 'User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    circle['name'] ?? '$age safe',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
