import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';
import 'group_room_screen.dart';

class GroupChatHomeScreen extends StatefulWidget {
  const GroupChatHomeScreen({super.key});

  @override
  State<GroupChatHomeScreen> createState() => _GroupChatHomeScreenState();
}

class _GroupChatHomeScreenState extends State<GroupChatHomeScreen> {
  bool loading = true;
  bool creating = false;

  List groups = [];
  List users = [];
  Set<int> selectedUserIds = {};

  final groupNameController = TextEditingController();
  final groupDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  @override
  void dispose() {
    groupNameController.dispose();
    groupDescriptionController.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    await Future.wait([
      loadGroups(),
      loadUsers(),
    ]);
  }

  Future<void> loadGroups() async {
    final me = AppSession.currentUser;
    if (me == null) return;

    setState(() => loading = true);

    try {
      final result = await ApiService.get('/groups/my/${me['id']}');
      groups = result['data'] ?? [];
    } catch (e) {
      showMessage('Groups load failed: $e');
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> loadUsers() async {
    try {
      final result = await ApiService.get('/users');
      users = result is List ? result : [];
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> createGroup() async {
    final me = AppSession.currentUser;

    if (me == null) return;

    if (groupNameController.text.trim().length < 2) {
      showMessage('Group name is required.');
      return;
    }

    setState(() => creating = true);

    try {
      final result = await ApiService.post('/groups', {
        'creatorId': me['id'],
        'name': groupNameController.text.trim(),
        'description': groupDescriptionController.text.trim(),
        'ageGroup': me['ageGroup'] ?? 'adult',
        'memberIds': selectedUserIds.toList(),
      });

      groupNameController.clear();
      groupDescriptionController.clear();
      selectedUserIds.clear();

      if (!mounted) return;

      Navigator.pop(context);
      showMessage(result['message'] ?? 'Group created.');
      await loadGroups();
    } catch (e) {
      showMessage('Create group failed: $e');
    }

    if (mounted) setState(() => creating = false);
  }

  void openCreateGroupSheet() {
    final me = AppSession.currentUser;

    selectedUserIds.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final availableUsers = users.where((item) {
              final user = Map<String, dynamic>.from(item);
              return user['id'] != me?['id'];
            }).toList();

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Group',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: groupNameController,
                      decoration: inputDecoration(
                        label: 'Group Name',
                        icon: Icons.groups,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: groupDescriptionController,
                      maxLines: 2,
                      decoration: inputDecoration(
                        label: 'Description',
                        icon: Icons.notes,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Members',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (availableUsers.isEmpty)
                      const EmptyState(
                        icon: Icons.people,
                        title: 'No users found',
                        subtitle: 'Create more accounts to add members.',
                      )
                    else
                      ...availableUsers.map((item) {
                        final user = Map<String, dynamic>.from(item);
                        final id = user['id'] as int;
                        final selected = selectedUserIds.contains(id);

                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == true) {
                                selectedUserIds.add(id);
                              } else {
                                selectedUserIds.remove(id);
                              }
                            });
                          },
                          title: Text(user['nickname'] ?? user['name'] ?? 'User'),
                          subtitle: Text('${user['ageGroup']}'),
                        );
                      }),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: creating ? null : createGroup,
                      icon: creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Create Group'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xfff8fafc),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  void openGroup(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupRoomScreen(group: group),
      ),
    ).then((_) => loadGroups());
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget groupCard(Map<String, dynamic> group) {
    final count = Map<String, dynamic>.from(group['_count'] ?? {});

    return PremiumCard(
      child: InkWell(
        onTap: () => openGroup(group),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.groups, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group['name'] ?? 'Group',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group['description'] ?? 'Group chat, group call and shared moments',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${count['members'] ?? 0} members • ${count['messages'] ?? 0} messages',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
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
        title: const Text('Group Chat'),
        actions: [
          IconButton(
            onPressed: loadGroups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openCreateGroupSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? const EmptyState(
                  icon: Icons.groups_2,
                  title: 'No group yet',
                  subtitle: 'Create your first group chat with friends, family, classmates or work team.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: AppTheme.darkGradient,
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.forum, color: AppTheme.primary),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Private groups, group calls, emoji effects and custom nicknames.',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...groups.map((item) {
                      return groupCard(Map<String, dynamic>.from(item));
                    }),
                  ],
                ),
    );
  }
}
