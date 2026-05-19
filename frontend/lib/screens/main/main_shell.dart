import 'package:flutter/material.dart';
import '../../core/access_control.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../feed/feed_screen.dart';
import '../explore/explore_screen.dart';
import '../reels/reels_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../people/people_screen.dart';
import '../circles/circle_screen.dart';
import '../chat/chat_screen.dart';
import '../help/help_screen.dart';
import '../profile/profile_screen.dart';
import '../activity/activity_screen.dart';
import '../safety/safety_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../groups/group_chat_home_screen.dart';
import '../create/create_hub_screen.dart';

class MainNavItem {
  final String feature;
  final String title;
  final String label;
  final IconData icon;
  final Widget page;

  const MainNavItem({
    required this.feature,
    required this.title,
    required this.label,
    required this.icon,
    required this.page,
  });
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  int unreadCount = 0;

  List<MainNavItem> get navItems {
    final ageGroup = AppSession.currentUser?['ageGroup'] ?? 'adult';

    final all = <MainNavItem>[
      const MainNavItem(
        feature: 'feed',
        title: 'Home Feed',
        label: 'Feed',
        icon: Icons.dynamic_feed,
        page: FeedScreen(),
      ),
      const MainNavItem(
        feature: 'explore',
        title: 'Explore',
        label: 'Explore',
        icon: Icons.explore,
        page: ExploreScreen(),
      ),
      const MainNavItem(
        feature: 'reels',
        title: 'Reels',
        label: 'Reels',
        icon: Icons.play_circle,
        page: ReelsScreen(),
      ),
      const MainNavItem(
        feature: 'shop',
        title: 'Shop',
        label: 'Shop',
        icon: Icons.storefront,
        page: MarketplaceScreen(),
      ),
      const MainNavItem(
        feature: 'people',
        title: 'People',
        label: 'People',
        icon: Icons.people_alt,
        page: PeopleScreen(),
      ),
      const MainNavItem(
        feature: 'circles',
        title: 'Circles',
        label: 'Circles',
        icon: Icons.groups,
        page: CircleScreen(),
      ),
      const MainNavItem(
        feature: 'chat',
        title: 'Safe Chat',
        label: 'Chat',
        icon: Icons.chat,
        page: ChatScreen(),
      ),
      const MainNavItem(
        feature: 'help',
        title: 'Local Help',
        label: 'Help',
        icon: Icons.favorite,
        page: HelpScreen(),
      ),
      const MainNavItem(
        feature: 'profile',
        title: 'Profile',
        label: 'Profile',
        icon: Icons.person,
        page: ProfileScreen(),
      ),
    ];

    return all
        .where((item) => AccessControl.canUseFeature(ageGroup, item.feature))
        .toList();
  }

  bool get canOpenAdmin {
    final age = AppSession.currentUser?['ageGroup'] ?? 'adult';
    return age == 'adult' || age == 'senior';
  }

  @override
  void initState() {
    super.initState();
    loadUnreadCount();
  }

  Future<void> loadUnreadCount() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    try {
      final result = await ApiService.get('/notifications/unread/${user['id']}');

      if (!mounted) return;

      setState(() {
        unreadCount = result['unreadCount'] ?? 0;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }




  Future<void> openCreateHubScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateHubScreen()),
    );

    await loadUnreadCount();
  }
  Future<void> openGroupChatScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GroupChatHomeScreen()),
    );

    await loadUnreadCount();
  }
  Future<void> openSettingsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

    await loadUnreadCount();
  }
  Future<void> openActivityCenter() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivityScreen()),
    );

    await loadUnreadCount();
  }

  Future<void> openSafetyCenter() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SafetyScreen()),
    );

    await loadUnreadCount();
  }

  Future<void> openAdminDashboard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );

    await loadUnreadCount();
  }

  void setIndexByFeature(String feature) {
    final items = navItems;
    final foundIndex = items.indexWhere((item) => item.feature == feature);

    if (foundIndex >= 0) {
      setState(() => index = foundIndex);
    }
  }

  bool hasFeature(String feature) {
    return navItems.any((item) => item.feature == feature);
  }

  void showCreateSheet() {
    final ageGroup = AppSession.currentUser?['ageGroup'] ?? 'adult';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * .82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create something useful',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AccessControl.accessDescription(ageGroup),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  sheetTile(
                    icon: Icons.edit,
                    title: 'Create Post',
                    subtitle: 'Share update, news, information, study tip',
                    onTap: () {
                      Navigator.pop(context);
                      setIndexByFeature('feed');
                    },
                  ),
                  sheetTile(
                    icon: Icons.explore,
                    title: 'Open Explore',
                    subtitle: 'Search safe posts, reels, people and products',
                    onTap: () {
                      Navigator.pop(context);
                      setIndexByFeature('explore');
                    },
                  ),
                  sheetTile(
                    icon: Icons.shield,
                    title: 'Open Safety Center',
                    subtitle: 'Report, block and review unsafe activity',
                    onTap: () {
                      Navigator.pop(context);
                      openSafetyCenter();
                    },
                  ),
                  if (canOpenAdmin)
                    sheetTile(
                      icon: Icons.analytics,
                      title: 'Open Admin Dashboard',
                      subtitle: 'Analytics, users, safety and content overview',
                      onTap: () {
                        Navigator.pop(context);
                        openAdminDashboard();
                      },
                    ),
                  if (hasFeature('people'))
                    sheetTile(
                      icon: Icons.person_add,
                      title: 'Find People',
                      subtitle: 'Send safe connection requests',
                      onTap: () {
                        Navigator.pop(context);
                        setIndexByFeature('people');
                      },
                    ),
                  if (hasFeature('reels'))
                    sheetTile(
                      icon: Icons.play_circle,
                      title: 'Create Reel',
                      subtitle: 'Short video upload',
                      onTap: () {
                        Navigator.pop(context);
                        setIndexByFeature('reels');
                      },
                    ),
                  if (hasFeature('shop'))
                    sheetTile(
                      icon: Icons.storefront,
                      title: 'Add Product',
                      subtitle: 'Creator/business product showcase',
                      onTap: () {
                        Navigator.pop(context);
                        setIndexByFeature('shop');
                      },
                    ),
                  if (hasFeature('help'))
                    sheetTile(
                      icon: Icons.volunteer_activism,
                      title: 'Ask Local Help',
                      subtitle: 'Blood donor, study help, local info, farmer support',
                      onTap: () {
                        Navigator.pop(context);
                        setIndexByFeature('help');
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget sheetTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: AppTheme.primary.withOpacity(.12),
        child: Icon(icon, color: AppTheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final items = navItems;

    if (index >= items.length) {
      index = 0;
    }

    final activeItem = items[index];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.bubble_chart, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeItem.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${AccessControl.ageGroupLabel(user?['ageGroup'] ?? 'adult')} access',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: openCreateHubScreen,
          ),
IconButton(
            icon: const Icon(Icons.forum_outlined),
            onPressed: openGroupChatScreen,
          ),
IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: openSettingsScreen,
          ),
          if (canOpenAdmin)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              onPressed: openAdminDashboard,
            ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            onPressed: openSafetyCenter,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: openActivityCenter,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: activeItem.page,
      floatingActionButton: FloatingActionButton(
        onPressed: showCreateSheet,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: items.length <= 5
                  ? MediaQuery.of(context).size.width - 16
                  : items.length * 86,
              child: NavigationBar(
                selectedIndex: index,
                height: 72,
                onDestinationSelected: (value) {
                  setState(() => index = value);
                  loadUnreadCount();
                },
                destinations: items
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}





