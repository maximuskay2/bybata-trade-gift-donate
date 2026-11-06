import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/navigation/main_navigation.dart';
import 'core/navigation/route_observer.dart';
import 'features/karma/services/karma_service.dart';
import 'features/karma/providers/karma_provider.dart';
import 'features/karma/screens/karma_screen.dart';
import 'features/karma/screens/karma_leaderboard_screen.dart';
import 'features/karma/screens/achievements_screen.dart';
import 'features/karma/screens/karma_history_screen.dart';
import 'features/karma/screens/trust_level_screen.dart';
import 'features/karma/screens/earn_karma_guide_screen.dart';
import 'features/karma/test_karma_integration.dart';
import 'features/karma/models/karma_models.dart' as karma_models;
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_modern_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/email_verification_screen.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/trade/screens/create_trade_screen.dart';
import 'features/trade/screens/edit_trade_screen.dart';
import 'features/trade/screens/my_trades_screen.dart';
import 'features/trade/screens/trade_screen.dart';
import 'features/trade/screens/trade_details_screen.dart';
import 'features/trade/screens/trade_details_loader.dart';
import 'features/trade/screens/trade_offers_screen.dart';
import 'features/trade/screens/negotiation_screen.dart';
import 'features/trade/models/trade_models.dart' as trade_models;
import 'features/trade/providers/trade_backend_provider.dart';
import 'features/gifting/screens/create_gift_screen.dart';
import 'features/gifting/screens/gifting_screen.dart';
import 'features/gifting/screens/gift_details_screen.dart';
import 'features/gifting/screens/claim_gift_screen.dart';
import 'features/gifting/screens/my_gifts_screen.dart';
import 'features/gifting/screens/gift_history_screen.dart';
import 'features/gifting/models/gift_models.dart' as gift_models;
import 'features/donations/screens/create_campaign_screen.dart';
import 'features/donations/screens/donations_screen.dart';
import 'features/donations/screens/my_campaigns_screen.dart';
import 'features/donations/screens/donation_history_screen.dart';
import 'features/donations/screens/campaign_management_screen.dart';
import 'features/donations/screens/campaign_details_screen.dart';
import 'features/donations/models/donation_models.dart';
import 'screens/coming_soon_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/activity_history_screen.dart';
import 'features/profile/screens/verification_screen.dart';
import 'features/settings/screens/enhanced_settings_screen.dart';
import 'features/profile/screens/achievements_screen.dart'
    as profile_achievements;
import 'package:bybata/core/navigation/guarded_navigator.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/user_profile_screen.dart';
import 'features/profile/models/user_profile.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/search/providers/search_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'screens/search/search_screen.dart';
import 'features/search/screens/search_results_screen.dart';
import 'features/notifications/screens/notifications_screen_simple.dart';
import 'features/notifications/widgets/notification_initializer.dart';
import 'core/providers/notification_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/navigation/app_routes.dart';
import 'features/settings/screens/settings_loader_screen.dart';
import 'features/settings/screens/help_support_screen.dart';
import 'features/wallet/screens/wallet_screen.dart';
import 'features/wallet/screens/promotion_center_screen.dart';
import 'features/wallet/screens/create_ad_screen.dart';
import 'core/widgets/auth_gate.dart';
import 'features/gifting/providers/gift_provider.dart';
import 'features/donations/providers/campaign_provider.dart';
import 'providers/feed_provider.dart';
import 'features/donations/models/donation_models.dart' as donations;
import 'models/feed_item.dart';
import 'screens/request_details_screen.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/models/chat_conversation.dart';
import 'core/providers/wallet_provider.dart';
import 'core/api/api_client.dart';
import 'core/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'core/utils/app_messenger.dart';
import 'features/notifications/services/push_notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/gifting/screens/gift_details_loader.dart';
import 'features/donations/widgets/donation_success_dialog.dart';
import 'features/donations/screens/campaign_details_loader.dart';
import 'features/community/services/community_api_service.dart';
import 'core/errors/global_error_handler.dart';
import 'core/utils/diagnostic_log_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home_v2/screens/browse_home_screen_v2.dart';
import 'features/home_v2/conversational/conversational_feed_refresh.dart';
import 'screens/splash/animated_splash_screen.dart';
import 'screens/splash/startup_network_overlay.dart';
import 'core/utils/network_utils.dart';
import 'core/utils/network_error_message.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'core/utils/donation_karma_utils.dart';
import 'core/utils/media_utils.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await MediaResolver.warmBaseUrl();

    // Decode splash logo before heavy init so the first Flutter frame is branded.
    try {
      await rootBundle.load('assets/animations/logo.png');
    } catch (_) {}

    // Initialize Firebase first (required for FCM / in-app notifications)
    await Firebase.initializeApp();

    // Explicitly turn on Crashlytics collection so release/profile builds
    // ship every recordError() call + native crash to the Firebase console.
    // In debug builds we still call recordError from AppLogger but Firebase
    // ignores them by default — that's fine.
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      // Boot breadcrumb: if we ever see this in a crash report it confirms
      // Crashlytics wiring is alive end-to-end.
      await FirebaseCrashlytics.instance.log(
        'App boot: mode=${kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug')}',
      );
    } catch (e, s) {
      // Never let Crashlytics setup itself crash the app.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Crashlytics] setup failed: $e\n$s');
      }
    }

    // Initialize Hive for lightweight local caches (profile, chat, hubs).
    await Hive.initFlutter();
    await Hive.openBox<String>('user_profile_cache');
    await Hive.openBox<String>('chat_cache');
    await Hive.openBox<String>('wallet_cache');
    await Hive.openBox<String>('notifications_cache');
    await Hive.openBox<String>('gifts_cache');
    await Hive.openBox<String>('campaigns_cache');
    await Hive.openBox<String>('trades_cache');

    try {
      await PushNotificationsService.initialize().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } catch (_) {}

    final themeProvider = ThemeProvider();
    await themeProvider.initializeTheme();

    final notificationProvider = NotificationProvider();

    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (kDebugMode) {
        return ErrorWidget(details.exception);
      }
      return GlobalErrorHandler.buildBrokenSubtreePlaceholder(details);
    };

    FlutterError.onError = GlobalErrorHandler.handleFlutterError;

    PlatformDispatcher.instance.onError = (error, stack) {
      GlobalErrorHandler.handleZoneError(error, stack);
      return true;
    };

    runApp(
      MyApp(
        themeProvider: themeProvider,
        notificationProvider: notificationProvider,
      ),
    );
  }, (error, stack) {
    GlobalErrorHandler.handleZoneError(error, stack);
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
    // Always forward print() output. In debug we keep the parent print so the
    // line shows in `flutter run` exactly as today. In profile/release we
    // also forward it via dart:developer.log so it reaches os_log →
    // Console.app / idevicesyslog (regular print is otherwise dropped).
    if (kDebugMode) {
      parent.print(zone, line);
    } else {
      developer.log(line, name: 'Bybata.print');
    }
  }));
}

