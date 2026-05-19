import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/app_session.dart';
import '../core/app_theme.dart';
import 'media_preview.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onChanged;

  const PostCard({
    super.key,
    required this.post,
    this.onChanged,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int reactionsTotal = 0;
  int thoughtsCount = 0;
  Map<String, dynamic> reactionCounts = {};
  bool reacting = false;

  final List<Map<String, String>> reactions = const [
    {'type': 'boost', 'emoji': '🚀', 'label': 'Boost', 'subtitle': 'Push useful post'},
    {'type': 'support', 'emoji': '❤️', 'label': 'Support', 'subtitle': 'Show care'},
    {'type': 'useful', 'emoji': '💡', 'label': 'Useful', 'subtitle': 'Helpful info'},
    {'type': 'trend', 'emoji': '🔥', 'label': 'Trend', 'subtitle': 'Make it hot'},
    {'type': 'help', 'emoji': '🤲', 'label': 'Help', 'subtitle': 'Need action'},
    {'type': 'concern', 'emoji': '⚠️', 'label': 'Concern', 'subtitle': 'Not suitable / needs review'},
    {'type': 'angry', 'emoji': '😡', 'label': 'Angry', 'subtitle': 'This feels harmful'},
  ];

  @override
  void initState() {
    super.initState();
    updateCountsFromPost();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateCountsFromPost();
  }

  void updateCountsFromPost() {
    final counts = Map<String, dynamic>.from(widget.post['_count'] ?? {});
    reactionsTotal = counts['likes'] ?? 0;
    thoughtsCount = counts['comments'] ?? 0;
    reactionCounts = Map<String, dynamic>.from(widget.post['reactionCounts'] ?? {});
  }

  Future<void> reactToPost(String reactionType) async {
    final user = AppSession.currentUser;
    if (user == null || reacting) return;

    setState(() => reacting = true);

    try {
      final result = await ApiService.post(
        "/interactions/posts/${widget.post['id']}/reaction",
        {
          'userId': user['id'],
          'reactionType': reactionType,
        },
      );

      setState(() {
        reactionsTotal = result['reactionsTotal'] ?? reactionsTotal;
        thoughtsCount = result['thoughtsCount'] ?? thoughtsCount;
        reactionCounts = Map<String, dynamic>.from(result['reactionCounts'] ?? {});
      });

      widget.onChanged?.call();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Reaction updated'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaction failed: $e')),
      );
    }

    if (mounted) {
      setState(() => reacting = false);
    }
  }

  void openReactionSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  'React with meaning',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'CircleUp reactions help rank useful, safe and trusted content.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                ...reactions.map((reaction) {
                  final type = reaction['type']!;
                  final count = reactionCounts[type] ?? 0;
                  final isNegative = type == 'concern' || type == 'angry';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isNegative ? const Color(0xfffff7ed) : const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isNegative
                            ? Colors.orange.withOpacity(.25)
                            : Colors.black.withOpacity(.06),
                      ),
                    ),
                    child: ListTile(
                      leading: Text(
                        reaction['emoji']!,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        reaction['label']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(reaction['subtitle']!),
                      trailing: Chip(label: Text('$count')),
                      onTap: reacting ? null : () => reactToPost(type),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openThoughtSheet() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    final thoughtController = TextEditingController();
    List thoughts = [];
    bool loading = true;
    bool sending = false;
    String selectedMediaType = 'text';

    try {
      thoughts = await ApiService.get(
        "/interactions/posts/${widget.post['id']}/thoughts",
      );
      loading = false;
    } catch (_) {
      thoughts = [];
      loading = false;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> reloadThoughts() async {
              setSheetState(() => loading = true);

              try {
                thoughts = await ApiService.get(
                  "/interactions/posts/${widget.post['id']}/thoughts",
                );
              } catch (_) {
                thoughts = [];
              }

              setSheetState(() => loading = false);
            }

            Future<void> addThought() async {
              final text = thoughtController.text.trim();
              if (text.isEmpty || sending) return;

              setSheetState(() => sending = true);

              try {
                final result = await ApiService.post(
                  "/interactions/posts/${widget.post['id']}/thoughts",
                  {
                    'userId': user['id'],
                    'content': text,
                    'mediaType': selectedMediaType,
                    'mediaUrl': null,
                  },
                );

                thoughtController.clear();

                setState(() {
                  thoughtsCount = result['thoughtsCount'] ?? thoughtsCount;
                });

                await reloadThoughts();
                widget.onChanged?.call();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Thought failed: $e')),
                );
              }

              setSheetState(() => sending = false);
            }

            Widget mediaChip(String type, String label, IconData icon) {
              return ChoiceChip(
                selected: selectedMediaType == type,
                avatar: Icon(icon, size: 18),
                label: Text(label),
                onSelected: (_) {
                  setSheetState(() => selectedMediaType = type);
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Helpful Thoughts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add advice, support, image proof, short video idea, or real information.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        mediaChip('text', 'Text', Icons.notes),
                        mediaChip('image', 'Photo later', Icons.image),
                        mediaChip('video', 'Video later', Icons.videocam),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : thoughts.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.lightbulb_outline,
                                        size: 52,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No thoughts yet',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Be the first to add something helpful.',
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: thoughts.length,
                                  itemBuilder: (context, index) {
                                    final thought = Map<String, dynamic>.from(
                                      thoughts[index] as Map,
                                    );
                                    final thoughtUser =
                                        Map<String, dynamic>.from(
                                      thought['user'] ?? {},
                                    );

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfff8fafc),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.black.withOpacity(.06),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            child: Text(
                                              (thoughtUser['nickname'] ??
                                                      thoughtUser['name'] ??
                                                      'U')
                                                  .toString()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  thoughtUser['nickname'] ??
                                                      thoughtUser['name'] ??
                                                      'Unknown',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(thought['content'] ?? ''),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: thoughtController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Write a helpful thought...',
                              filled: true,
                              fillColor: const Color(0xfff8fafc),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: sending ? null : addThought,
                          child: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    thoughtController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(widget.post['user'] ?? {});
    final circle = Map<String, dynamic>.from(widget.post['circle'] ?? {});
    final latestThoughts = (widget.post['comments'] as List?) ?? [];
    final mediaUrl = widget.post['mediaUrl'];
    final mediaType = widget.post['mediaType'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.07),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.4),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['nickname'] ?? user['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        circle['name'] ?? 'Circle',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xffeef2ff),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    user['ageGroup'] ?? 'unknown',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.post['content'] ?? '',
              style: const TextStyle(
                fontSize: 15,
                height: 1.42,
                color: AppTheme.dark,
              ),
            ),
            if (mediaUrl != null && mediaUrl.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              MediaPreview(
                mediaUrl: mediaUrl,
                mediaType: mediaType,
                title: 'Post media uploaded',
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(.10),
                    AppTheme.accent.withOpacity(.10),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.post['smartReason'] ??
                          'Circle Insight: media posts can reach trusted circles faster.',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (reactionCounts.isNotEmpty && reactionsTotal > 0) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: reactions.map((reaction) {
                  final type = reaction['type']!;
                  final count = reactionCounts[type] ?? 0;
                  if (count == 0) return const SizedBox.shrink();

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withOpacity(.06)),
                    ),
                    child: Text('${reaction['emoji']} $count'),
                  );
                }).toList(),
              ),
            ],
            if (latestThoughts.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...latestThoughts.map<Widget>((item) {
                final thought = Map<String, dynamic>.from(item as Map);
                final thoughtUser = Map<String, dynamic>.from(
                  thought['user'] ?? {},
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8fafc),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${thoughtUser['nickname'] ?? thoughtUser['name'] ?? 'User'}: ${thought['content'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const Divider(height: 26),
            Row(
              children: [
                Expanded(
                  child: actionButton(
                    icon: Icons.emoji_emotions_outlined,
                    text: 'React',
                    count: reactionsTotal,
                    onTap: openReactionSheet,
                  ),
                ),
                Expanded(
                  child: actionButton(
                    icon: Icons.lightbulb_outline,
                    text: 'Thoughts',
                    count: thoughtsCount,
                    onTap: openThoughtSheet,
                  ),
                ),
                Expanded(
                  child: actionButton(
                    icon: Icons.send_outlined,
                    text: 'Share',
                    count: null,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share feature will be added later.'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget actionButton({
    required IconData icon,
    required String text,
    required int? count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(
              count == null ? text : '$text • $count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
