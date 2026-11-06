import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/config/web_links_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/diagnostic_log_screen.dart';
import '../../profile/repository/profile_repository.dart';
import '../../profile/screens/appeal_screen.dart';
import '../widgets/settings_ui.dart';
import 'help_support_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

const _kTermsUrl = WebLinksConfig.termsUrl;
const _kPrivacyUrl = WebLinksConfig.privacyUrl;

class SettingsSupportScreen extends StatelessWidget {
  final VoidCallback? onDeleteAccount;

  const SettingsSupportScreen({super.key, this.onDeleteAccount});

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Help & legal',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: SettingsUi.screenPadding,
        children: [
          SettingsGroupCard(
            children: [
              SettingsNavTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ',
                subtitle: 'Answers to common questions',
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const HelpSupportScreen(initialTab: 0),
                    ),
                  );
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.support_agent_rounded,
                title: 'Contact support',
                subtitle: 'Reach the Bybata team',
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const HelpSupportScreen(initialTab: 1),
                    ),
                  );
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.gavel_rounded,
                title: 'Submit appeal',
                subtitle: 'Appeal an account restriction',
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const AppealScreen(),
                    ),
                  );
                },
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.article_rounded,
                title: 'Terms of service',
                subtitle: 'Terms and conditions',
                onTap: () => _launchUrl(context, _kTermsUrl),
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy policy',
                subtitle: 'How we handle your data',
                onTap: () => _launchUrl(context, _kPrivacyUrl),
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'Version ${AppConstants.appVersion}',
                onTap: () => _showAbout(context),
                onLongPress: kDebugMode ? () => _openDiagnostics(context) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        showSettingsSnack(context, 'Could not open link', success: false);
      }
    } catch (e) {
      if (context.mounted) {
        showSettingsSnack(context, 'Could not open link: $e', success: false);
      }
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: const Icon(Icons.swap_horiz, size: 48),
      children: [
        Text(AppConstants.appMission),
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.bug_report_outlined, size: 18),
            label: const Text('Open diagnostics log'),
            onPressed: () {
              Navigator.of(context).pop();
              _openDiagnostics(context);
            },
          ),
        ],
      ],
    );
  }

  void _openDiagnostics(BuildContext context) {
    GuardedNavigator.pushNamed(context, DiagnosticLogScreen.routeName);
  }
}

/// Delete account flow — shown from hub danger zone.
class SettingsDeleteAccountHandler {
  SettingsDeleteAccountHandler._();

  static void showDeleteDialog(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your profile, trades, karma, and messages. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmTypedDelete(context);
            },
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  static void _confirmTypedDelete(BuildContext context) {
    final ctrl = TextEditingController();
    final danger = Theme.of(context).colorScheme.error;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final ok = ctrl.text.trim() == 'DELETE';
          return AlertDialog(
            title: const Text('Type DELETE to confirm'),
            content: TextField(
              controller: ctrl,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setLocal(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: ok
                    ? () async {
                        Navigator.pop(dialogContext);
                        await _performDelete(context);
                      }
                    : null,
                style: FilledButton.styleFrom(backgroundColor: danger),
                child: const Text('Delete forever'),
              ),
            ],
          );
        },
      ),
    ).then((_) => ctrl.dispose());
  }

  static Future<void> _performDelete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BybataLoader(),
    );
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final client = ApiClient(baseUrl, storage);
      await ProfileRepository(client.dio).deleteAccount();
      if (!context.mounted) return;
      navigator.pop();
      await auth.signOut();
      if (!context.mounted) return;
      navigator.pop();
      AppRoutes.resetNavigationAfterSignOut();
    } on DioException catch (e) {
      if (context.mounted) navigator.pop();
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : e.message;
      if (context.mounted) {
        showSettingsSnack(context, msg ?? 'Could not delete account', success: false);
      }
    } catch (e) {
      if (context.mounted) navigator.pop();
      if (context.mounted) {
        showSettingsSnack(context, '$e', success: false);
      }
    }
  }
}
