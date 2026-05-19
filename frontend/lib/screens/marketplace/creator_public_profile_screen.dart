import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';

class CreatorPublicProfileScreen extends StatefulWidget {
  final int creatorId;

  const CreatorPublicProfileScreen({
    super.key,
    required this.creatorId,
  });

  @override
  State<CreatorPublicProfileScreen> createState() =>
      _CreatorPublicProfileScreenState();
}

class _CreatorPublicProfileScreenState
    extends State<CreatorPublicProfileScreen> {
  bool loading = true;
  bool sendingRequest = false;
  Map<String, dynamic>? profile;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() => loading = true);

    try {
      final result = await ApiService.get(
        '/marketplace/creator/${widget.creatorId}',
      );

      profile = Map<String, dynamic>.from(result['data'] ?? {});
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> sendConnectionRequest() async {
    final me = AppSession.currentUser;
    final creator = profile;

    if (me == null || creator == null) return;

    setState(() => sendingRequest = true);

    try {
      final result = await ApiService.post('/connections/request', {
        'requesterId': me['id'],
        'receiverId': creator['id'],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Request sent.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connect failed: $e')),
      );
    }

    if (mounted) {
      setState(() => sendingRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creator = profile;
    final products = (creator?['products'] as List?) ?? [];
    final reels = (creator?['reels'] as List?) ?? [];
    final me = AppSession.currentUser;
    final isMe = me != null && creator != null && me['id'] == creator['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Profile'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : creator == null
              ? const EmptyState(
                  icon: Icons.person_off,
                  title: 'Creator not found',
                  subtitle: 'This profile is not available.',
                )
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
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white,
                            child: Text(
                              (creator['nickname'] ?? creator['name'] ?? 'C')
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            creator['nickname'] ?? creator['name'] ?? 'Creator',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            creator['name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(.86),
                            ),
                          ),
                          if ((creator['businessName'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Text(
                              creator['businessName'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            creator['creatorBio'] ??
                                'This creator has not added a bio yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.90),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              Chip(
                                label: Text(
                                  'Trust ${creator['trustScore'] ?? 0}',
                                ),
                              ),
                              Chip(
                                label: Text(
                                  creator['ageGroup'] ?? 'adult',
                                ),
                              ),
                              Chip(
                                label: Text(
                                  creator['businessCategory'] ?? 'General',
                                ),
                              ),
                              Chip(
                                label: Text(
                                  'Products ${creator['_count']?['products'] ?? 0}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (!isMe)
                            FilledButton.icon(
                              onPressed: sendingRequest ? null : sendConnectionRequest,
                              icon: sendingRequest
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.person_add),
                              label: const Text('Connect Safely'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Product Showcase',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (products.isEmpty)
                      const EmptyState(
                        icon: Icons.storefront,
                        title: 'No products yet',
                        subtitle: 'This creator has not added products.',
                      )
                    else
                      ...products.map((item) {
                        final product = Map<String, dynamic>.from(item);

                        return PremiumCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AppTheme.primary.withOpacity(.12),
                                child: const Icon(
                                  Icons.shopping_bag,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product['description'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '৳${product['price']} • ${product['category']}',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                    Text(
                      'Recent Reels',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (reels.isEmpty)
                      const EmptyState(
                        icon: Icons.play_circle,
                        title: 'No reels yet',
                        subtitle: 'Creator reels will appear here.',
                      )
                    else
                      ...reels.map((item) {
                        final reel = Map<String, dynamic>.from(item);

                        return PremiumCard(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.play_circle),
                            ),
                            title: Text(reel['caption'] ?? ''),
                            subtitle: Text(
                              '${reel['category']} • ${reel['ageGroup']} safe',
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
