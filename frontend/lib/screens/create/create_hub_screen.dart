import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'create_post_screen.dart';
import 'create_story_screen.dart';

class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  void open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return InkWell(
      onTap: () => open(context, screen),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppTheme.darkGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.add, color: AppTheme.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create useful content safely for your circles.',
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
          const SizedBox(height: 18),
          actionCard(
            context: context,
            icon: Icons.edit,
            title: 'Create Post',
            subtitle: 'Share update, news, study tip, help or information.',
            screen: const CreatePostScreen(),
          ),
          actionCard(
            context: context,
            icon: Icons.auto_awesome,
            title: 'Create Story',
            subtitle: 'Upload photo, video or file with age-safe duration.',
            screen: const CreateStoryScreen(),
          ),
        ],
      ),
    );
  }
}
