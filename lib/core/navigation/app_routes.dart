import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/app_messenger.dart';
import '../widgets/sign_in_required_dialog.dart';
import '../../features/profile/models/user_profile.dart';
import '../../features/settings/screens/settings_loader_screen.dart';
import '../../features/gifting/models/gift_models.dart' as gift_models;
import 'main_navigation.dart';
import '../../features/home_v2/screens/browse_home_screen_v2.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';
import '../motion/hub_stage_bus.dart';

/// Helper class for organized navigation throughout the app
class AppRoutes {
  // Private constructor to prevent instantiation
  AppRoutes._();
  
  /// Show login required dialog
  static void _showLoginRequired(
    BuildContext context, {
    String? title,
    String? message,
    String? highlight,
  }) {
    SignInRequiredDialog.show(
      context,
      title: title,
      message: message,
      highlight: highlight,
    );
  }

  /// Public entry point for the standard "Sign In Required" dialog.
  ///
  /// Use this from any widget that wants to gate a tap when the visitor is
  /// browsing logged-out (feed cards, campaign rails, drawer items, etc.).
  static void showLoginRequired(
    BuildContext context, {
    String? title,
    String? message,
    String? highlight,
  }) =>
      _showLoginRequired(
        context,
        title: title,
        message: message,
        highlight: highlight,
      );

  /// Convenience: returns true and shows the dialog if the user is NOT
  /// authenticated. Returns false (no side effect) if the user IS
  /// authenticated. Lets call sites short-circuit with a single line:
  ///
  /// ```dart
  /// if (AppRoutes.requireSignIn(context)) return;
  /// // ... proceed with the protected action ...
  /// ```
  static bool requireSignIn(
    BuildContext context, {
    String? title,
    String? message,
    String? highlight,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) return false;
    _showLoginRequired(
      context,
      title: title,
      message: message,
      highlight: highlight,
    );
    return true;
  }

  /// Sign out and return to the guest browse root ([RootRouter] → browse home).
  static Future<void> completeSignOut(BuildContext context) async {
    resetNavigationAfterSignOut();
    Provider.of<NotificationProvider>(context, listen: false)
        .clearSessionOnSignOut();
    await Provider.of<AuthProvider>(context, listen: false).signOut();
  }

  /// Wallet — requires sign-in.
  static void navigateToWallet(BuildContext context) {
    if (requireSignIn(
      context,
      title: 'Sign in to view your wallet',
      message:
          'Sign in or create a free account to manage BYC, karma, and donations.',
      highlight: 'Your wallet unlocks after you sign in.',
    )) {
      return;
    }
    GuardedNavigator.pushNamed(context, AppConstants.walletRoute);
  }

  /// Promotions center — requires sign-in.
  static void navigateToPromotions(BuildContext context) {
    if (requireSignIn(
      context,
      title: 'Sign in for promotions',
      message:
          'Sign in or create a free account to boost listings and manage ads.',
      highlight: 'Promotions are available to signed-in members.',
    )) {
      return;
    }
    GuardedNavigator.pushNamed(context, '/wallet/promotions');
  }

  /// Pops all pushed routes so [RootRouter] can show the guest browse home.
  static void resetNavigationAfterSignOut() {
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// Navigate to the home screen (authenticated → main shell home tab, guest → browse home).
  static void navigateToHome(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final navigator = appNavigatorKey.currentState ?? Navigator.of(context);

    if (auth.isAuthenticated) {
      GuardedNavigator.pushAndRemoveUntil(context, 
        MaterialPageRoute(
          builder: (_) => const MainNavigation(initialScreen: 'home'),
        ),
        (route) => false,
      );
      return;
    }

    GuardedNavigator.pushAndRemoveUntil(context, 
      MaterialPageRoute(builder: (_) => const BrowseHomeScreenV2()),
      (route) => false,
    );
  }
  
  /// Navigate to Create Trade Screen
  static void navigateToCreateTrade(BuildContext context, {String? routeOverride}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }
    GuardedNavigator.pushNamed(context, routeOverride ?? AppConstants.createTradeRoute);
  }
  
  /// Navigate to My Trades Screen
  static void navigateToMyTrades(BuildContext context) {
    GuardedNavigator.pushNamed(context, '/my-trades');
  }
  
  /// Navigate to Trade Offers Screen
  static void navigateToTradeOffers(BuildContext context) {
    GuardedNavigator.pushNamed(context, '/trade-offers');
  }
  