/// Entry surface of the app.
///
/// We no longer gate on a fixed-duration splash timer. Instead, the splash
/// widget is rendered directly by [RootRouter] whenever it is still deciding
/// which surface to show (auth loading, onboarding flag loading). This keeps
/// the "BYBATA · Trade. Gift. Donate and Grow Together" text visible from
/// the first frame all the way up to the moment the real destination is
/// ready — no artificial 2.5s delay, no flicker between the native launch
/// screen and the Flutter splash.
class _SplashWrapper extends StatelessWidget {
  const _SplashWrapper();

  @override
  Widget build(BuildContext context) => const RootRouter();
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final NotificationProvider notificationProvider;

  const MyApp({
    super.key,
    required this.themeProvider,
    required this.notificationProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => KarmaProvider()),
        // Provide the singleton KarmaService app-wide so screens can use context.read/watch
        ChangeNotifierProvider.value(value: KarmaService()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final ap = AuthProvider();
            ap.initializeAuth();
            return ap;
          },
        ),
        ChangeNotifierProvider(create: (_) => TradeBackendProvider()),
        ChangeNotifierProvider(
          create: (_) {
            const storage = FlutterSecureStorage();
            final apiClient = ApiClient(EnvConfig.defaultBaseUrl, storage);
            return GiftProvider(apiClient);
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            const storage = FlutterSecureStorage();
            final apiClient = ApiClient(EnvConfig.defaultBaseUrl, storage);
            return CampaignProvider(apiClient);
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            const storage = FlutterSecureStorage();
            final apiClient = ApiClient(EnvConfig.defaultBaseUrl, storage);
            return FeedProvider(apiClient);
          },
        ),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (context) {
            const storage = FlutterSecureStorage();
            final apiClient = ApiClient(EnvConfig.defaultBaseUrl, storage);
            return ChatProvider(context.read<AuthProvider>(), apiClient);
          },
          update: (context, authProvider, previous) {
            if (previous != null) return previous;
            const storage = FlutterSecureStorage();
            final apiClient = ApiClient(EnvConfig.defaultBaseUrl, storage);
            return ChatProvider(authProvider, apiClient);
          },
        ),
      ],
      child: NotificationInitializer(
        child: _PreloadActiveCampaigns(
          child: _DeepLinkHandler(
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return MaterialApp(
                  title: 'Bybata',
                  theme: themeProvider.lightTheme,
                  darkTheme: themeProvider.darkTheme,
                  themeMode: themeProvider.themeMode,
                  debugShowCheckedModeBanner: false,
                  // GLOBAL STATUS BAR CONTRAST FIX FOR GLASS UI.
                  // Every route is wrapped in an AnnotatedRegion that forces the
                  // native status-bar / nav-bar icon colours to contrast with
                  // the current theme brightness, so the time/battery/signal
                  // icons always stay legible on top of the glass/backdrop
                  // blur at the very top edge (where `extendBodyBehindAppBar:
                  // true` lets screen content slide under the notch).
                  //
                  //   - Dark theme  -> light icons (white time / battery)
                  //   - Light theme -> dark  icons (black time / battery)
                  //
                  // Individual AppBars may still override `systemOverlayStyle`
                  // locally if a particular glass layer needs the opposite
                  // contrast (rare).
                  builder: (context, child) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final overlay = isDark
                        ? SystemUiOverlayStyle.light.copyWith(
                            statusBarColor: Colors.transparent,
                            systemNavigationBarColor: Colors.transparent,
                            systemNavigationBarIconBrightness: Brightness.light,
                          )
                        : SystemUiOverlayStyle.dark.copyWith(
                            statusBarColor: Colors.transparent,
                            systemNavigationBarColor: Colors.transparent,
                            systemNavigationBarIconBrightness: Brightness.dark,
                          );
                    return AnnotatedRegion<SystemUiOverlayStyle>(
                      value: overlay,
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                  home: const _SplashWrapper(),
                  navigatorKey: appNavigatorKey,
                  navigatorObservers: [
                    appRouteObserver,
                    NavigationTapGuardObserver(),
                  ],
                  routes: {
                  '/main': (context) => const MainNavigation(),
                  if (kDebugMode)
                    DiagnosticLogScreen.routeName: (context) =>
                        const DiagnosticLogScreen(),
                  // Main feature routes
                  AppConstants.tradeRoute: (context) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    final tabIndex = args is Map
                        ? (args['initialTabIndex'] as int?) ?? 0
                        : 0;
                    final highlightOfferId = args is Map
                        ? args['highlightOfferId'] as String?
                        : null;
                    final highlightTradeId = args is Map
                        ? args['highlightTradeId'] as String?
                        : null;
                    return TradeScreen(
                      initialTabIndex: tabIndex,
                      highlightOfferId: highlightOfferId,
                      highlightTradeId: highlightTradeId,
                    );
                  },
                  AppConstants.giftingRoute: (context) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    final tabIndex = args is Map
                        ? (args['initialTabIndex'] as int?) ?? 0
                        : 0;
                    final highlightRequestId = args is Map
                        ? args['highlightRequestId'] as String?
                        : null;
                    final highlightGiftId = args is Map
                        ? args['highlightGiftId'] as String?
                        : null;
                    return GiftingScreen(
                      initialTabIndex: tabIndex,
                      highlightRequestId: highlightRequestId,
                      highlightGiftId: highlightGiftId,
                    );
                  },
                  AppConstants.donationsRoute: (context) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    final tabIndex = args is Map
                        ? (args['initialTabIndex'] as int?) ?? 0
                        : 0;
                    return DonationsScreen(initialTabIndex: tabIndex);
                  },
                  // KARMA routes
                  '/karma': (context) => const KarmaScreen(),
                  '/karma/leaderboard': (context) =>
                      const KarmaLeaderboardScreen(),
                  '/karma/achievements': (context) =>
                      const AchievementsScreen(),
                  '/karma/history': (context) => const KarmaHistoryScreen(),
                  '/karma/trust-level': (context) => const TrustLevelScreen(),
                  '/karma/earn': (context) => const EarnKarmaGuideScreen(),
                  '/karma/test': (context) => const TestKarmaIntegration(),
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegisterModernScreen(),
                  '/forgot-password': (context) => const ForgotPasswordScreen(),
                  AppConstants.onboardingRoute: (context) => const OnboardingScreen(),
                  '/create-trade': (context) => const CreateTradeScreen(),
                  '/my-trades': (context) => const MyTradesScreen(),
                  '/trade-offers': (context) => const TradeOffersScreen(),
                  AppConstants.createGiftRoute: (context) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    final chainParentId = args is Map ? args['chainParentId'] as String? : null;
                    return CreateGiftScreen(chainParentId: chainParentId);
                  },
                  AppConstants.myGiftsRoute: (context) => const MyGiftsScreen(),
                  AppConstants.giftHistoryRoute: (context) =>
                      const GiftHistoryScreen(),
                  AppConstants.createCampaignRoute: (context) =>
                      const CreateCampaignScreen(),
                  '/create-intent': (context) => const ComingSoonScreen(title: 'Community'),
                  '/create-request': (context) => const ComingSoonScreen(title: 'Community'),
                  AppConstants.myCampaignsRoute: (context) =>
                      const MyCampaignsScreen(),
                  AppConstants.donationHistoryRoute: (context) =>
                      const DonationHistoryScreen(),
                  '/campaign-details': (context) {
                    // Accept either a fully-loaded Campaign object or a
                    // lightweight map carrying just {'id': ...}. The home V2
                    // feed and campaigns rail navigate via the id-only shape.
                    final args = ModalRoute.of(context)?.settings.arguments;
                    if (args is Campaign) {
                      return CampaignDetailsScreen(campaign: args);
                    }
                    if (args is Map) {
                      final id = args['id']?.toString() ??
                          args['campaignId']?.toString();
                      if (id != null && id.isNotEmpty) {
                        return CampaignDetailsLoader(campaignId: id);
                      }
                    }
                    return const Scaffold(
                      body: Center(child: Text('Campaign not found.')),
                    );
                  },
                  AppConstants.createCommunityRoute: (context) =>
                      const ComingSoonScreen(title: 'Community'),
                  AppConstants.communityRoute: (context) =>
                      const ComingSoonScreen(title: 'Community'),
                  AppConstants.communityDetailsRoute: (context) =>
                      const ComingSoonScreen(title: 'Community'),
                  AppConstants.communityPostsRoute: (context) =>
                      const ComingSoonScreen(title: 'Community'),
                  AppConstants.createPostRoute: (context) =>
                      const ComingSoonScreen(title: 'Community'),
                  AppConstants.eventsRoute: (context) =>
                      const ComingSoonScreen(title: 'Community'),
                  AppConstants.walletRoute: (context) => AuthGate(
                        title: 'Sign in to view your wallet',
                        message:
                            'Sign in or create a free account to manage BYC, karma, and donations.',
                        child: WalletScreen(),
                      ),
                  '/wallet/promotions': (context) => const AuthGate(
                        title: 'Sign in for promotions',
                        message:
                            'Sign in or create a free account to boost listings and manage ads.',
                        child: PromotionCenterScreen(),
                      ),
                  '/wallet/create-ad': (context) => const AuthGate(
                        child: CreateAdScreen(),
                      ),
                  AppConstants.profileRoute: (context) => ProfileScreen(),
                  // PROFILE routes
                  '/profile/activity': (context) =>
                      const ActivityHistoryScreen(),
                  '/profile/achievements': (context) =>
                      const profile_achievements.AchievementsScreen(),
                  // SEARCH routes
                  '/search': (context) => const SearchScreen(),
                  // NOTIFICATION routes
                  '/notifications': (context) => const AuthGate(
                        title: 'Sign in to view notifications',
                        message:
                            'Sign in or create a free account to see alerts for trades, gifts, and campaigns.',
                        highlight:
                            'Your notification inbox is available after you sign in.',
                        child: NotificationsScreen(),
                      ),
                  // SETTINGS routes
                  '/settings': (context) => const SettingsLoaderScreen(),
                  '/help': (context) => HelpSupportScreen(),
                },
                onGenerateRoute: (settings) {
                  // Chat route with conversation details from API response
                  if (settings.name == '/chat') {
                    final args = settings.arguments as Map<String, dynamic>;
                    final conversationId = args['conversationId'] as String;
                    final itemTitle = args['itemTitle'] as String? ?? '';
                    final itemType = args['itemType'] as String? ?? 'TRADE';
                    
                    ChatType chatType;
                    switch (itemType.toUpperCase()) {
                      case 'TRADE':
                        chatType = ChatType.trade;
                        break;
                      case 'GIFT':
                        chatType = ChatType.gifting;
                        break;
                      case 'CAMPAIGN':
                      case 'DONATION':
                        chatType = ChatType.donation;
                        break;
                      case 'REQUEST':
                        chatType = ChatType.trade; 
                        break;
                      default:
                        chatType = ChatType.trade;
                    }
                    
                    final conversation = ChatConversation(
                      id: conversationId,
                      otherUserId: args['ownerId'] as String? ?? '',
                      otherUserName: args['ownerName'] as String? ?? 'User',
                      otherUserAvatar: '',
                      chatType: chatType,
                      contextTitle: itemTitle,
                      contextId: args['itemId'] as String? ?? '',
                      lastActivity: DateTime.now(),
                    );
                    
                    return MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        conversation: conversation,
                        chatType: chatType,
                      ),
                    );
                  }
                  if (settings.name == '/email-verification') {
                    final email = settings.arguments as String;
                    return MaterialPageRoute(
                      builder: (context) =>
                          EmailVerificationScreen(email: email),
                    );
                  }

                  if (settings.name == '/password-reset') {
                    final email = settings.arguments as String;
                    return MaterialPageRoute(
                      builder: (context) =>
                          ResetPasswordScreen(email: email),
                    );
                  }

                  if (settings.name == '/trade-details') {
                    final arguments = settings.arguments;
                    if (arguments is trade_models.Trade &&
                        arguments.images.isNotEmpty) {
                      return MaterialPageRoute(
                        builder: (context) =>
                            TradeDetailsScreen(trade: arguments),
                      );
                    }

                    String tradeId;
                    if (arguments is trade_models.Trade) {
                      tradeId = arguments.id;
                    } else if (arguments is Map<String, dynamic>) {
                      tradeId = arguments['id']?.toString() ?? '';
                    } else {
                      tradeId = '';
                    }

                    return MaterialPageRoute(
                      builder: (context) =>
                          TradeDetailsLoader(tradeId: tradeId),
                    );
                  }

                  if (settings.name == '/edit-trade') {
                    final arguments = settings.arguments;
                    trade_models.Trade trade;

                    if (arguments is trade_models.Trade) {
                      trade = arguments;
                    } else {
                      trade = trade_models.Trade(
                        id: 'error',
                        title: 'Error Loading Trade',
                        description: 'There was an error loading this trade.',
                        images: const [],
                        category: trade_models.TradeCategory.others,
                        owner: trade_models.TradeUser(
                          id: 'error_user',
                          name: 'Error',
                          username: '@error',
                          rating: 0.0,
                          completedTrades: 0,
                          joinedDate: DateTime.now(),
                          isVerified: false,
                        ),
                        status: trade_models.TradeStatus.active,
                        createdAt: DateTime.now(),
                        condition: trade_models.ItemCondition.good,
                        estimatedValue: 0,
                        interestedItems: const [],
                        location: '',
                        tags: const [],
                        viewCount: 0,
                        favoriteCount: 0,
                        isNegotiable: true,
                        allowPickup: true,
                      );
                    }

                    return MaterialPageRoute(
                      builder: (context) => EditTradeScreen(trade: trade),
                    );
                  }

                  if (settings.name == '/negotiation') {
                    final args = settings.arguments as Map<String, dynamic>;
                    return MaterialPageRoute(
                      builder: (context) => NegotiationScreen(
                        targetTrade: args['targetTrade'] as trade_models.Trade,
                        userTrades:
                            args['userTrades'] as List<trade_models.Trade>,
                      ),
                    );
                  }

                  if (settings.name == '/trade-offers-filtered') {
                    final selectedTrade =
                        settings.arguments as trade_models.Trade?;
                    return MaterialPageRoute(
                      builder: (context) =>
                          TradeOffersScreen(selectedTrade: selectedTrade),
                    );
                  }

                  if (settings.name == AppConstants.giftDetailsRoute) {
                    final arguments = settings.arguments;
                    if (arguments is gift_models.Gift) {
                      return MaterialPageRoute(
                        builder: (context) => GiftDetailsScreen(
                          gift: AppRoutes.giftToLegacyMap(arguments),
                        ),
                      );
                    }
                    if (arguments is Map<String, dynamic>) {
                      final id = arguments['id']?.toString() ??
                          arguments['giftId']?.toString();
                      final isIdOnly = id != null &&
                          id.isNotEmpty &&
                          arguments['title'] == null;
                      if (isIdOnly) {
                        return MaterialPageRoute(
                          builder: (context) =>
                              GiftDetailsLoader(giftId: id),
                        );
                      }
                      return MaterialPageRoute(
                        builder: (context) =>
                            GiftDetailsScreen(gift: arguments),
                      );
                    }
                    return MaterialPageRoute(
                      builder: (context) => const Scaffold(
                        body: Center(child: Text('Gift not found.')),
                      ),
                    );
                  }

                  if (settings.name == AppConstants.editGiftRoute) {
                    final arguments = settings.arguments;
                    gift_models.Gift? gift;

                    if (arguments is gift_models.Gift) {
                      gift = arguments;
                    } else if (arguments is Map<String, dynamic>) {
                      try {
                        gift = gift_models.Gift(
                          id: arguments['id']?.toString() ?? '',
                          title: arguments['title']?.toString() ?? '',
                          description:
                              arguments['description']?.toString() ?? '',
                          giver: gift_models.GiftUser(
                            id: arguments['giverId']?.toString() ?? '',
                            name: arguments['giver']?.toString() ?? 'Unknown',
                            username: '@unknown',
                            rating: 0.0,
                            completedGifts: 0,
                            karmaPoints: 0,
                            joinedDate: DateTime.now(),
                            isVerified: false,
                          ),
                          type: gift_models.GiftType.values.firstWhere(
                            (t) =>
                                t.name ==
                                (arguments['type']?.toString().toLowerCase() ??
                                    'random'),
                            orElse: () => gift_models.GiftType.random,
                          ),
                          category: gift_models.GiftCategory.values.firstWhere(
                            (c) =>
                                c.name ==
                                (arguments['category']
                                        ?.toString()
                                        .toLowerCase() ??
                                    'others'),
                            orElse: () => gift_models.GiftCategory.others,
                          ),
                          status: gift_models.GiftStatus.active,
                          createdAt: DateTime.now(),
                          expiresAt: null,
                          karmaReward: (arguments['karma'] as int?) ?? 30,
                          maxClaims: 1,
                          currentClaims: 0,
                          location: arguments['location']?.toString(),
                          isLocationRestricted: false,
                          imageUrls: const [],
                          tags:
                              (arguments['tags'] as List<dynamic>?)
                                  ?.map((e) => e.toString())
                                  .toList() ??
                              const [],
                          metadata: const {},
                          targetUserId: null,
                          targetCriteria: null,
                        );
                      } catch (_) {
                        gift = null;
                      }
                    }

                    return MaterialPageRoute(
                      builder: (context) => CreateGiftScreen(initialGift: gift),
                    );
                  }

                  if (settings.name == AppConstants.claimGiftRoute) {
                    // Handle both old format (just gift map) and new format (gift map + fullGift)
                    Map<String, dynamic> gift;
                    gift_models.Gift? fullGift;
                    
                    if (settings.arguments is Map<String, dynamic>) {
                      final args = settings.arguments as Map<String, dynamic>;
                      gift = args['gift'] as Map<String, dynamic>? ?? args;
                      fullGift = args['fullGift'] as gift_models.Gift?;
                    } else {
                      // Fallback for legacy format
                      gift = settings.arguments as Map<String, dynamic>;
                      fullGift = null;
                    }
                    
                    return MaterialPageRoute(
                      builder: (context) => ClaimGiftScreen(
                        gift: gift,
                        fullGift: fullGift,
                      ),
                    );
                  }

                  if (settings.name == AppConstants.campaignManagementRoute) {
                    final campaign = settings.arguments as Campaign;
                    return MaterialPageRoute(
                      builder: (context) =>
                          CampaignManagementScreen(campaign: campaign),
                    );
                  }

                  if (settings.name == '/karma/achievement-detail') {
                    final achievement = settings.arguments as karma_models.Achievement;
                    return MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: Text(achievement.name)),
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                achievement.iconUrl,
                                style: const TextStyle(fontSize: 60),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                achievement.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(achievement.description),
                              const SizedBox(height: 16),
                              if (achievement.isUnlocked)
                                Text(
                                  'Unlocked: ${achievement.unlockedAt?.day}/${achievement.unlockedAt?.month}/${achievement.unlockedAt?.year}',
                                  style: TextStyle(color: Colors.green),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                'Reward: +${achievement.pointsReward} KARMA',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (settings.name == '/profile/edit') {
                    final userProfile = settings.arguments as UserProfile;
                    return MaterialPageRoute(
                      builder: (context) =>
                          EditProfileScreen(userProfile: userProfile),
                    );
                  }

                  if (settings.name == '/profile/verification') {
                    final userProfile = settings.arguments as UserProfile;
                    return MaterialPageRoute(
                      builder: (context) =>
                          VerificationScreen(userProfile: userProfile),
                    );
                  }

                  if (settings.name == '/profile/settings') {
                    final userProfile = settings.arguments as UserProfile;
                    return MaterialPageRoute(
                      builder: (context) =>
                          EnhancedSettingsScreen(userProfile: userProfile),
                    );
                  }

                  if (settings.name == '/search/results') {
                    final query = settings.arguments as String;
                    return MaterialPageRoute(
                      builder: (context) => SearchResultsScreen(query: query),
                    );
                  }

                  if (settings.name == '/request-details') {
                    final item = settings.arguments as FeedItem;
                    return MaterialPageRoute(
                      builder: (context) => RequestDetailsScreen(item: item),
                    );
                  }

                  return null;
                },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PreloadActiveCampaigns extends StatefulWidget {
  final Widget child;
  const _PreloadActiveCampaigns({required this.child});

  @override
  State<_PreloadActiveCampaigns> createState() =>
      _PreloadActiveCampaignsState();
}

