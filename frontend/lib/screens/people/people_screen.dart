import 'package:flutter/material.dart';
import '../../core/access_control.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  bool loading = true;
  List suggestions = [];
  List accepted = [];
  List pendingReceived = [];
  List pendingSent = [];
  Map<String, dynamic> counts = {};
  String tab = 'suggestions';

  @override
  void initState() {
    super.initState();
    loadPeople();
  }

  Future<void> loadPeople() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      final suggestionsResult = await ApiService.get(
        '/connections/suggestions/${user['id']}',
      );

      final connectionsResult = await ApiService.get(
        '/connections/user/${user['id']}',
      );

      suggestions = suggestionsResult['data'] ?? [];
      accepted = connectionsResult['accepted'] ?? [];
      pendingReceived = connectionsResult['pendingReceived'] ?? [];
      pendingSent = connectionsResult['pendingSent'] ?? [];
      counts = Map<String, dynamic>.from(connectionsResult['counts'] ?? {});
    } catch (e) {
      debugPrint(e.toString());
      showMessage('People load failed: $e');
    }

    setState(() => loading = false);
  }

  Future<void> sendRequest(Map<String, dynamic> targetUser) async {
    final user = AppSession.currentUser;
    if (user == null) return;

    try {
      final result = await ApiService.post('/connections/request', {
        'requesterId': user['id'],
        'receiverId': targetUser['id'],
      });

      await loadPeople();
      showMessage(result['message'] ?? 'Request sent.');
    } catch (e) {
      showMessage('Request failed: $e');
    }
  }

  Future<void> respondRequest(int connectionId, String status) async {
    final user = AppSession.currentUser;
    if (user == null) return;

    try {
      final result = await ApiService.post(
        '/connections/$connectionId/respond',
        {
          'userId': user['id'],
          'status': status,
        },
      );

      await loadPeople();
      showMessage(result['message'] ?? 'Request updated.');
    } catch (e) {
      showMessage('Response failed: $e');
    }
  }

  Future<void> blockConnection(int connectionId) async {
    final user = AppSession.currentUser;
    if (user == null) return;

    try {
      final result = await ApiService.post(
        '/connections/$connectionId/block',
        {
          'userId': user['id'],
        },
      );

      await loadPeople();
      showMessage(result['message'] ?? 'Connection blocked.');
    } catch (e) {
      showMessage('Block failed: $e');
    }
  }

  Widget tabChip(String value, String label, IconData icon, int count) {
    return ChoiceChip(
      selected: tab == value,
      avatar: Icon(icon, size: 18),
      label: Text('$label $count'),
      onSelected: (_) {
        setState(() => tab = value);
      },
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget avatar(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          (user['nickname'] ?? user['name'] ?? 'U')
              .toString()
              .substring(0, 1)
              .toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget userInfo(Map<String, dynamic> user) {
    final myAge = AppSession.currentUser?['ageGroup'] ?? 'adult';
    final targetAge = user['ageGroup'] ?? 'adult';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user['nickname'] ?? user['name'] ?? 'User',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            user['name'] ?? '',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(targetAge),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Trust ${user['trustScore'] ?? 0}'),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  AccessControl.canConnect(myAge, targetAge)
                      ? 'Safe'
                      : 'Blocked',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget suggestionCard(Map<String, dynamic> user) {
    return PremiumCard(
      child: Row(
        children: [
          avatar(user),
          const SizedBox(width: 12),
          userInfo(user),
          FilledButton.icon(
            onPressed: () => sendRequest(user),
            icon: const Icon(Icons.person_add),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget pendingReceivedCard(Map<String, dynamic> item) {
    final user = Map<String, dynamic>.from(item['otherUser'] ?? {});

    return PremiumCard(
      child: Column(
        children: [
          Row(
            children: [
              avatar(user),
              const SizedBox(width: 12),
              userInfo(user),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => respondRequest(item['id'], 'accepted'),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => respondRequest(item['id'], 'rejected'),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget pendingSentCard(Map<String, dynamic> item) {
    final user = Map<String, dynamic>.from(item['otherUser'] ?? {});

    return PremiumCard(
      child: Row(
        children: [
          avatar(user),
          const SizedBox(width: 12),
          userInfo(user),
          const Chip(label: Text('Pending')),
        ],
      ),
    );
  }

  Widget acceptedCard(Map<String, dynamic> item) {
    final user = Map<String, dynamic>.from(item['otherUser'] ?? {});

    return PremiumCard(
      child: Column(
        children: [
          Row(
            children: [
              avatar(user),
              const SizedBox(width: 12),
              userInfo(user),
              const Chip(label: Text('Connected')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => tab = 'connected');
                    showMessage('Open Chat tab to message this safe connection.');
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => blockConnection(item['id']),
                  icon: const Icon(Icons.block),
                  label: const Text('Block'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget activeList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tab == 'suggestions') {
      if (suggestions.isEmpty) {
        return const EmptyState(
          icon: Icons.person_search,
          title: 'No safe suggestions',
          subtitle: 'New safe users will appear here.',
        );
      }

      return Column(
        children: suggestions
            .map((item) => suggestionCard(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }

    if (tab == 'requests') {
      if (pendingReceived.isEmpty) {
        return const EmptyState(
          icon: Icons.inbox,
          title: 'No received requests',
          subtitle: 'Connection requests will appear here.',
        );
      }

      return Column(
        children: pendingReceived
            .map((item) => pendingReceivedCard(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }

    if (tab == 'sent') {
      if (pendingSent.isEmpty) {
        return const EmptyState(
          icon: Icons.outbox,
          title: 'No sent requests',
          subtitle: 'Your pending requests will appear here.',
        );
      }

      return Column(
        children: pendingSent
            .map((item) => pendingSentCard(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }

    if (accepted.isEmpty) {
      return const EmptyState(
        icon: Icons.people,
        title: 'No connections yet',
        subtitle: 'Accept or send connection requests first.',
      );
    }

    return Column(
      children: accepted
          .map((item) => acceptedCard(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final age = user?['ageGroup'] ?? 'adult';

    return RefreshIndicator(
      onRefresh: loadPeople,
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
                  child: Icon(Icons.people_alt, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Safe Connections',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AccessControl.accessDescription(age),
                        style: TextStyle(
                          color: Colors.white.withOpacity(.86),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
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
                tabChip('suggestions', 'Suggestions', Icons.person_search, suggestions.length),
                tabChip('requests', 'Requests', Icons.inbox, pendingReceived.length),
                tabChip('sent', 'Sent', Icons.outbox, pendingSent.length),
                tabChip('connected', 'Connected', Icons.people, accepted.length),
              ],
            ),
          ),
          activeList(),
        ],
      ),
    );
  }
}
