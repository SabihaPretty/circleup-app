import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool loading = true;

  Map<String, dynamic> summary = {};
  Map<String, dynamic> charts = {};
  Map<String, dynamic> recent = {};
  List recommendations = [];
  int healthScore = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() => loading = true);

    try {
      final result = await ApiService.get('/admin/dashboard');

      summary = Map<String, dynamic>.from(result['summary'] ?? {});
      charts = Map<String, dynamic>.from(result['charts'] ?? {});
      recent = Map<String, dynamic>.from(result['recent'] ?? {});
      recommendations = result['recommendations'] ?? [];
      healthScore = result['healthScore'] ?? 0;
    } catch (e) {
      debugPrint(e.toString());
      showMessage('Admin dashboard load failed: $e');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List listFromChart(String key) {
    final value = charts[key];

    if (value is List) return value;

    return [];
  }

  List listFromRecent(String key) {
    final value = recent[key];

    if (value is List) return value;

    return [];
  }

  Color healthColor() {
    if (healthScore >= 85) return AppTheme.success;
    if (healthScore >= 65) return AppTheme.warning;
    return Colors.red;
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 165,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppTheme.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget chartBar({
    required String label,
    required int value,
    required int maxValue,
    required Color color,
  }) {
    final percent = maxValue == 0 ? 0.0 : value / maxValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 11,
              backgroundColor: color.withOpacity(.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget chartCard({
    required String title,
    required String subtitle,
    required String chartKey,
    required IconData icon,
    required Color color,
  }) {
    final items = listFromChart(chartKey);
    int maxValue = 1;

    for (final item in items) {
      final row = Map<String, dynamic>.from(item);
      final value = int.tryParse('${row['value']}') ?? 0;
      if (value > maxValue) maxValue = value;
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(title, subtitle, icon, color),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.bar_chart,
              title: 'No chart data',
              subtitle: 'Data will appear after usage.',
            )
          else
            ...items.map((item) {
              final row = Map<String, dynamic>.from(item);
              final value = int.tryParse('${row['value']}') ?? 0;

              return chartBar(
                label: row['label'] ?? '',
                value: value,
                maxValue: maxValue,
                color: color,
              );
            }),
        ],
      ),
    );
  }

  Widget sectionTitle(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(.13),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget recentUsersCard() {
    final users = listFromRecent('users');

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Recent Users',
            'Latest registered accounts',
            Icons.people,
            AppTheme.primary,
          ),
          const SizedBox(height: 12),
          if (users.isEmpty)
            const EmptyState(
              icon: Icons.people_outline,
              title: 'No users',
              subtitle: 'Registered users will appear here.',
            )
          else
            ...users.map((item) {
              final user = Map<String, dynamic>.from(item);

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(.12),
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
                title: Text(user['nickname'] ?? user['name'] ?? 'User'),
                subtitle: Text('${user['ageGroup']} • trust ${user['trustScore']}'),
                trailing: Chip(label: Text(user['accountMode'] ?? 'personal')),
              );
            }),
        ],
      ),
    );
  }

  Widget recentPostsCard() {
    final posts = listFromRecent('posts');

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Recent Posts',
            'Latest feed activity',
            Icons.dynamic_feed,
            AppTheme.warning,
          ),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const EmptyState(
              icon: Icons.dynamic_feed,
              title: 'No posts',
              subtitle: 'Posts will appear here.',
            )
          else
            ...posts.map((item) {
              final post = Map<String, dynamic>.from(item);
              final user = Map<String, dynamic>.from(post['user'] ?? {});
              final count = Map<String, dynamic>.from(post['_count'] ?? {});

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.article),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By ${user['nickname'] ?? user['name'] ?? 'User'} • ${count['likes'] ?? 0} reactions • ${count['comments'] ?? 0} thoughts',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget recentReportsCard() {
    final reports = listFromRecent('reports');

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Recent Safety Reports',
            'Needs review and action',
            Icons.shield,
            Colors.red,
          ),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            const EmptyState(
              icon: Icons.verified_user,
              title: 'No safety reports',
              subtitle: 'Safety reports will appear here.',
            )
          else
            ...reports.map((item) {
              final report = Map<String, dynamic>.from(item);
              final reporter = Map<String, dynamic>.from(report['reporter'] ?? {});
              final reported = Map<String, dynamic>.from(report['reportedUser'] ?? {});

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.withOpacity(.10)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(.12),
                      child: const Icon(Icons.report, color: Colors.red),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['reason'] ?? 'Report',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By ${reporter['nickname'] ?? reporter['name'] ?? 'User'} → ${reported['nickname'] ?? reported['name'] ?? 'Target'}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Chip(label: Text(report['status'] ?? 'pending')),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget recentProductsCard() {
    final products = listFromRecent('products');

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Recent Products',
            'Marketplace activity',
            Icons.storefront,
            AppTheme.success,
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const EmptyState(
              icon: Icons.storefront,
              title: 'No products',
              subtitle: 'Products will appear here.',
            )
          else
            ...products.map((item) {
              final product = Map<String, dynamic>.from(item);
              final seller = Map<String, dynamic>.from(product['seller'] ?? {});

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.success.withOpacity(.12),
                  child: const Icon(Icons.shopping_bag, color: AppTheme.success),
                ),
                title: Text(product['name'] ?? 'Product'),
                subtitle: Text(
                  '৳${product['price']} • Seller: ${seller['businessName'] ?? seller['nickname'] ?? seller['name'] ?? 'Seller'}',
                ),
                trailing: Chip(label: Text(product['category'] ?? 'general')),
              );
            }),
        ],
      ),
    );
  }

  Widget recommendationCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Admin Recommendations',
            'What to check next',
            Icons.auto_awesome,
            AppTheme.accent,
          ),
          const SizedBox(height: 12),
          if (recommendations.isEmpty)
            const Text('No recommendation right now.')
          else
            ...recommendations.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates, color: AppTheme.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final age = user?['ageGroup'] ?? 'adult';
    final isAllowed = age == 'adult' || age == 'senior';

    if (!isAllowed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
        ),
        body: const EmptyState(
          icon: Icons.lock,
          title: 'Admin dashboard restricted',
          subtitle: 'Only adult or senior demo admin accounts can view this dashboard.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
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
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CircleUp Admin Analytics',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Monitor users, content, safety and marketplace health.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.86),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 31,
                          backgroundColor: Colors.white,
                          child: Text(
                            '$healthScore',
                            style: TextStyle(
                              color: healthColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Wrap(
                    children: [
                      statCard(
                        title: 'Total Users',
                        value: '${summary['totalUsers'] ?? 0}',
                        icon: Icons.people,
                        color: AppTheme.primary,
                      ),
                      statCard(
                        title: 'Posts',
                        value: '${summary['totalPosts'] ?? 0}',
                        icon: Icons.dynamic_feed,
                        color: AppTheme.warning,
                      ),
                      statCard(
                        title: 'Reels',
                        value: '${summary['totalReels'] ?? 0}',
                        icon: Icons.play_circle,
                        color: AppTheme.accent,
                      ),
                      statCard(
                        title: 'Products',
                        value: '${summary['totalProducts'] ?? 0}',
                        icon: Icons.storefront,
                        color: AppTheme.success,
                      ),
                      statCard(
                        title: 'Orders',
                        value: '${summary['totalOrders'] ?? 0}',
                        icon: Icons.receipt_long,
                        color: Colors.teal,
                      ),
                      statCard(
                        title: 'Pending Reports',
                        value: '${summary['pendingReports'] ?? 0}',
                        icon: Icons.report,
                        color: Colors.red,
                      ),
                      statCard(
                        title: 'Connections',
                        value: '${summary['totalConnections'] ?? 0}',
                        icon: Icons.people_alt,
                        color: Colors.indigo,
                      ),
                      statCard(
                        title: 'Guardian Links',
                        value: '${summary['totalGuardianLinks'] ?? 0}',
                        icon: Icons.family_restroom,
                        color: Colors.orange,
                      ),
                    ],
                  ),

                  chartCard(
                    title: 'Age Group Analytics',
                    subtitle: 'Kids, teen, adult and senior user balance',
                    chartKey: 'ageBreakdown',
                    icon: Icons.cake,
                    color: AppTheme.primary,
                  ),

                  chartCard(
                    title: 'Content Analytics',
                    subtitle: 'Posts, stories, reels and products',
                    chartKey: 'contentBreakdown',
                    icon: Icons.dashboard,
                    color: AppTheme.accent,
                  ),

                  chartCard(
                    title: 'Safety Analytics',
                    subtitle: 'Report review pipeline',
                    chartKey: 'safetyBreakdown',
                    icon: Icons.shield,
                    color: Colors.red,
                  ),

                  recommendationCard(),
                  recentUsersCard(),
                  recentReportsCard(),
                  recentPostsCard(),
                  recentProductsCard(),
                ],
              ),
      ),
    );
  }
}
