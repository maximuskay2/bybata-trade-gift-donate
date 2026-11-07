import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../screens/search/search_screen.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../karma/navigation/karma_navigator.dart';
import '../../notifications/screens/notifications_screen_simple.dart';
import '../../settings/screens/help_support_screen.dart';
import '../../settings/screens/settings_loader_screen.dart';
import '../../wallet/navigation/wallet_navigator.dart';
import 'intent_module.dart';
import '../screens/discover_screen.dart';
import 'conversational_analytics.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Routes conversational intent selections to the correct surface.
class IntentNavigation {
  IntentNavigation._();

  static void go(BuildContext context, IntentSuggestion suggestion) {
    switch (suggestion.module) {
      case IntentModule.trade:
        if (suggestion.action == IntentAction.browse) {
          AppRoutes.navigateToTradeHub(context);
        } else {
          AppRoutes.navigateToCreateTrade(context);
        }
        break;
      case IntentModule.gift:
        if (suggestion.action == IntentAction.browse) {
          AppRoutes.navigateToGiftHub(context);
        } else {
          AppRoutes.navigateToCreateGift(context);
        }
        break;
      case IntentModule.donation:
        if (suggestion.action == IntentAction.browse) {
          AppRoutes.navigateToDonationsHub(context);
        } else {
          AppRoutes.navigateToCreateCampaign(context);
        }
        break;
      case IntentModule.wallet:
        if (AppRoutes.requireSignIn(context)) return;
        if (suggestion.action == IntentAction.browse) {
          GuardedNavigator.pushNamed(context, AppConstants.walletRoute);
        } else {
          WalletNavigator.toFundWallet(context);
        }
        break;
      case IntentModule.karma:
        if (AppRoutes.requireSignIn(context)) return;
        if (suggestion.action == IntentAction.browse) {
          KarmaNavigator.toKarmaHome(context);
        } else {
          KarmaNavigator.toEarnKarma(context);
        }
        break;
      case IntentModule.settings:
        if (AppRoutes.requireSignIn(context)) return;
        GuardedNavigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsLoaderScreen()),
        );
        break;
      case IntentModule.ads:
        if (AppRoutes.requireSignIn(context)) return;
        WalletNavigator.toPromotionCenter(context);
        break;
      case IntentModule.profile:
        if (AppRoutes.requireSignIn(context)) return;
        GuardedNavigator.pushNamed(context, AppConstants.profileRoute);
        break;
      case IntentModule.community:
        if (suggestion.action == IntentAction.browse) {
          GuardedNavigator.pushNamed(context, AppConstants.communityRoute);
        } else {
          if (AppRoutes.requireSignIn(context)) return;
          GuardedNavigator.pushNamed(
            context,
            AppConstants.createCommunityRoute,
          );
        }
        break;
      case IntentModule.messages:
        if (AppRoutes.requireSignIn(context)) return;
        GuardedNavigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatListScreen(showBackButton: true),
          ),
        );
        break;
      case IntentModule.notifications:
        if (AppRoutes.requireSignIn(context)) return;
        GuardedNavigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
      case IntentModule.discover:
        openAdvancedSearch(context);
        break;
      case IntentModule.support:
        HelpSupportScreen.open(context);
        break;
    }
  }

  static void openAdvancedSearch(BuildContext context) {
    ConversationalAnalytics.backupSearchOpened();
    GuardedNavigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  /// Full search screen with optional module category pre-selected.
  static void openSearchWithQuery(
    BuildContext context, {
    required String query,
    IntentModule? module,
  }) {
    ConversationalAnalytics.backupSearchOpened();
    GuardedNavigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialQuery: query,
          initialCategory: _categoryForModule(module),
        ),
      ),
    );
  }

  static String? _categoryForModule(IntentModule? module) {
    switch (module) {
      case IntentModule.trade:
        return 'Trades';
      case IntentModule.gift:
        return 'Gifts';
      case IntentModule.donation:
        return 'Donations';
      default:
        return null;
    }
  }

  static void openExplore(BuildContext context) {
    GuardedNavigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoverScreen()),
    );
  }

  static void openHelp(BuildContext context) {
    HelpSupportScreen.open(context);
  }
}