  /// Navigate to Trade Details Screen with trade data
  static void navigateToTradeDetails(BuildContext context, dynamic trade) {
    GuardedNavigator.pushNamed(context, 
      '/trade-details',
      arguments: trade,
    );
  }

  /// Navigate to Trade Details by id (uses [TradeDetailsLoader]).
  static void navigateToTradeDetailsById(BuildContext context, String tradeId) {
    if (HubStageBus.tryOpen(HubStageBus.trade, tradeId)) return;
    GuardedNavigator.pushNamed(context,
      AppConstants.tradeDetailsRoute,
      arguments: {'id': tradeId},
    );
  }
  
  /// Navigate to Edit Trade Screen with trade data
  static void navigateToEditTrade(BuildContext context, dynamic trade) {
    GuardedNavigator.pushNamed(context, 
      '/edit-trade',
      arguments: trade,
    );
  }
  
  /// Navigate to Negotiation Screen with required parameters
  static void navigateToNegotiation(
    BuildContext context, {
    required dynamic targetTrade,
    required List<dynamic> userTrades,
  }) {
    if (requireSignIn(context)) return;
    GuardedNavigator.pushNamed(context, 
      '/negotiation',
      arguments: {
        'targetTrade': targetTrade,
        'userTrades': userTrades,
      },
    );
  }
  
  /// Navigate to Trade Offers Screen with specific trade filter
  static void navigateToTradeOffersFiltered(
    BuildContext context, 
    dynamic selectedTrade,
  ) {
    GuardedNavigator.pushNamed(context, 
      '/trade-offers-filtered',
      arguments: selectedTrade,
    );
  }
  
  /// Generic navigation method for future features
  static void navigateToFeature(BuildContext context, String routeName, {
    Object? arguments,
    String? comingSoonMessage,
  }) {
    if (comingSoonMessage != null) {
      AppToast.show(context, comingSoonMessage);
      return;
    }
    
    GuardedNavigator.pushNamed(context, routeName, arguments: arguments);
  }
  
