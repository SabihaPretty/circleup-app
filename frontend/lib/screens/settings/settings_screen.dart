import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/profile_photo_uploader.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool loading = true;
  bool saving = false;

  Map<String, dynamic> settings = {};

  bool twoStepEnabled = false;
  String preferredVerifyMode = 'email';

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      final result = await ApiService.get('/settings/${user['id']}');
      settings = Map<String, dynamic>.from(result['data'] ?? {});
      twoStepEnabled = settings['twoStepEnabled'] == true;
      preferredVerifyMode = settings['preferredVerifyMode'] ?? 'email';
    } catch (e) {
      showMessage('Settings load failed: $e');
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> saveSettings() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    setState(() => saving = true);

    try {
      final result = await ApiService.post('/settings/update', {
        'userId': user['id'],
        'twoStepEnabled': twoStepEnabled,
        'preferredVerifyMode': preferredVerifyMode,
      });

      settings = Map<String, dynamic>.from(result['data'] ?? {});
      showMessage(result['message'] ?? 'Settings updated.');
    } catch (e) {
      showMessage('Settings update failed: $e');
    }

    if (mounted) setState(() => saving = false);
  }

  void showChangePasswordSheet() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool changing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> changePassword() async {
              if (currentController.text.isEmpty) {
                showMessage('Current password is required.');
                return;
              }

              if (newController.text.length < 6) {
                showMessage('New password must be at least 6 characters.');
                return;
              }

              if (newController.text != confirmController.text) {
                showMessage('New password and confirm password do not match.');
                return;
              }

              setSheetState(() => changing = true);

              try {
                final result = await ApiService.post('/auth/password/change', {
                  'currentPassword': currentController.text,
                  'newPassword': newController.text,
                  'confirmPassword': confirmController.text,
                });

                if (!mounted) return;

                Navigator.pop(context);
                showMessage(result['message'] ?? 'Password changed successfully.');
              } catch (e) {
                showMessage('Change password failed: $e');
              }

              if (mounted) setSheetState(() => changing = false);
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const ProfilePhotoUploader(),
                    Text(
                      'Change Password',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 14),
                    passwordField(
                      controller: currentController,
                      label: 'Current Password',
                      icon: Icons.lock,
                    ),
                    const SizedBox(height: 12),
                    passwordField(
                      controller: newController,
                      label: 'New Password',
                      icon: Icons.lock_reset,
                    ),
                    const SizedBox(height: 12),
                    passwordField(
                      controller: confirmController,
                      label: 'Confirm New Password',
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: changing ? null : changePassword,
                      icon: changing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Update Password'),
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

  Widget passwordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xfff8fafc),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget modeChip(String value, String label, IconData icon) {
    return ChoiceChip(
      selected: preferredVerifyMode == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => setState(() => preferredVerifyMode = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = settings['email'];
    final phone = settings['phone'];
    final isEmailVerified = settings['isEmailVerified'] == true;
    final isPhoneVerified = settings['isPhoneVerified'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                const ProfilePhotoUploader(),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: AppTheme.darkGradient,
                  ),
                  child: const Row(
                    children: [
                const ProfilePhotoUploader(),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.settings, color: AppTheme.primary),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Account Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                const ProfilePhotoUploader(),
                      const Text(
                        'Security',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: twoStepEnabled,
                        onChanged: (value) => setState(() => twoStepEnabled = value),
                        title: const Text('Two-Step Verification'),
                        subtitle: const Text(
                          'Require a code when logging in from your email or phone.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Verification Method',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                const ProfilePhotoUploader(),
                          modeChip('email', 'Email', Icons.email),
                          modeChip('phone', 'Phone', Icons.phone),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Chip(
                        avatar: Icon(
                          isEmailVerified ? Icons.verified : Icons.warning,
                          color: isEmailVerified ? AppTheme.success : AppTheme.warning,
                        ),
                        label: Text(
                          email == null
                              ? 'No email'
                              : isEmailVerified
                                  ? 'Verified email: $email'
                                  : 'Email not verified',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        avatar: Icon(
                          isPhoneVerified ? Icons.verified : Icons.warning,
                          color: isPhoneVerified ? AppTheme.success : AppTheme.warning,
                        ),
                        label: Text(
                          phone == null
                              ? 'No phone'
                              : isPhoneVerified
                                  ? 'Verified phone: $phone'
                                  : 'Phone not verified',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: saving ? null : saveSettings,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save Settings'),
                      ),
                    ],
                  ),
                ),
                PremiumCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.lock_reset, color: AppTheme.primary),
                    ),
                    title: const Text(
                      'Change Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Update your current login password safely.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: showChangePasswordSheet,
                  ),
                ),
                const PremiumCard(
                  child: EmptyState(
                    icon: Icons.auto_awesome,
                    title: 'More controls coming next',
                    subtitle: 'Privacy, nickname display and call filter settings will be added step by step.',
                  ),
                ),
              ],
            ),
    );
  }
}

