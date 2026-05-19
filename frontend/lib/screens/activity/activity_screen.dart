import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool loading = true;
  List notifications = [];
  int unreadCount = 0;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      final result = await ApiService.get('/notifications/user/${user['id']}');

      notifications = result['data'] ?? [];
      unreadCount = result['unreadCount'] ?? 0;
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  List get filteredNotifications {
    if (filter == 'all') return notifications;
    if (filter == 'unread') {
      return notifications.where((n) => n['isRead'] == false).toList();
    }

    return notifications.where((n) => n['type'] == filter).toList();
  }

  Future<void> markOneRead(int notificationId) async {
    final user = AppSession.currentUser;
    if (user == null) return;

    try {
      await ApiService.post(
        '/notifications/$notificationId/read?userId=${user['id']}',
        {},
      );

      await loadNotifications();
    } catch (e) {
      showMessage('Failed to mark read: $e');
    }
  }

  Future<void> markAllRead() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    try {
      await ApiService.post('/notifications/read-all/${user['id']}', {});
      await loadNotifications();
      showMessage('All notifications marked as read.');
    } catch (e) {
      showMessage('Failed: $e');
    }
  }

  IconData iconForType(String type) {
    if (type == 'order') return Icons.shopping_bag;
    if (type == 'order_status') return Icons.receipt_long;
    if (type == 'reaction') return Icons.emoji_emotions_outlined;
    if (type == 'thought') return Icons.lightbulb_outline;
    return Icons.notifications;
  }

  Color colorForType(String type) {
    if (type == 'order') return AppTheme.success;
    if (type == 'order_status') return AppTheme.primary;
    if (type == 'reaction') return AppTheme.accent;
    if (type == 'thought') return AppTheme.warning;
    return AppTheme.primary;
  }

  Widget filterChip(String value, String label, IconData icon) {
    return ChoiceChip(
      selected: filter == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) {
        setState(() => filter = value);
      },
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Center'),
        actions: [
          TextButton(
            onPressed: unreadCount == 0 ? null : markAllRead,
            child: const Text('Read all'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: AppTheme.darkGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(.22),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.notifications_active,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Activity Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user?['name'] ?? 'User'} • $unreadCount unread',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.86),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(label: Text('$unreadCount new')),
                ],
              ),
            ),

            const SizedBox(height: 14),

            PremiumCard(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  filterChip('all', 'All', Icons.all_inbox),
                  filterChip('unread', 'Unread', Icons.mark_email_unread),
                  filterChip('order', 'Orders', Icons.shopping_bag),
                  filterChip('order_status', 'Status', Icons.receipt_long),
                  filterChip('reaction', 'Reactions', Icons.emoji_emotions),
                  filterChip('thought', 'Thoughts', Icons.lightbulb),
                ],
              ),
            ),

            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (filteredNotifications.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'No activity yet',
                subtitle: 'Reactions, thoughts and orders will appear here.',
              )
            else
              ...filteredNotifications.map((item) {
                final n = Map<String, dynamic>.from(item);
                final sender = Map<String, dynamic>.from(n['sender'] ?? {});
                final type = n['type'] ?? 'general';
                final isRead = n['isRead'] == true;
                final color = colorForType(type);

                return PremiumCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      if (!isRead) {
                        markOneRead(n['id']);
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: color.withOpacity(.13),
                              child: Icon(
                                iconForType(type),
                                color: color,
                              ),
                            ),
                            if (!isRead)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['title'] ?? 'Activity',
                                style: TextStyle(
                                  fontWeight:
                                      isRead ? FontWeight.w600 : FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n['message'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(type),
                                  ),
                                  if ((sender['name'] ?? '').toString().isNotEmpty)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('From ${sender['name']}'),
                                    ),
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(isRead ? 'Read' : 'New'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