  /// Navigate to Create Gift Screen
  static void navigateToCreateGift(BuildContext context, {String? chainParentId}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }
    GuardedNavigator.pushNamed(context,
      AppConstants.createGiftRoute,
      arguments: chainParentId != null ? {'chainParentId': chainParentId} : null,
    );
  }
  
  /// Navigate to My Gifts Screen
  static void navigateToMyGifts(BuildContext context) {
    GuardedNavigator.pushNamed(context, AppConstants.myGiftsRoute);
  }
  
  /// Navigate to Gift History Screen
  static void navigateToGiftHistory(BuildContext context) {
    GuardedNavigator.pushNamed(context, AppConstants.giftHistoryRoute);
  }
  
  /// Navigate to Gift Details Screen with real Gift model
  static void navigateToGiftDetails(BuildContext context, gift_models.Gift gift) {
    GuardedNavigator.pushNamed(context,
      AppConstants.giftDetailsRoute,
      arguments: giftToLegacyMap(gift),
    );
  }

  /// Navigate to Gift Details by id (uses [GiftDetailsLoader]).
  static void navigateToGiftDetailsById(BuildContext context, String giftId) {
    if (HubStageBus.tryOpen(HubStageBus.gift, giftId)) return;
    GuardedNavigator.pushNamed(context,
      AppConstants.giftDetailsRoute,
      arguments: {'id': giftId},
    );
  }
  
  /// Navigate to Edit Gift Screen with real Gift model
  static void navigateToEditGift(BuildContext context, gift_models.Gift gift) {
    GuardedNavigator.pushNamed(context,
      AppConstants.editGiftRoute,
      arguments: gift,
    );
  }

  /// Navigate to Claim Gift Screen with real Gift model
  static void navigateToClaimGift(BuildContext context, gift_models.Gift gift) {
    GuardedNavigator.pushNamed(context,
      AppConstants.claimGiftRoute,
      arguments: giftToLegacyMap(gift),
    );
  }

  /// Navigate to Campaign Details by id (uses [CampaignDetailsLoader]).
  static void navigateToCampaignDetailsById(
    BuildContext context,
    String campaignId,
  ) {
    if (HubStageBus.tryOpen(HubStageBus.donate, campaignId)) return;
    GuardedNavigator.pushNamed(context,
      AppConstants.campaignDetailsRoute,
      arguments: {'id': campaignId},
    );
  }

  /// Convert Gift model to legacy Map used by [GiftDetailsScreen].
  static Map<String, dynamic> giftToLegacyMap(gift_models.Gift gift) {
    return {
      'id': gift.id,
      'title': gift.title,
      'description': gift.description,
      'giver': gift.giver.name,
      'giverId': gift.giver.id,
      'color': gift.category.color,
      'icon': gift.category.icon,
      'karma': gift.karmaReward,
      'location': gift.location,
      'tags': gift.tags,
      'type': gift.type.name,
      'category': gift.category.name,
      'expires': gift.expiresAt != null ? gift.timeRemaining : null,
      'claimed': gift.status == gift_models.GiftStatus.claimed ||
          gift.status == gift_models.GiftStatus.completed,
      'mediaKeys': gift.imageUrls,
      'mediaType': gift.mediaType,
      'videoKey': gift.videoKey,
      'thumbnailKey': gift.thumbnailKey,
      'giverAvatarKey': gift.giver.profileImageUrl,
    };
  }

  /// Navigate to Create Campaign Screen
  static void navigateToCreateCampaign(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }
    GuardedNavigator.pushNamed(context, AppConstants.createCampaignRoute);
  }
  
  /// Navigate to Campaign Details Screen with campaign data
  static void navigateToCampaignDetails(BuildContext context, dynamic campaign) {
    GuardedNavigator.pushNamed(context, 
      AppConstants.campaignDetailsRoute,
      arguments: campaign,
    );
  }
  
  /// Navigate to My Campaigns Screen
  static void navigateToMyCampaigns(BuildContext context) {
    GuardedNavigator.pushNamed(context, AppConstants.myCampaignsRoute);
  }
  
  /// Navigate to Donation History Screen
  static void navigateToDonationHistory(BuildContext context) {
    GuardedNavigator.pushNamed(context, AppConstants.donationHistoryRoute);
  }

  /// Donations hub — optional tab (0 browse, 1 my campaigns, 2 requests, 3 history).
  static void navigateToDonationsHub(
    BuildContext context, {
    int tabIndex = 0,
    String? stageFocusId,
  }) {
    GuardedNavigator.pushNamed(context,
      AppConstants.donationsRoute,
      arguments: {
        'initialTabIndex': tabIndex.clamp(0, 3),
        if (stageFocusId != null && stageFocusId.isNotEmpty)
          'stageFocusId': stageFocusId,
      },
    );
  }

  /// After creating a listing, replace the create screen with the trade hub.
  static void replaceWithTradeHub(BuildContext context) {
    GuardedNavigator.pushReplacementNamed(context, AppConstants.tradeRoute);
  }

  /// Trade hub — tab 0 browse, 1 mine, 2 draft, 3 offers, 4 history.
  static void navigateToTradeHub(
    BuildContext context, {
    int tabIndex = 0,
    String? highlightOfferId,
    String? highlightTradeId,
    String? stageFocusId,
  }) {
    GuardedNavigator.pushNamed(context,
      AppConstants.tradeRoute,
      arguments: {
        'initialTabIndex': tabIndex.clamp(0, 4),
        if (highlightOfferId != null && highlightOfferId.isNotEmpty)
          'highlightOfferId': highlightOfferId,
        if (highlightTradeId != null && highlightTradeId.isNotEmpty)
          'highlightTradeId': highlightTradeId,
        if (stageFocusId != null && stageFocusId.isNotEmpty)
          'stageFocusId': stageFocusId,
      },
    );
  }

  /// After creating a listing, replace the create screen with the gift hub.
  static void replaceWithGiftHub(BuildContext context, {String? createdGiftId}) {
    GuardedNavigator.pushReplacementNamed(context, 
      AppConstants.giftingRoute,
      arguments: {
        'refresh': true,
        if (createdGiftId != null && createdGiftId.isNotEmpty)
          'createdGiftId': createdGiftId,
      },
    );
  }

  /// Gift hub — tab 0 browse, 1 my gifts, 2 requests, 3 history.
  static void navigateToGiftHub(
    BuildContext context, {
    int tabIndex = 0,
    String? highlightRequestId,
    String? highlightGiftId,
    String? stageFocusId,
  }) {
    GuardedNavigator.pushNamed(context,
      AppConstants.giftingRoute,
      arguments: {
        'initialTabIndex': tabIndex.clamp(0, 3),
        if (highlightRequestId != null && highlightRequestId.isNotEmpty)
          'highlightRequestId': highlightRequestId,
        if (highlightGiftId != null && highlightGiftId.isNotEmpty)
          'highlightGiftId': highlightGiftId,
        if (stageFocusId != null && stageFocusId.isNotEmpty)
          'stageFocusId': stageFocusId,
      },
    );
  }

  /// After creating a campaign, replace the create screen with the donations hub.
  static void replaceWithDonationsHub(BuildContext context, {int tabIndex = 0}) {
    GuardedNavigator.pushReplacementNamed(context, 
      AppConstants.donationsRoute,
      arguments: {'initialTabIndex': tabIndex.clamp(0, 3)},
    );
  }

  /// Navigate to the Ask-for-Help / community request composer.
  /// Gated behind auth because posting a request writes to the user's profile.
  static void navigateToAskForHelp(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }
    GuardedNavigator.pushNamed(context, '/create-request');
  }

  /// Navigate to Campaign Management Screen with campaign data
  static void navigateToCampaignManagement(BuildContext context, dynamic campaign) {
    GuardedNavigator.pushNamed(context, 
      AppConstants.campaignManagementRoute,
      arguments: campaign,
    );
  }

  static void navigateToEditCampaign(BuildContext context, dynamic campaign) {
    GuardedNavigator.pushNamed(context,
      AppConstants.createCampaignRoute,
      arguments: campaign,
    );
  }

  /// Navigate to Create Community Screen
  static void navigateToCreateCommunity(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }
    GuardedNavigator.pushNamed(context, AppConstants.createCommunityRoute);
  }
  
  /// Navigate to Community Details Screen with community data
  static void navigateToCommunityDetails(BuildContext context, dynamic community) {
    GuardedNavigator.pushNamed(context, 
      AppConstants.communityDetailsRoute,
      arguments: community,
    );
  }
  
  /// Navigate to Community Posts Screen
  static void navigateToCommunityPosts(BuildContext context, dynamic community) {
    GuardedNavigator.pushNamed(context, 
      AppConstants.communityPostsRoute,
      arguments: community,
    );
  }
  
  /// Navigate to Create Post Screen
  static void navigateToCreatePost(BuildContext context, dynamic community) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }
    GuardedNavigator.pushNamed(context, 
      AppConstants.createPostRoute,
      arguments: community,
    );
  }
  
  /// Navigate to Events Screen
  static void navigateToEvents(BuildContext context, dynamic community) {
    GuardedNavigator.pushNamed(context, 
      AppConstants.eventsRoute,
      arguments: community,
    );
  }
  
  /// Navigate to Members Screen
  static void navigateToMembers(BuildContext context, dynamic community) {
    GuardedNavigator.pushNamed(context, 
      AppConstants.membersRoute,
      arguments: community,
    );
  }

  /// Navigate to Edit Profile Screen
  /// Uses the main profile edit route wired in `main.dart`.
  static void navigateToEditProfile(BuildContext context, {dynamic userProfile}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }
    GuardedNavigator.pushNamed(context,
      '/profile/edit',
      arguments: userProfile,
    );
  }

  /// Navigate to Activity History Screen
  static void navigateToActivityHistory(BuildContext context) {
    GuardedNavigator.pushNamed(context, '/activity-history');
  }

  /// Navigate to Verification Screen
  static void navigateToVerification(BuildContext context, {dynamic userProfile}) {
    GuardedNavigator.pushNamed(context,
      '/verification',
      arguments: userProfile,
    );
  }

  /// Navigate to Settings Screen
  static void navigateToSettings(BuildContext context, {UserProfile? userProfile}) {
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (context) => SettingsLoaderScreen(initialProfile: userProfile),
      ),
    ).then((result) {
      if (result is UserProfile && context.mounted) {
        // Caller may refresh profile if needed.
      }
    });
  }

  /// Navigate to Achievements Screen
  static void navigateToAchievements(BuildContext context) {
    GuardedNavigator.pushNamed(context, '/achievements');
  }

  /// Navigate to Profile Screen with user data
  static void navigateToProfile(BuildContext context, {dynamic userId}) {
    GuardedNavigator.pushNamed(context,
      '/profile',
      arguments: userId,
    );
  }

  /// Navigate to Notifications Screen
  static void navigateToNotifications(BuildContext context) {
    if (requireSignIn(
      context,
      title: 'Sign in to view notifications',
      message:
          'Sign in or create a free account to see alerts for trades, gifts, and campaigns.',
      highlight: 'Your notification inbox is available after you sign in.',
    )) {
      return;
    }
    GuardedNavigator.pushNamed(context, '/notifications');
  }

  /// Show coming soon message for features not yet implemented
  static void showComingSoon(BuildContext context, String featureName) {
    AppToast.show(context, '$featureName - Coming soon!');
  }
}
