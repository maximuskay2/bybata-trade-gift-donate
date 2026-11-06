import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/repository/profile_repository.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/verification_screen.dart';
import '../widgets/settings_ui.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class SettingsAccountScreen extends StatelessWidget {
  final UserProfile userProfile;
  final ValueChanged<UserProfile>? onProfileUpdated;

  const SettingsAccountScreen({
    super.key,
    required this.userProfile,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Account',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: SettingsUi.screenPadding,
        children: [
          SettingsGroupCard(
            children: [
              SettingsNavTile(
                icon: Icons.person_rounded,
                title: 'Personal information',
                subtitle: 'Name, bio, avatar, and contact details',
                onTap: () async {
                  final changed = await GuardedNavigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        userProfile: userProfile,
                      ),
                    ),
                  );
                  if (changed == true && context.mounted) {
                    showSettingsSnack(context, 'Profile updated');
                    onProfileUpdated?.call(userProfile);
                  }
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.verified_user_rounded,
                title: 'Account verification',
                subtitle: 'Verify your identity and contact info',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (userProfile.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ],
                ),
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) =>
                          VerificationScreen(userProfile: userProfile),
                    ),
                  );
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.lock_rounded,
                title: 'Change password',
                subtitle: 'Update the password for your account',
                onTap: () => _showChangePasswordDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final cur = currentCtrl.text;
                      final nw = newCtrl.text;
                      final cf = confirmCtrl.text;
                      if (cur.isEmpty || nw.isEmpty) {
                        AppToast.warning(context, 'Fill all fields');
                        return;
                      }
                      if (nw.length < 8) {
                        AppToast.warning(
                          context,
                          'New password must be at least 8 characters',
                        );
                        return;
                      }
                      if (nw != cf) {
                        AppToast.warning(context, 'New passwords do not match');
                        return;
                      }
                      setLocal(() => submitting = true);
                      try {
                        final baseUrl = await EnvConfig.getBaseUrl();
                        const storage = FlutterSecureStorage();
                        final client = ApiClient(baseUrl, storage);
                        await ProfileRepository(client.dio)
                            .changePassword(cur, nw);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        showSettingsSnack(context, 'Password updated');
                      } on DioException catch (e) {
                        final msg = e.response?.data is Map
                            ? (e.response!.data as Map)['message']?.toString()
                            : e.message;
                        AppToast.error(context, msg ?? 'Could not change password');
                      } catch (e) {
                        AppToast.error(context, '$e');
                      } finally {
                        setLocal(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    ).then((_) {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    });
  }
}
