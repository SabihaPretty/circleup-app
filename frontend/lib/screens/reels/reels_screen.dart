import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/media_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_preview.dart';
import '../../widgets/premium_card.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  bool loading = true;
  List reels = [];
  String category = 'all';

  @override
  void initState() {
    super.initState();
    loadReels();
  }

  String reelsEndpoint() {
    final ageGroup = AppSession.currentUser?['ageGroup'] ?? 'adult';
    final circleId = AppSession.selectedCircle?['id'];

    var url = '/reels?ageGroup=$ageGroup&category=$category';

    if (circleId != null) {
      url += '&circleId=$circleId';
    }

    return url;
  }

  Future<void> loadReels() async {
    setState(() => loading = true);

    try {
      final result = await ApiService.get(reelsEndpoint());
      reels = result['data'] ?? [];
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> openCreateReelSheet() async {
    final user = AppSession.currentUser;
    final circle = AppSession.selectedCircle;

    if (user == null) return;

    final captionController = TextEditingController(
      text: 'My first CircleUp reel',
    );

    String selectedMediaType = 'video';
    String selectedAge = user['ageGroup'] ?? 'adult';
    String selectedCategory = 'fun';
    MediaUploadResult? reelMedia;
    bool uploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget mediaChip(String value, String label, IconData icon) {
              return ChoiceChip(
                selected: selectedMediaType == value,
                avatar: Icon(icon, size: 18),
                label: Text(label),
                onSelected: (_) => setSheetState(() => selectedMediaType = value),
              );
            }

            Widget ageChip(String value, String label) {
              return ChoiceChip(
                selected: selectedAge == value,
                label: Text(label),
                onSelected: (_) => setSheetState(() => selectedAge = value),
              );
            }

            Widget categoryChip(String value, String label) {
              return ChoiceChip(
                selected: selectedCategory == value,
                label: Text(label),
                onSelected: (_) => setSheetState(() => selectedCategory = value),
              );
            }

            Future<void> uploadReelMedia() async {
              setSheetState(() => uploading = true);

              try {
                MediaUploadResult? result;

                if (selectedMediaType == 'video') {
                  result = await MediaService.pickAndUploadVideo();
                } else if (selectedMediaType == 'image') {
                  result = await MediaService.pickAndUploadImage();
                } else {
                  result = await MediaService.pickAndUploadAnyFile();
                }

                if (result != null) {
                  reelMedia = result;
                  selectedMediaType = result.mediaType;
                }
              } catch (e) {
                showMessage('Reel media upload failed: $e');
              }

              setSheetState(() => uploading = false);
            }

            Future<void> createReel() async {
              if (captionController.text.trim().isEmpty && reelMedia == null) {
                showMessage('Write reel caption or upload media first.');
                return;
              }

              try {
                await ApiService.post('/reels/create', {
                  'caption': captionController.text.trim().isEmpty
                      ? 'Uploaded a reel'
                      : captionController.text.trim(),
                  'mediaType': reelMedia?.mediaType ?? selectedMediaType,
                  'mediaUrl': reelMedia?.url,
                  'ageGroup': selectedAge,
                  'category': selectedCategory,
                  'userId': user['id'],
                  'circleId': circle?['id'],
                });

                if (!mounted) return;
                Navigator.pop(context);
                captionController.dispose();
                await loadReels();
                showMessage('Reel created.');
              } catch (e) {
                showMessage('Reel create failed: $e');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Reel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Upload real image/video/file to your age-safe reel.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: captionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write reel caption...',
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Reel type', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        mediaChip('video', 'Video', Icons.play_circle),
                        mediaChip('image', 'Photo Reel', Icons.image),
                        mediaChip('file', 'File Reel', Icons.attach_file),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: uploading ? null : uploadReelMedia,
                      icon: uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(uploading ? 'Uploading...' : 'Pick & Upload Media'),
                    ),
                    if (reelMedia != null) ...[
                      const SizedBox(height: 10),
                      MediaPreview(
                        mediaUrl: reelMedia!.url,
                        mediaType: reelMedia!.mediaType,
                        title: 'Reel media uploaded',
                        onRemove: () {
                          setSheetState(() => reelMedia = null);
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text('Audience age', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ageChip('kids', 'Kids'),
                        ageChip('teen', 'Teen'),
                        ageChip('adult', 'Adult'),
                        ageChip('senior', 'Senior'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        categoryChip('fun', 'Fun'),
                        categoryChip('study', 'Study'),
                        categoryChip('health', 'Health'),
                        categoryChip('farmer', 'Farmer'),
                        categoryChip('business', 'Business'),
                        categoryChip('local', 'Local'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: createReel,
                        icon: const Icon(Icons.upload),
                        label: const Text('Create Reel'),
                      ),
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

  Widget categoryChip(String value, String label) {
    return ChoiceChip(
      selected: category == value,
      label: Text(label),
      onSelected: (_) async {
        setState(() => category = value);
        await loadReels();
      },
    );
  }

  IconData reelIcon(String mediaType, String category) {
    if (mediaType == 'image') return Icons.image;
    if (mediaType == 'file') return Icons.attach_file;

    if (category == 'study') return Icons.school;
    if (category == 'health') return Icons.health_and_safety;
    if (category == 'farmer') return Icons.agriculture;
    if (category == 'business') return Icons.storefront;
    if (category == 'local') return Icons.location_on;

    return Icons.play_circle;
  }

  Color ageColor(String age) {
    if (age == 'kids') return Colors.orange;
    if (age == 'teen') return Colors.indigo;
    if (age == 'senior') return Colors.green;
    return AppTheme.primary;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAge = AppSession.currentUser?['ageGroup'] ?? 'unknown';

    return Column(
      children: [
        PremiumCard(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppTheme.mainGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.play_circle, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'CircleUp Reels',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: openCreateReelSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Age-safe reels with real uploaded media. Current mode: $userAge',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    categoryChip('all', 'All'),
                    const SizedBox(width: 8),
                    categoryChip('fun', 'Fun'),
                    const SizedBox(width: 8),
                    categoryChip('study', 'Study'),
                    const SizedBox(width: 8),
                    categoryChip('health', 'Health'),
                    const SizedBox(width: 8),
                    categoryChip('farmer', 'Farmer'),
                    const SizedBox(width: 8),
                    categoryChip('business', 'Business'),
                    const SizedBox(width: 8),
                    categoryChip('local', 'Local'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : reels.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const EmptyState(
                          icon: Icons.play_circle,
                          title: 'No reels yet',
                          subtitle: 'Create your first age-safe reel.',
                        ),
                        FilledButton.icon(
                          onPressed: openCreateReelSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Reel'),
                        ),
                      ],
                    )
                  : PageView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: reels.length,
                      itemBuilder: (context, index) {
                        final reel = Map<String, dynamic>.from(reels[index]);
                        final creator = Map<String, dynamic>.from(reel['user'] ?? {});
                        final circle = Map<String, dynamic>.from(reel['circle'] ?? {});
                        final age = reel['ageGroup'] ?? 'adult';
                        final reelCategory = reel['category'] ?? 'fun';
                        final mediaType = reel['mediaType'] ?? 'video';
                        final mediaUrl = reel['mediaUrl'];
                        final color = ageColor(age);

                        return Container(
                          margin: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color.withOpacity(.95),
                                AppTheme.secondary,
                                AppTheme.accent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(.22),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              if (mediaType == 'image' && mediaUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(34),
                                  child: Image.network(
                                    mediaUrl,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) {
                                      return Center(
                                        child: Icon(
                                          reelIcon(mediaType, reelCategory),
                                          size: 130,
                                          color: Colors.white.withOpacity(.82),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Center(
                                  child: Icon(
                                    reelIcon(mediaType, reelCategory),
                                    size: 130,
                                    color: Colors.white.withOpacity(.82),
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(34),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(.05),
                                      Colors.black.withOpacity(.55),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 18,
                                right: 82,
                                bottom: 26,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Chip(label: Text('$age safe')),
                                        Chip(label: Text(reelCategory)),
                                        Chip(label: Text(mediaType)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      reel['caption'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        height: 1.22,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '@${creator['nickname'] ?? creator['name'] ?? 'Creator'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      circle['name'] == null
                                          ? 'Public reel'
                                          : 'Circle: ${circle['name']}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(.88),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 14,
                                bottom: 30,
                                child: Column(
                                  children: [
                                    reelButton(Icons.favorite, 'Love'),
                                    const SizedBox(height: 16),
                                    reelButton(Icons.comment, 'Talk'),
                                    const SizedBox(height: 16),
                                    reelButton(Icons.share, 'Share'),
                                    const SizedBox(height: 16),
                                    reelButton(Icons.bookmark, 'Save'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget reelButton(IconData icon, String text) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white.withOpacity(.25),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
