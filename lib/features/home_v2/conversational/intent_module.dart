import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Core functional modules surfaced by the conversational home parser.
enum IntentModule {
  trade,
  gift,
  donation,
  wallet,
  karma,
  settings,
  ads,
  profile,
  community,
  messages,
  notifications,
  discover,
  support,
}

/// Whether the suggestion opens a module hub, create flow, or in-place feed search.
enum IntentAction {
  browse,
  create,
  searchFeed,
}

extension IntentModuleMeta on IntentModule {
  String get label {
    switch (this) {
      case IntentModule.trade:
        return 'Trade';
      case IntentModule.gift:
        return 'Gift';
      case IntentModule.donation:
        return 'Donate';
      case IntentModule.wallet:
        return 'Wallet';
      case IntentModule.karma:
        return 'KARMA';
      case IntentModule.settings:
        return 'Settings';
      case IntentModule.ads:
        return 'Promotions';
      case IntentModule.profile:
        return 'Profile';
      case IntentModule.community:
        return 'Community';
      case IntentModule.messages:
        return 'Messages';
      case IntentModule.notifications:
        return 'Notifications';
      case IntentModule.discover:
        return 'Discover';
      case IntentModule.support:
        return 'Help & Support';
    }
  }

  IconData get icon {
    switch (this) {
      case IntentModule.trade:
        return Icons.swap_horiz_rounded;
      case IntentModule.gift:
        return Icons.card_giftcard_rounded;
      case IntentModule.donation:
        return Icons.volunteer_activism_rounded;
      case IntentModule.wallet:
        return Icons.account_balance_wallet_rounded;
      case IntentModule.karma:
        return Icons.auto_awesome_rounded;
      case IntentModule.settings:
        return Icons.settings_rounded;
      case IntentModule.ads:
        return Icons.campaign_rounded;
      case IntentModule.profile:
        return Icons.person_rounded;
      case IntentModule.community:
        return Icons.groups_rounded;
      case IntentModule.messages:
        return Icons.chat_bubble_outline_rounded;
      case IntentModule.notifications:
        return Icons.notifications_none_rounded;
      case IntentModule.discover:
        return Icons.explore_rounded;
      case IntentModule.support:
        return Icons.support_agent_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case IntentModule.trade:
        return AppTheme.tradeColor;
      case IntentModule.gift:
        return AppTheme.giftColor;
      case IntentModule.donation:
        return AppTheme.donationColor;
      case IntentModule.wallet:
        return AppTheme.karmaColor;
      case IntentModule.karma:
        return AppTheme.karmaColor;
      case IntentModule.settings:
        return AppTheme.primaryColor;
      case IntentModule.ads:
        return AppTheme.giftColor;
      case IntentModule.profile:
        return AppTheme.primaryColor;
      case IntentModule.community:
        return AppTheme.communityColor;
      case IntentModule.messages:
        return AppTheme.communityColor;
      case IntentModule.notifications:
        return AppTheme.primaryColor;
      case IntentModule.discover:
        return AppTheme.tradeColor;
      case IntentModule.support:
        return AppTheme.primaryColor;
    }
  }

  /// Modules that expose both a browse hub and a create/action entry.
  bool get hasBrowseAndCreate {
    switch (this) {
      case IntentModule.trade:
      case IntentModule.gift:
      case IntentModule.donation:
      case IntentModule.wallet:
      case IntentModule.karma:
      case IntentModule.ads:
      case IntentModule.community:
        return true;
      case IntentModule.settings:
      case IntentModule.profile:
      case IntentModule.messages:
      case IntentModule.notifications:
      case IntentModule.discover:
      case IntentModule.support:
        return false;
    }
  }
}

class IntentSuggestion {
  final IntentModule module;
  final IntentAction action;
  final String matchedKeyword;

  const IntentSuggestion({
    required this.module,
    required this.action,
    required this.matchedKeyword,
  });

  String get title {
    if (action == IntentAction.searchFeed) {
      switch (module) {
        case IntentModule.trade:
          return 'Search trades nearby';
        case IntentModule.gift:
          return 'Search gifts nearby';
        case IntentModule.donation:
          return 'Search fundraisers nearby';
        case IntentModule.discover:
          return 'Search listings nearby';
        default:
          return 'Search in feed';
      }
    }
    switch (module) {
      case IntentModule.trade:
        return action == IntentAction.browse ? 'Trade Center' : 'Create Trade';
      case IntentModule.gift:
        return action == IntentAction.browse ? 'Gift Center' : 'Give a Gift';
      case IntentModule.donation:
        return action == IntentAction.browse
            ? 'Donations Center'
            : 'Create Campaign';
      case IntentModule.wallet:
        return action == IntentAction.browse ? 'Wallet' : 'Fund Wallet';
      case IntentModule.karma:
        return action == IntentAction.browse ? 'KARMA Hub' : 'Earn KARMA';
      case IntentModule.settings:
        return 'Settings';
      case IntentModule.ads:
        return action == IntentAction.browse
            ? 'Promotion Center'
            : 'Boost a Listing';
      case IntentModule.profile:
        return 'My Profile';
      case IntentModule.community:
        return action == IntentAction.browse
            ? 'Communities'
            : 'Create Community';
      case IntentModule.messages:
        return 'Messages';
      case IntentModule.notifications:
        return 'Notifications';
      case IntentModule.discover:
        return 'Search Bybata';
      case IntentModule.support:
        return 'Help & Support';
    }
  }

  String get subtitle {
    if (action == IntentAction.searchFeed) {
      return 'Open full search with your keywords';
    }
    switch (module) {
      case IntentModule.trade:
        return action == IntentAction.browse
            ? 'Browse listings and swap offers'
            : 'List something new to trade';
      case IntentModule.gift:
        return action == IntentAction.browse
            ? 'Browse gifts available near you'
            : 'Offer an item to someone for free';
      case IntentModule.donation:
        return action == IntentAction.browse
            ? 'Explore active campaigns'
            : 'Launch a new fundraising campaign';
      case IntentModule.wallet:
        return action == IntentAction.browse
            ? 'Check BYC balance and transactions'
            : 'Add BYC to your wallet';
      case IntentModule.karma:
        return action == IntentAction.browse
            ? 'View points, trust level, and history'
            : 'See ways to earn more KARMA';
      case IntentModule.settings:
        return 'Account, privacy, notifications, and more';
      case IntentModule.ads:
        return action == IntentAction.browse
            ? 'Manage ads and promotion boosts'
            : 'Promote a trade, gift, or campaign';
      case IntentModule.profile:
        return 'View and edit your public profile';
      case IntentModule.community:
        return action == IntentAction.browse
            ? 'Browse groups and local hubs'
            : 'Start a new community';
      case IntentModule.messages:
        return 'Open your conversations';
      case IntentModule.notifications:
        return 'See alerts and activity updates';
      case IntentModule.discover:
        return 'Find trades, gifts, and campaigns';
      case IntentModule.support:
        return 'FAQs, tickets, and contact support';
    }
  }

  IconData get icon {
    if (action == IntentAction.searchFeed) {
      return Icons.search_rounded;
    }
    if (action == IntentAction.create &&
        module.hasBrowseAndCreate) {
      return Icons.add_rounded;
    }
    return module.icon;
  }
}
