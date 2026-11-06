import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../profile/repository/profile_repository.dart';
import '../../wallet/screens/wallet_pin_management_screen.dart';
import '../widgets/settings_ui.dart';
import 'active_sessions_screen.dart';
import 'blocked_users_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class SettingsSecurityScreen extends StatelessWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Security & data',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: SettingsUi.screenPadding,
        children: [
          SettingsGroupCard(
            children: [
              SettingsNavTile(
                icon: Icons.pin_rounded,
                title: 'Wallet PIN',
                subtitle: 'Protect wallet actions with a PIN',
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const WalletPinManagementScreen(),
                    ),
                  );
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.devices_rounded,
                title: 'Active sessions',
                subtitle: 'See where you are signed in',
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const ActiveSessionsScreen(),
                    ),
                  );
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.block_rounded,
                title: 'Blocked users',
                subtitle: 'Manage who cannot reach you',
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen(),
                    ),
                  );
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.download_rounded,
                title: 'Download my data',
                subtitle: 'Request a copy of your information',
                onTap: () => _requestDataExport(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _requestDataExport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Download your data'),
        content: const Text(
          'We will prepare your data and email you a download link. This may take up to 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final baseUrl = await EnvConfig.getBaseUrl();
                const storage = FlutterSecureStorage();
                final client = ApiClient(baseUrl, storage);
                await ProfileRepository(client.dio).requestDataExport();
                if (context.mounted) {
                  showSettingsSnack(
                    context,
                    'Request submitted. Check your email when ready.',
                  );
                }
              } on DioException catch (e) {
                final msg = e.response?.data is Map
                    ? (e.response!.data as Map)['message']?.toString()
                    : e.message;
                if (context.mounted) {
                  showSettingsSnack(context, msg ?? 'Request failed', success: false);
                }
              } catch (e) {
                if (context.mounted) {
                  showSettingsSnack(context, '$e', success: false);
                }
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}
