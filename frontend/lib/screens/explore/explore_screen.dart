import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_preview.dart';
import '../../widgets/post_card.dart';
import '../../widgets/premium_card.dart';
import '../marketplace/creator_public_profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool loading = true;
  String type = 'all';

  final searchController = TextEditingController();

  Map<String, dynamic> result = {};
  Map<String, dynamic> data = {};
  Map<String, dynamic> counts = {};

  @override
  void initState() {
    super.initState();
    loadExplore();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadExplore() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      final q = Uri.encodeComponent(searchController.text.trim());

      final response = await ApiService.get(
        '/search/all?userId=${user['id']}&q=$q&type=$type',
      );

      result = Map<String, dynamic>.from(response);
      data = Map<String, dynamic>.from(response['data'] ?? {});
      counts = Map<String, dynamic>.from(response['counts'] ?? {});
    } catch (e) {
      debugPrint(e.toString());
      showMessage('Explore failed: $e');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  List section(String key) {
    final value = data[key];
    if (value is List) return value;
    return [];
  }

  Future<void> sendConnectionRequest(Map<String, dynamic> targetUser) async {
    final me = AppSession.currentUser;
    if (me == null) return;

    try {
      final response = await ApiService.post('/connections/request', {
        'requesterId': me['id'],
        'receiverId': targetUser['id'],
      });

      showMessage(response['message'] ?? 'Connection request sent.');
      await loadExplore();
    } catch (e) {
      showMessage('Connect failed: $e');
    }
  }

  void openCreatorProfile(int creatorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorPublicProfileScreen(creatorId: creatorId),
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget typeChip(String value, String label, IconData icon) {
    return ChoiceChip(
      selected: type == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) async {
        setState(() => type = value);
        await loadExplore();
      },
    );
  }

  Widget sectionHeader(String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
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
      ),
    );
  }

  Widget userCard(Map<String, dynamic> user) {
    final me = AppSession.currentUser;
    final isMe = me != null && me['id'] == user['id'];

    return PremiumCard(
      child: Row(
        children: [
          Container(
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
          ),
          const SizedBox(width: 12),
          Expanded(
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
                Text(
                  user['businessName'] ?? user['name'] ?? '',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(user['ageGroup'] ?? 'adult'),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('Trust ${user['trustScore'] ?? 0}'),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(user['accountMode'] ?? 'personal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMe)
            FilledButton.icon(
              onPressed: () => sendConnectionRequest(user),
              icon: const Icon(Icons.person_add),
              label: const Text('Connect'),
            ),
        ],
      ),
    );
  }

  Widget reelCard(Map<String, dynamic> reel) {
    final creator = Map<String, dynamic>.from(reel['user'] ?? {});
    final mediaUrl = reel['mediaUrl'];
    final mediaType = reel['mediaType'];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.accent.withOpacity(.14),
                child: const Icon(Icons.play_circle, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reel['caption'] ?? 'Reel',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Chip(label: Text(reel['ageGroup'] ?? 'adult')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'By ${creator['nickname'] ?? creator['name'] ?? 'Creator'} • ${reel['category']}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (mediaUrl != null && mediaUrl.toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            MediaPreview(
              mediaUrl: mediaUrl,
              mediaType: mediaType,
              title: 'Reel media',
            ),
          ],
        ],
      ),
    );
  }

  Widget productCard(Map<String, dynamic> product) {
    final seller = Map<String, dynamic>.from(product['seller'] ?? {});

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.success.withOpacity(.14),
                child: const Icon(Icons.shopping_bag, color: AppTheme.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  product['name'] ?? 'Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Chip(label: Text('৳${product['price']}')),
            ],
          ),
          const SizedBox(height: 8),
          Text(product['description'] ?? ''),
          const SizedBox(height: 8),
          Text(
            '${product['category']} • Seller: ${seller['businessName'] ?? seller['nickname'] ?? seller['name'] ?? 'Seller'}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => openCreatorProfile(seller['id']),
            icon: const Icon(Icons.storefront),
            label: const Text('Open Seller Profile'),
          ),
        ],
      ),
    );
  }

  Widget usersSection() {
    final users = section('users');

    if (users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'People',
          'Safe people search based on age rules',
          Icons.people_alt,
          AppTheme.primary,
        ),
        ...users.map((item) => userCard(Map<String, dynamic>.from(item))),
      ],
    );
  }

  Widget postsSection() {
    final posts = section('posts');

    if (posts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Posts',
          'Safe posts from allowed age groups',
          Icons.dynamic_feed,
          AppTheme.warning,
        ),
        ...posts.take(8).map(
              (item) => PostCard(
                post: Map<String, dynamic>.from(item),
                onChanged: loadExplore,
              ),
            ),
      ],
    );
  }

  Widget reelsSection() {
    final reels = section('reels');

    if (reels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Reels',
          'Age-filtered reels and short media',
          Icons.play_circle,
          AppTheme.accent,
        ),
        ...reels.take(8).map(
              (item) => reelCard(Map<String, dynamic>.from(item)),
            ),
      ],
    );
  }

  Widget productsSection() {
    final products = section('products');

    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Products',
          'Marketplace search for adult/senior accounts',
          Icons.storefront,
          AppTheme.success,
        ),
        ...products.take(8).map(
              (item) => productCard(Map<String, dynamic>.from(item)),
            ),
      ],
    );
  }

  Widget trendingSection() {
    final trendingPosts = section('trendingPosts');
    final trendingReels = section('trendingReels');
    final trendingProducts = section('trendingProducts');

    if (trendingPosts.isEmpty &&
        trendingReels.isEmpty &&
        trendingProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Trending Explore',
          'Useful and fresh results for your safe mode',
          Icons.trending_up,
          AppTheme.primary,
        ),
        SizedBox(
          height: 155,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...trendingPosts.map((item) {
                final post = Map<String, dynamic>.from(item);

                return miniTrendCard(
                  icon: Icons.dynamic_feed,
                  title: 'Post',
                  subtitle: post['content'] ?? '',
                  color: AppTheme.warning,
                );
              }),
              ...trendingReels.map((item) {
                final reel = Map<String, dynamic>.from(item);

                return miniTrendCard(
                  icon: Icons.play_circle,
                  title: 'Reel',
                  subtitle: reel['caption'] ?? '',
                  color: AppTheme.accent,
                );
              }),
              ...trendingProducts.map((item) {
                final product = Map<String, dynamic>.from(item);

                return miniTrendCard(
                  icon: Icons.storefront,
                  title: 'Product',
                  subtitle: product['name'] ?? '',
                  color: AppTheme.success,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget miniTrendCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.13),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.13),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget emptyResult() {
    final total =
        (counts['users'] ?? 0) +
        (counts['posts'] ?? 0) +
        (counts['reels'] ?? 0) +
        (counts['products'] ?? 0);

    if (loading || total > 0) return const SizedBox.shrink();

    return const EmptyState(
      icon: Icons.search_off,
      title: 'No result found',
      subtitle: 'Try another keyword. Results are filtered by age and safety rules.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final age = user?['ageGroup'] ?? 'adult';
    final viewer = Map<String, dynamic>.from(result['viewer'] ?? {});
    final allowedAges = viewer['allowedContentAges'];

    return RefreshIndicator(
      onRefresh: loadExplore,
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
                  child: Icon(Icons.explore, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Safe Explore',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$age mode • allowed content: ${allowedAges is List ? allowedAges.join(', ') : 'loading'}',
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
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => loadExplore(),
                  decoration: InputDecoration(
                    hintText: 'Search people, posts, reels, products...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: loadExplore,
                    ),
                    filled: true,
                    fillColor: const Color(0xfff8fafc),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    typeChip('all', 'All', Icons.all_inbox),
                    typeChip('users', 'People', Icons.people_alt),
                    typeChip('posts', 'Posts', Icons.dynamic_feed),
                    typeChip('reels', 'Reels', Icons.play_circle),
                    typeChip('products', 'Products', Icons.storefront),
                  ],
                ),
              ],
            ),
          ),

          if (loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            PremiumCard(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('People ${counts['users'] ?? 0}')),
                  Chip(label: Text('Posts ${counts['posts'] ?? 0}')),
                  Chip(label: Text('Reels ${counts['reels'] ?? 0}')),
                  Chip(label: Text('Products ${counts['products'] ?? 0}')),
                ],
              ),
            ),
            trendingSection(),
            usersSection(),
            postsSection(),
            reelsSection(),
            productsSection(),
            emptyResult(),
          ],
        ],
      ),
    );
  }
}
