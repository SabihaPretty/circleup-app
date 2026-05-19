import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/premium_card.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController creatorBioController;
  late TextEditingController businessNameController;
  late TextEditingController businessCategoryController;

  String accountMode = 'personal';
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final user = AppSession.currentUser ?? {};

    accountMode = user['accountMode'] ?? 'personal';

    creatorBioController = TextEditingController(
      text: user['creatorBio'] ?? '',
    );

    businessNameController = TextEditingController(
      text: user['businessName'] ?? '',
    );

    businessCategoryController = TextEditingController(
      text: user['businessCategory'] ?? '',
    );
  }

  @override
  void dispose() {
    creatorBioController.dispose();
    businessNameController.dispose();
    businessCategoryController.dispose();
    super.dispose();
  }

  Future<void> saveCreatorMode() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    setState(() => saving = true);

    try {
      final updatedUser = await ApiService.post('/users/creator-mode', {
        'userId': user['id'],
        'accountMode': accountMode,
        'creatorBio': creatorBioController.text.trim(),
        'businessName': businessNameController.text.trim(),
        'businessCategory': businessCategoryController.text.trim(),
      });

      AppSession.currentUser = Map<String, dynamic>.from(updatedUser);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile mode updated.')),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }

    if (mounted) {
      setState(() => saving = false);
    }
  }

  Widget modeChip(String value, String label, IconData icon) {
    return ChoiceChip(
      selected: accountMode == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => setState(() => accountMode = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final circle = AppSession.selectedCircle;

    return ListView(
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
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primary.withOpacity(.12),
                  child: Text(
                    (user?['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?['name'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                user?['email'] ?? '',
                style: TextStyle(color: Colors.white.withOpacity(.84)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Chip(label: Text('Age: ${user?['ageGroup'] ?? 'unknown'}')),
                  Chip(label: Text('Trust: ${user?['trustScore'] ?? 0}')),
                  Chip(label: Text('Mode: ${user?['accountMode'] ?? 'personal'}')),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Creator / Business Mode',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use this to become a creator, small business seller, teacher, doctor, farmer guide, or local helper.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  modeChip('personal', 'Personal', Icons.person),
                  modeChip('creator', 'Creator', Icons.workspace_premium),
                  modeChip('business', 'Business', Icons.storefront),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: creatorBioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Creator Bio',
                  hintText: 'Example: I share study, health, farming or business tips.',
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: businessNameController,
                decoration: InputDecoration(
                  labelText: 'Business Name',
                  hintText: 'Example: CircleUp Fresh Shop',
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: businessCategoryController,
                decoration: InputDecoration(
                  labelText: 'Business / Creator Category',
                  hintText: 'Example: Education, Health, Farmer, Food, Local Service',
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: saving ? null : saveCreatorMode,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Mode'),
              ),
            ],
          ),
        ),

        PremiumCard(
          child: ListTile(
            leading: const Icon(Icons.groups, color: AppTheme.primary),
            title: const Text('Selected Circle'),
            subtitle: Text(circle?['name'] ?? 'No circle selected'),
          ),
        ),

        const PremiumCard(
          child: ListTile(
            leading: Icon(Icons.memory, color: AppTheme.primary),
            title: Text('AI Memory Timeline'),
            subtitle: Text('Placeholder: Monthly memories will be generated later.'),
            trailing: Icon(Icons.auto_awesome),
          ),
        ),

        const PremiumCard(
          child: ListTile(
            leading: Icon(Icons.family_restroom, color: AppTheme.warning),
            title: Text('Kids Safe Mode'),
            subtitle: Text('Real version will include parental control and restricted content.'),
            trailing: Icon(Icons.child_care),
          ),
        ),

        const SizedBox(height: 14),

        OutlinedButton.icon(
          onPressed: () {
            AppSession.currentUser = null;
            AppSession.selectedCircle = null;

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