class _PreloadActiveCampaignsState extends State<_PreloadActiveCampaigns> {
  static bool _didPreload = false;

  @override
  void initState() {
    super.initState();
    if (!_didPreload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final authProvider = context.read<AuthProvider>();
          if (!authProvider.isAuthenticated) {
            return;
          }
        } catch (e) {
          return;
        }
        
        final campaignProvider = context.read<CampaignProvider>();
        if (campaignProvider.campaigns.isEmpty && !campaignProvider.isLoading) {
          campaignProvider.loadCampaigns(
            status: donations.CampaignStatus.active,
          );
        }
        _didPreload = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  static const Duration _minSplashDuration = Duration(seconds: 3);
  /// After the min splash, show feedback if bootstrap is still running.
  static const Duration _connectionFeedbackDelay = Duration(seconds: 4);
  static const Duration _forceBootstrapTimeout = Duration(seconds: 12);

  bool _minSplashElapsed = false;
  bool _onboardingResolved = false;
  bool _hasOnboarded = false;
  bool _showConnectionFeedback = false;
  bool _isRetryingStartup = false;
  bool? _hasInternet;
  Timer? _connectionFeedbackTimer;
  Timer? _forceBootstrapTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, _onMinSplashElapsed);
    unawaited(_loadOnboardingState());
    _forceBootstrapTimer = Timer(_forceBootstrapTimeout, _forceBootstrapComplete);
  }

  @override
  void dispose() {
    _connectionFeedbackTimer?.cancel();
    _forceBootstrapTimer?.cancel();
    super.dispose();
  }

  void _onMinSplashElapsed() {
    if (!mounted) return;
    setState(() => _minSplashElapsed = true);
    _scheduleConnectionFeedbackTimer();
  }

  bool _isBootstrapping(AuthProvider auth) {
    if (!_minSplashElapsed) return true;
    if (auth.isLoading) return true;
    if (!_onboardingResolved) return true;
    return false;
  }

  void _scheduleConnectionFeedbackTimer() {
    _connectionFeedbackTimer?.cancel();
    _connectionFeedbackTimer = Timer(_connectionFeedbackDelay, () {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!_isBootstrapping(auth)) return;

      setState(() => _showConnectionFeedback = true);
      unawaited(_probeInternet());
    });
  }

  Future<void> _probeInternet() async {
    final online = await NetworkUtils.hasInternetConnection();
    if (!mounted) return;
    setState(() => _hasInternet = online);
  }

  Future<void> _loadOnboardingState() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      _hasOnboarded =
          prefs.getBool(AppConstants.onboardingCompletedKey) ?? false;
    } catch (_) {
      _hasOnboarded = true;
    }
    if (!mounted) return;
    setState(() => _onboardingResolved = true);
  }

  Future<void> _forceBootstrapComplete() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!_isBootstrapping(auth)) return;

    if (auth.isLoading) {
      await auth.forceOfflineStartup();
    }
    if (!_onboardingResolved && mounted) {
      setState(() {
        _onboardingResolved = true;
        _hasOnboarded = true;
      });
    }
    if (mounted) {
      setState(() => _showConnectionFeedback = true);
    }
  }

  Future<void> _handleStartupRetry() async {
    if (_isRetryingStartup) return;
    setState(() {
      _isRetryingStartup = true;
      _showConnectionFeedback = false;
      _hasInternet = null;
    });
    _scheduleConnectionFeedbackTimer();
    await context.read<AuthProvider>().retryInitializeAuth();
    if (!mounted) return;
    setState(() => _isRetryingStartup = false);
  }

  Future<void> _handleContinueOffline() async {
    await context.read<AuthProvider>().forceOfflineStartup();
    if (!_onboardingResolved) {
      _hasOnboarded = true;
      _onboardingResolved = true;
    }
    if (!mounted) return;
    setState(() {
      _showConnectionFeedback = false;
      _hasInternet = null;
      _onboardingResolved = true;
    });
    _connectionFeedbackTimer?.cancel();
    _forceBootstrapTimer?.cancel();
  }

  Widget _buildSplash({
    required AuthProvider auth,
    required bool showConnectionFeedback,
  }) {
    final online = _hasInternet;
    final overlay = showConnectionFeedback
        ? StartupNetworkOverlay(
            title: online == false
                ? 'No internet connection'
                : 'Having trouble connecting',
            message: online == false
                ? NetworkErrorMessage.offline
                : 'Bybata is taking longer than usual to start. Check your connection and try again.',
            onRetry: _handleStartupRetry,
            onContinueOffline: _handleContinueOffline,
            continueOfflineLabel: auth.hasCachedSession
                ? 'Continue with saved account'
                : 'Browse without signing in',
            isRetrying: _isRetryingStartup,
          )
        : null;

    return AnimatedSplashScreen(
      showLoadingIndicator: !showConnectionFeedback,
      overlay: overlay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bootstrapping = _isBootstrapping(auth);

    if (!bootstrapping && _showConnectionFeedback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isBootstrapping(context.read<AuthProvider>())) return;
        setState(() {
          _showConnectionFeedback = false;
          _hasInternet = null;
        });
        _connectionFeedbackTimer?.cancel();
      });
    }

    if (bootstrapping) {
      return _buildSplash(
        auth: auth,
        showConnectionFeedback: _showConnectionFeedback,
      );
    }

    if (auth.isAuthenticated) {
      final user = auth.currentUser;
      if (user != null && !user.isEmailVerified) {
        return EmailVerificationScreen(email: user.email);
      }
      return const MainNavigation();
    }

    if (!_hasOnboarded) {
      return const OnboardingScreen();
    }
    return const BrowseHomeScreenV2();
  }
}

