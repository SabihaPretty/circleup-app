import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../widgets/empty_state.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final titleController = TextEditingController(text: 'Blood donor needed');
  final descriptionController = TextEditingController(
    text: 'Urgent blood donor needed nearby.',
  );

  String category = 'medical';
  List helpPosts = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadHelpPosts();
  }

  Future<void> loadHelpPosts() async {
    setState(() => loading = true);

    try {
      helpPosts = await ApiService.get('/help');
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> createHelpPost() async {
    final user = AppSession.currentUser;
    final circle = AppSession.selectedCircle;

    if (user == null) return;

    if (circle == null) {
      showMessage('Please select a circle first.');
      return;
    }

    try {
      await ApiService.post('/help/create', {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'category': category,
        'location': 'Local Area',
        'userId': user['id'],
        'circleId': circle['id'],
      });

      await loadHelpPosts();
      showMessage('Help post created.');
    } catch (e) {
      showMessage('Help post failed: $e');
    }
  }

  Widget categoryChip(String value, String label) {
    return ChoiceChip(
      selected: category == value,
      label: Text(label),
      onSelected: (_) => setState(() => category = value),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadHelpPosts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Local Help Feed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Help title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      categoryChip('medical', 'Medical'),
                      categoryChip('study', 'Study'),
                      categoryChip('farmer', 'Farmer'),
                      categoryChip('local', 'Local'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: createHelpPost,
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text('Create Help Post'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (helpPosts.isEmpty)
            const EmptyState(
              icon: Icons.volunteer_activism,
              title: 'No help posts',
              subtitle: 'Create local help request.',
            )
          else
            ...helpPosts.map((item) {
              final h = Map<String, dynamic>.from(item);
              final user = h['user'] ?? {};

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.help_outline)),
                  title: Text(h['title'] ?? ''),
                  subtitle: Text(
                    '${h['description'] ?? ''}\nBy: ${user['name'] ?? 'Unknown'} | ${h['category']}',
                  ),
                  isThreeLine: true,
                  trailing: Chip(label: Text(h['status'] ?? 'open')),
                ),
              );
            }),
        ],
      ),
    );
  }
}
