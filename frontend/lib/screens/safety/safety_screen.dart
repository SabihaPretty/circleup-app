import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  bool loading = true;
  bool submitting = false;

  List targetUsers = [];
  List myReports = [];
  List blockedUsers = [];
  List adminReports = [];

  String tab = 'report';
  String reason = 'Harassment';
  String severity = 'medium';
  int? selectedTargetUserId;

  final descriptionController = TextEditingController();

  final reasons = const [
    'Harassment',
    'Spam',
    'Adult / Unsafe content',
    'Fake account',
    'Hate / abusive behavior',
    'Scam / fraud',
    'Other',
  ];

  final severities = const ['low', 'medium', 'high', 'urgent'];

  @override
  void initState() {
    super.initState();
    loadSafetyData();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadSafetyData() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      final age = user['ageGroup'] ?? 'adult';

      if (age == 'kids') {
        final guardianResult = await ApiService.get('/guardian/user/${user['id']}');
        targetUsers = guardianResult['safeChatUsers'] ?? [];
      } else {
        final usersResult = await ApiService.get('/users');
        targetUsers = (usersResult as List).where((item) {
          final u = Map<String, dynamic>.from(item);
          return u['id'] != user['id'];
        }).toList();
      }

      final reportsResult = await ApiService.get('/safety/reports/my/${user['id']}');
      myReports = reportsResult['data'] ?? [];

      final blockedResult = await ApiService.get('/safety/blocked/${user['id']}');
      blockedUsers = blockedResult['data'] ?? [];

      final adminResult = await ApiService.get('/safety/reports/admin?status=all');
      adminReports = adminResult['data'] ?? [];

      if (selectedTargetUserId == null && targetUsers.isNotEmpty) {
        final first = Map<String, dynamic>.from(targetUsers.first);
        selectedTargetUserId = first['id'];
      }
    } catch (e) {
      debugPrint(e.toString());
      showMessage('Safety data load failed: $e');
    }

    setState(() => loading = false);
  }

  Map<String, dynamic>? selectedTargetUser() {
    if (selectedTargetUserId == null) return null;

    for (final item in targetUsers) {
      final user = Map<String, dynamic>.from(item);
      if (user['id'] == selectedTargetUserId) {
        return user;
      }
    }

    return null;
  }

  Future<void> submitReport() async {
    final me = AppSession.currentUser;
    final target = selectedTargetUser();

    if (me == null) return;

    if (target == null) {
      showMessage('Select a user first.');
      return;
    }

    setState(() => submitting = true);

    try {
      final result = await ApiService.post('/safety/reports/create', {
        'reporterId': me['id'],
        'reportedUserId': target['id'],
        'targetType': 'user',
        'targetId': target['id'],
        'reason': reason,
        'description': descriptionController.text.trim(),
        'severity': severity,
      });

      descriptionController.clear();
      await loadSafetyData();
      showMessage(result['message'] ?? 'Report submitted.');
    } catch (e) {
      showMessage('Report failed: $e');
    }

    if (mounted) {
      setState(() => submitting = false);
    }
  }

  Future<void> blockSelectedUser() async {
    final me = AppSession.currentUser;
    final target = selectedTargetUser();

    if (me == null) return;

    if (target == null) {
      showMessage('Select a user first.');
      return;
    }

    setState(() => submitting = true);

    try {
      final result = await ApiService.post('/safety/block', {
        'blockerId': me['id'],
        'blockedId': target['id'],
        'reason': reason,
      });

      await loadSafetyData();
      showMessage(result['message'] ?? 'User blocked.');
    } catch (e) {
      showMessage('Block failed: $e');
    }

    if (mounted) {
      setState(() => submitting = false);
    }
  }

  Future<void> unblockUser(int blockedId) async {
    final me = AppSession.currentUser;
    if (me == null) return;

    try {
      final result = await ApiService.post('/safety/unblock', {
        'blockerId': me['id'],
        'blockedId': blockedId,
      });

      await loadSafetyData();
      showMessage(result['message'] ?? 'User unblocked.');
    } catch (e) {
      showMessage('Unblock failed: $e');
    }
  }

  Future<void> reviewReport(int reportId, String status) async {
    final me = AppSession.currentUser;
    if (me == null) return;

    String actionTaken = 'Reviewed by safety team';

    if (status == 'resolved') {
      actionTaken = 'Safety action taken and report resolved';
    } else if (status == 'dismissed') {
      actionTaken = 'No policy issue found in this demo review';
    } else if (status == 'reviewing') {
      actionTaken = 'Report is now under active review';
    }

    try {
      final result = await ApiService.post('/safety/reports/$reportId/review', {
        'reviewerId': me['id'],
        'status': status,
        'actionTaken': actionTaken,
      });

      await loadSafetyData();
      showMessage(result['message'] ?? 'Report updated.');
    } catch (e) {
      showMessage('Review failed: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  Color severityColor(String value) {
    if (value == 'urgent') return Colors.red;
    if (value == 'high') return Colors.orange;
    if (value == 'medium') return AppTheme.warning;
    return AppTheme.success;
  }

  Color statusColor(String value) {
    if (value == 'resolved') return AppTheme.success;
    if (value == 'dismissed') return Colors.grey;
    if (value == 'reviewing') return AppTheme.primary;
    return AppTheme.warning;
  }

  Widget userDropdown() {
    if (targetUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off,
        title: 'No safety target available',
        subtitle: 'Kids can report only connected guardian/family contacts. Others can report visible users.',
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: selectedTargetUserId,
      decoration: InputDecoration(
        labelText: 'Select user',
        filled: true,
        fillColor: const Color(0xfff8fafc),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
      ),
      items: targetUsers.map((item) {
        final user = Map<String, dynamic>.from(item);

        return DropdownMenuItem<int>(
          value: user['id'],
          child: Text(
            '${user['nickname'] ?? user['name'] ?? 'User'} • ${user['ageGroup']}',
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => selectedTargetUserId = value);
      },
    );
  }

  Widget reportForm() {
    final target = selectedTargetUser();

    return Column(
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submit Safety Report',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use this for harassment, fake account, unsafe content, scam or abuse.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              userDropdown(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: reasons.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => reason = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: InputDecoration(
                  labelText: 'Severity',
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: severities.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => severity = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Explain what happened...',
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (target != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffeef2ff),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target: ${target['nickname'] ?? target['name']} • ${target['ageGroup']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: submitting || targetUsers.isEmpty ? null : submitReport,
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.report),
                      label: const Text('Report'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: submitting || targetUsers.isEmpty ? null : blockSelectedUser,
                      icon: const Icon(Icons.block),
                      label: const Text('Block'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget myReportsList() {
    if (myReports.isEmpty) {
      return const EmptyState(
        icon: Icons.report_outlined,
        title: 'No reports yet',
        subtitle: 'Submitted safety reports will appear here.',
      );
    }

    return Column(
      children: myReports.map((item) {
        final report = Map<String, dynamic>.from(item);
        final target = Map<String, dynamic>.from(report['reportedUser'] ?? {});
        final status = report['status'] ?? 'pending';
        final sev = report['severity'] ?? 'medium';

        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: severityColor(sev).withOpacity(.14),
                    child: Icon(Icons.report, color: severityColor(sev)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      report['reason'] ?? 'Report',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(status),
                    backgroundColor: statusColor(status).withOpacity(.14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Target: ${target['nickname'] ?? target['name'] ?? 'Unknown'}'),
              if ((report['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(report['description']),
              ],
              if ((report['actionTaken'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Action: ${report['actionTaken']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget blockedList() {
    if (blockedUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.block,
        title: 'No blocked users',
        subtitle: 'Blocked users will appear here.',
      );
    }

    return Column(
      children: blockedUsers.map((item) {
        final block = Map<String, dynamic>.from(item);
        final blocked = Map<String, dynamic>.from(block['blocked'] ?? {});

        return PremiumCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.withOpacity(.12),
                child: const Icon(Icons.block, color: Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blocked['nickname'] ?? blocked['name'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(blocked['ageGroup'] ?? ''),
                    if ((block['reason'] ?? '').toString().isNotEmpty)
                      Text(
                        'Reason: ${block['reason']}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => unblockUser(blocked['id']),
                child: const Text('Unblock'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget adminReviewList() {
    if (adminReports.isEmpty) {
      return const EmptyState(
        icon: Icons.admin_panel_settings,
        title: 'No admin reports',
        subtitle: 'All user reports will appear here for safety review.',
      );
    }

    return Column(
      children: adminReports.map((item) {
        final report = Map<String, dynamic>.from(item);
        final reporter = Map<String, dynamic>.from(report['reporter'] ?? {});
        final reported = Map<String, dynamic>.from(report['reportedUser'] ?? {});
        final status = report['status'] ?? 'pending';
        final sev = report['severity'] ?? 'medium';

        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: severityColor(sev).withOpacity(.14),
                    child: Icon(Icons.gavel, color: severityColor(sev)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      report['reason'] ?? 'Safety report',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(status),
                    backgroundColor: statusColor(status).withOpacity(.14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Reporter: ${reporter['nickname'] ?? reporter['name'] ?? 'Unknown'}'),
              Text('Reported: ${reported['nickname'] ?? reported['name'] ?? 'Unknown'}'),
              Text('Target: ${report['targetType']} #${report['targetId'] ?? '-'}'),
              if ((report['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(report['description']),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => reviewReport(report['id'], 'reviewing'),
                    child: const Text('Reviewing'),
                  ),
                  FilledButton(
                    onPressed: () => reviewReport(report['id'], 'resolved'),
                    child: const Text('Resolve'),
                  ),
                  OutlinedButton(
                    onPressed: () => reviewReport(report['id'], 'dismissed'),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget bodyByTab() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tab == 'report') return reportForm();
    if (tab == 'my_reports') return myReportsList();
    if (tab == 'blocked') return blockedList();

    return adminReviewList();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final age = user?['ageGroup'] ?? 'adult';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Center'),
      ),
      body: RefreshIndicator(
        onRefresh: loadSafetyData,
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
                    child: Icon(Icons.shield, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Safety Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$age account • report, block and review unsafe activity',
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
                  tabChip('report', 'Report', Icons.report, targetUsers.length),
                  tabChip('my_reports', 'My Reports', Icons.list_alt, myReports.length),
                  tabChip('blocked', 'Blocked', Icons.block, blockedUsers.length),
                  tabChip('admin', 'Admin Review', Icons.admin_panel_settings, adminReports.length),
                ],
              ),
            ),
            bodyByTab(),
          ],
        ),
      ),
    );
  }
}
