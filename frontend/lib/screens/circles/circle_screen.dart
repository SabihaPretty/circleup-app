import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../widgets/empty_state.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  bool loading = true;
  List circles = [];

  final nameController = TextEditingController(text: 'Family Circle');
  String circleType = 'family';

  @override
  void initState() {
    super.initState();
    loadCircles();
  }

  Future<void> loadCircles() async {
    setState(() => loading = true);

    try {
      circles = await ApiService.get('/circles');
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> createCircle() async {
    if (nameController.text.trim().isEmpty) return;

    try {
      final circle = await ApiService.post('/circles/create', {
        'name': nameController.text.trim(),
        'type': circleType,
      });

      AppSession.selectedCircle = circle;
      nameController.clear();

      await loadCircles();

      showMessage('Circle created and selected.');
    } catch (e) {
      showMessage('Circle create failed: $e');
    }
  }

  Widget circleTypeChip(String value, String label) {
    return ChoiceChip(
      selected: circleType == value,
      label: Text(label),
      onSelected: (_) => setState(() => circleType = value),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = AppSession.selectedCircle?['id'];

    return RefreshIndicator(
      onRefresh: loadCircles,
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
                    'Create Circle',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Circle name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      circleTypeChip('family', 'Family'),
                      circleTypeChip('friends', 'Friends'),
                      circleTypeChip('campus', 'Campus'),
                      circleTypeChip('work', 'Work'),
                      circleTypeChip('local', 'Local Area'),
                      circleTypeChip('business', 'Business'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: createCircle,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Circle'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Available Circles',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 10),

          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (circles.isEmpty)
            const EmptyState(
              icon: Icons.groups,
              title: 'No circle yet',
              subtitle: 'Create Family, Friends, Campus, Local, or Business circle.',
            )
          else
            ...circles.map((c) {
              final circle = Map<String, dynamic>.from(c);
              final isSelected = circle['id'] == selectedId;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(isSelected ? Icons.check : Icons.groups),
                  ),
                  title: Text(circle['name']),
                  subtitle: Text('Type: ${circle['type']}'),
                  trailing: isSelected
                      ? const Chip(label: Text('Selected'))
                      : FilledButton(
                          onPressed: () {
                            setState(() {
                              AppSession.selectedCircle = circle;
                            });
                            showMessage('${circle['name']} selected');
                          },
                          child: const Text('Select'),
                        ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
