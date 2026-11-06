import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/web_links_config.dart';
import '../navigation/app_routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_toast.dart';
import '../../features/donations/models/donation_models.dart';
import '../../features/donations/widgets/donation_bottom_sheet.dart';

/// Apple App Store Guideline 3.2.2(iv): peer campaign funding must not be
/// collected inside the iOS app unless BYBATA is a Benevity/Candid nonprofit.
///
/// Platform behavior:
/// - **iOS**: donations open the web support page (Safari).
/// - **Android**: in-app [DonationBottomSheet] + wallet BYC debit.
/// - **Web**: in-app (same as Android).
abstract final class CampaignSupportCompliance {
  /// When true, in-app BYC debits for campaigns are blocked on this platform.
  static bool get blocksInAppDonations {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String supportUrlFor(
    String campaignId, {
    BuildContext? context,
    Campaign? campaign,
    String? campaignTitle,
  }) {
    final id = campaignId.trim();
    String? token;
    String? email;
    String? name;
    if (context != null) {
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.isAuthenticated) {
          token = auth.authToken;
          email = auth.currentUser?.email;
          name = auth.currentUser?.displayName;
        }
      } catch (_) {}
    }
    return WebLinksConfig.campaignSupportLink(
      id,
      accessToken: token,
      email: email,
      displayName: name,
      title: campaign?.title ?? campaignTitle,
      raisedAmount: campaign?.raisedAmount,
      goalAmount: campaign?.goalAmount,
      storySnippet: campaign?.story,
    );
  }

  /// Feed / card primary CTA for campaign listings.
  static String feedCtaLabel() =>
      blocksInAppDonations ? 'SUPPORT' : 'Fund';

  /// Campaign detail primary action (non-owner).
  static String detailPrimaryLabel({required bool isAuthenticated}) {
    if (blocksInAppDonations) return 'Support on web';
    return isAuthenticated ? 'Donate now' : 'Sign in to donate';
  }

  /// Hub card footer label.
  static String hubDonateLabel() =>
      blocksInAppDonations ? 'SUPPORT' : 'Donate';

  /// Opens campaign support in the system browser (Safari / Chrome) so
  /// `bybata://` return links work reliably after donate / fund wallet.
  /// Falls back to in-app browser only if external launch fails.
  static Future<void> openWebSupport(
    BuildContext context, {
    required String campaignId,
    String? campaignTitle,
    Campaign? campaign,
  }) async {
    final id = campaignId.trim();
    if (id.isEmpty) {
      if (context.mounted) {
        AppToast.error(context, 'Campaign not found');
      }
      return;
    }

    final uri = Uri.parse(
      supportUrlFor(
        id,
        context: context,
        campaign: campaign,
        campaignTitle: campaignTitle ?? campaign?.title,
      ),
    );
    try {
      var launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      }
      if (!launched && context.mounted) {
        AppToast.error(context, 'Could not open support page');
      }
    } catch (_) {
      try {
        final fallback = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
        if (!fallback && context.mounted) {
          AppToast.error(context, 'Could not open support page');
        }
      } catch (__) {
        if (context.mounted) {
          AppToast.error(context, 'Could not open support page');
        }
      }
    }
  }

  /// Routes to in-app donation sheet (Android/web) or web support (iOS).
  static void handleSupportTap(
    BuildContext context, {
    required Campaign campaign,
    bool requireSignIn = true,
  }) {
    if (blocksInAppDonations) {
      openWebSupport(
        context,
        campaignId: campaign.id,
        campaign: campaign,
      );
      return;
    }

    if (requireSignIn && AppRoutes.requireSignIn(context)) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DonationBottomSheet(campaign: campaign),
    );
  }

  /// For feed cards that only have an id (no full [Campaign] model).
  static void handleSupportById(
    BuildContext context, {
    required String campaignId,
    String? campaignTitle,
    Campaign? campaign,
    bool requireSignIn = true,
  }) {
    if (campaign != null) {
      handleSupportTap(
        context,
        campaign: campaign,
        requireSignIn: requireSignIn,
      );
      return;
    }

    if (blocksInAppDonations) {
      openWebSupport(
        context,
        campaignId: campaignId,
        campaignTitle: campaignTitle,
      );
      return;
    }

    if (requireSignIn && AppRoutes.requireSignIn(context)) return;
    AppToast.show(
      context,
      'Open the campaign to donate',
    );
  }
}