class _DeepLinkHandler extends StatefulWidget {
  final Widget child;
  const _DeepLinkHandler({required this.child});
  @override
  State<_DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<_DeepLinkHandler> {
  StreamSubscription? _sub;
  String? _pendingInviteCode;
  bool _listeningAuth = false;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationsService.handleInitialMessage();
    });
  }

  Future<void> _initDeepLinks() async {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.toString().isNotEmpty) {
        await _handleUri(uri);
      }
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (_) {}
    _sub = _appLinks.uriLinkStream.listen((uri) async {
      await _handleUri(uri);
    }, onError: (_) {});
    await _loadPendingInvite();
    _listenAuthChanges();
  }

  Future<void> _dismissEmbeddedBrowserIfNeeded() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await closeInAppWebView();
    } catch (_) {}
  }

  /// Normalizes [bybata://] URIs. Dart treats the first segment as [Uri.host]
  /// (e.g. `bybata://campaign/{id}` → host=campaign, path=/id).
  ({String type, String id, Map<String, String> query}) _parseBybataUri(Uri uri) {
    final query = Map<String, String>.from(uri.queryParameters);
    final host = uri.host;
    final segs = uri.pathSegments;

    if (host == 'app') {
      if (segs.isEmpty) return (type: 'home', id: '', query: query);
      final idFromQuery = query['id'] ?? '';
      return (
        type: segs[0],
        id: segs.length > 1 ? segs[1] : idFromQuery,
        query: query,
      );
    }

    if (host.isNotEmpty) {
      return (type: host, id: segs.isNotEmpty ? segs[0] : '', query: query);
    }

    if (segs.isEmpty) return (type: 'home', id: '', query: query);
    return (type: segs[0], id: segs.length > 1 ? segs[1] : '', query: query);
  }

  Future<void> _handleUri(Uri uri) async {
    final segs = uri.pathSegments;
    final query = uri.queryParameters;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (uri.scheme == 'bybata') {
      await _dismissEmbeddedBrowserIfNeeded();
      final link = _parseBybataUri(uri);
      final type = link.type;
      final id = link.id;
      final bybataQuery = link.query;
      switch (type) {
        case 'home':
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'home')),
          );
          break;
        case 'trade':
          await _handleAuthRequiredDeepLink('trade', id);
          break;
        case 'gift':
          await _handleAuthRequiredDeepLink('gift', id);
          break;
        case 'campaign':
        case 'donation':
          await _handleAuthRequiredDeepLink('campaign', id);
          if (bybataQuery['webDonate'] == 'success') {
            ConversationalFeedRefreshBus.instance.requestRefresh();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(
                _showWebDonationSuccess(
                  amount: double.tryParse(bybataQuery['amount'] ?? ''),
                  karma: int.tryParse(bybataQuery['karma'] ?? ''),
                ),
              );
            });
          }
          break;
        case 'community':
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const ComingSoonScreen(title: 'Community')),
          );
          break;
        case 'chat':
          await _openChatFromDeepLink(id);
          break;
        case 'profile':
          final usernameParam = bybataQuery['username'];
          if (usernameParam != null && usernameParam.isNotEmpty) {
            final userId = await _resolveUserIdFromUsername(usernameParam);
            if (userId != null) {
              GuardedNavigator.push(context, 
                MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
              );
            } else {
              AppToast.show(context, 'User not found');
            }
          } else if (id.startsWith('@')) {
            final userId = await _resolveUserIdFromUsername(id);
            if (userId != null) {
              GuardedNavigator.push(context, 
                MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
              );
            } else {
              AppToast.show(context, 'User not found');
            }
          } else if (id.isNotEmpty) {
            GuardedNavigator.push(context, 
              MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)),
            );
          } else {
            GuardedNavigator.push(context, 
              MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'profile')),
            );
          }
          break;
        case 'wallet':
          if (mounted) {
            GuardedNavigator.push(context, 
              MaterialPageRoute(
                builder: (_) => const MainNavigation(initialScreen: 'wallet'),
              ),
            );
          }
          final webSupport = bybataQuery['webSupport'] ?? '';
          if (webSupport.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              AppToast.show(
                context,
                'After funding, return to Safari to complete your donation.',
              );
            });
          }
          break;
        case 'community-invite':
        case 'invite':
          final code = bybataQuery['code'] ?? id;
          if (code.isNotEmpty) {
            await _handleInviteCode(code, auth.isAuthenticated);
          }
          break;
        default:
          break;
      }
    } else if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (segs.isEmpty) return;
      final type = segs[0];
      final id = segs.length > 1 ? segs[1] : '';
      // Handle https://bybata.com/open-app?path=/trade/123 (Universal Links from emails)
      if (type == 'open-app') {
        final path = query['path'] ?? '';
        if (path.isEmpty) {
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'home')),
          );
          return;
        }
        final pathUri = Uri.parse(path);
        final pathSegs = pathUri.pathSegments;
        final pathQuery = pathUri.queryParameters;
        final pathType = pathSegs.isNotEmpty ? pathSegs[0] : '';
        final pathId = pathSegs.length > 1 ? pathSegs[1] : '';
        if (pathType == 'trade') {
          await _handleAuthRequiredDeepLink('trade', pathId);
        } else if (pathType == 'gift') {
          await _handleAuthRequiredDeepLink('gift', pathId);
        } else if (pathType == 'campaign' || pathType == 'donation') {
          await _handleAuthRequiredDeepLink('campaign', pathId);
          if (query['webDonate'] == 'success') {
            ConversationalFeedRefreshBus.instance.requestRefresh();
            await _showWebDonationSuccess(
              amount: double.tryParse(query['amount'] ?? ''),
              karma: int.tryParse(query['karma'] ?? ''),
            );
          }
        } else if (pathType == 'community') {
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const ComingSoonScreen(title: 'Community')),
          );
        } else if (pathType == 'chat') {
          await _openChatFromDeepLink(pathId);
        } else if (pathType == 'profile') {
          if (pathId.isNotEmpty) {
            GuardedNavigator.push(context, 
              MaterialPageRoute(builder: (_) => UserProfileScreen(userId: pathId)),
            );
          } else {
            GuardedNavigator.push(context, 
              MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'profile')),
            );
          }
        } else if (pathType == 'wallet') {
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'wallet')),
          );
        } else if (pathType == 'invite') {
          final code = pathQuery['code'] ?? pathId;
          if (code.isNotEmpty) {
            await _handleInviteCode(code, auth.isAuthenticated);
          } else {
            GuardedNavigator.push(context, 
              MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'home')),
            );
          }
        } else if (pathType == 'dashboard' || pathType == 'ads') {
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'home')),
          );
        } else {
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'home')),
          );
        }
        return;
      }
      if (type == 'trade') {
        await _handleAuthRequiredDeepLink('trade', id);
      } else if (type == 'gift') {
        await _handleAuthRequiredDeepLink('gift', id);
      } else if (type == 'campaign' || type == 'donation') {
        await _handleAuthRequiredDeepLink('campaign', id);
      } else if (type == 'community') {
        GuardedNavigator.push(context, 
          MaterialPageRoute(builder: (_) => const ComingSoonScreen(title: 'Community')),
        );
      } else if (type == 'chat') {
        await _openChatFromDeepLink(id);
      } else if (type == 'profile') {
        final usernameParam = query['username'];
        if (usernameParam != null && usernameParam.isNotEmpty) {
          final userId = await _resolveUserIdFromUsername(usernameParam);
          if (userId != null) {
            GuardedNavigator.push(context, 
              MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
            );
          } else {
            AppToast.show(context, 'User not found');
          }
        } else if (id.startsWith('@')) {
          final userId = await _resolveUserIdFromUsername(id);
          if (userId != null) {
            GuardedNavigator.push(context, 
              MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
            );
          } else {
            AppToast.show(context, 'User not found');
          }
        } else if (id.isNotEmpty) {
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)),
          );
        } else {
          GuardedNavigator.push(context, 
            MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'profile')),
          );
        }
      } else if (type == 'wallet') {
        GuardedNavigator.push(context, 
          MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'wallet')),
        );
      } else if (type == 'community-invite') {
        final code = query['code'] ?? (segs.length > 1 ? segs[1] : '');
        if (code.isNotEmpty) {
          await _handleInviteCode(code, auth.isAuthenticated);
        }
      } else if (type == 'invite') {
        final code = query['code'] ?? (segs.length > 1 ? segs[1] : '');
        if (code.isNotEmpty) {
          await _handleInviteCode(code, auth.isAuthenticated);
        }
      }
    }
  }

  Future<void> _openChatFromDeepLink(String conversationId) async {
    if (conversationId.isEmpty) {
      GuardedNavigator.push(context, 
        MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'chat')),
      );
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      if (mounted) GuardedNavigator.pushNamed(context, '/login');
      return;
    }
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.refreshConversations(force: true);
    ChatConversation? convo;
    for (final c in chatProvider.conversations) {
      if (c.id == conversationId) {
        convo = c;
        break;
      }
    }
    convo ??= await chatProvider.fetchAndUpsertConversation(conversationId);
    if (!mounted) return;
    if (convo == null) {
      GuardedNavigator.push(context, 
        MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'chat')),
      );
      return;
    }
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: convo!,
          chatType: convo.chatType,
        ),
      ),
    );
  }

  Future<String?> _resolveUserIdFromUsername(String username) async {
    final normalized = username.trim().replaceFirst('@', '');
    if (normalized.isEmpty) return null;
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final res = await apiClient.get('/v1/users/username/$normalized');
      final data = res.data;
      if (data is Map && data['id'] != null) {
        return data['id'].toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadPendingInvite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pendingInviteCode = prefs.getString('pending_invite_code');
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        if (_pendingInviteCode != null && _pendingInviteCode!.isNotEmpty) {
          await _acceptInviteCode(_pendingInviteCode!);
          await prefs.remove('pending_invite_code');
          _pendingInviteCode = null;
        } else {
          await _loadAndNavigatePendingDeepLink();
        }
      }
    } catch (_) {}
  }

  void _listenAuthChanges() {
    if (_listeningAuth) return;
    _listeningAuth = true;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.addListener(() async {
      if (!mounted) return;
      if (auth.isAuthenticated) {
        if (_pendingInviteCode != null) {
          await _acceptInviteCode(_pendingInviteCode!);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_invite_code');
          _pendingInviteCode = null;
        } else {
          await _loadAndNavigatePendingDeepLink();
        }
      }
    });
  }

  Future<void> _showWebDonationSuccess({
    double? amount,
    int? karma,
  }) async {
    if (!mounted) return;
    try {
      await context.read<KarmaProvider>().initialize();
      await context.read<WalletProvider>().refreshWallet();
      await context.read<CampaignProvider>().loadCampaigns(force: true);
    } catch (_) {}
    final dialogContext = appNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    final byc = amount ?? 0;
    final karmaPts = karma ??
        (byc > 0 ? calculateDonationKarmaReward(byc) : 0);
    if (byc <= 0 && karmaPts <= 0) {
      AppToast.show(dialogContext, 'Thank you for your support!');
      return;
    }
    await DonationSuccessDialog.show(
      dialogContext,
      amountByc: byc > 0 ? byc : 0,
      karmaEarned: karmaPts > 0 ? karmaPts : null,
    );
  }

  /// Redirects unauthenticated users to login; stores deep link to navigate after login.
  Future<void> _handleAuthRequiredDeepLink(String type, String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AppConstants.pendingDeepLinkKey,
        jsonEncode(<String, String>{'type': type, 'id': id}),
      );
      if (mounted) GuardedNavigator.pushNamed(context, '/login');
      return;
    }
    _navigateToDeepLink(type, id);
  }

  void _navigateToDeepLink(String type, String id) {
    switch (type) {
      case 'trade':
        GuardedNavigator.pushNamed(context, '/trade-details', arguments: {'id': id});
        break;
      case 'gift':
        GuardedNavigator.push(context, 
          MaterialPageRoute(builder: (_) => GiftDetailsLoader(giftId: id)),
        );
        break;
      case 'campaign':
        GuardedNavigator.pushNamed(context, AppConstants.myCampaignsRoute);
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (_) => CampaignDetailsLoader(campaignId: id),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _loadAndNavigatePendingDeepLink() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.pendingDeepLinkKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      if (map == null) return;
      final type = map['type']?.toString() ?? '';
      final id = map['id']?.toString() ?? '';
      if (type.isEmpty || id.isEmpty) return;
      await prefs.remove(AppConstants.pendingDeepLinkKey);
      if (mounted) _navigateToDeepLink(type, id);
    } catch (_) {}
  }

  Future<void> _handleInviteCode(String code, bool isAuthenticated) async {
    if (!isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_invite_code', code);
      _pendingInviteCode = code;
      if (mounted) GuardedNavigator.pushNamed(context, '/login');
      return;
    }
    await _acceptInviteCode(code);
  }

  Future<void> _acceptInviteCode(String code) async {
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      final lookup = await service.lookupInvite(code);
      await service.acceptInviteByCode(code);
      final community = lookup['community'] as Map<String, dynamic>? ?? {};
      final id = community['id']?.toString() ?? '';
      final name = community['name']?.toString() ?? 'Community';
      if (id.isNotEmpty && mounted) {
        AppToast.show(context, 'Joined $name');
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (_) => const ComingSoonScreen(title: 'Community'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Invite failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}