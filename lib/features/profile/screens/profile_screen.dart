import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../features/trade/providers/trade_backend_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../core/utils/profile_location_utils.dart';
import '../../../features/gifting/api/gift_api.dart';
import '../../../features/donations/api/campaign_api.dart';
import '../../../features/wallet/services/wallet_api.dart';
import '../../../features/wallet/navigation/wallet_navigator.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_side_drawer.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../common/widgets/verified_badge.dart';
import '../../../core/theme/app_theme.dart';
import '../../karma/providers/karma_provider.dart';
import '../../karma/navigation/karma_navigator.dart';
import '../../karma/screens/karma_screen.dart';
import '../../../core/errors/graceful_errors.dart';
import '../../../core/utils/trust_score_utils.dart';
import '../../../core/widgets/safe_screen.dart';
import '../models/user_profile.dart';
import '../models/activity.dart';
import '../services/activity_api_service.dart';
import '../services/achievements_api_service.dart';
import '../services/profile_cache.dart';
import '../services/profile_social_notifier.dart';
import '../services/user_social_service.dart';
import 'edit_profile_screen.dart';
import 'activity_history_screen.dart';
import 'achievements_screen.dart' as profile_achievements;
import 'verification_screen.dart';
import 'user_followers_list_screen.dart';
import 'package:bybata/features/settings/screens/enhanced_settings_screen.dart';
import 'package:bybata/features/settings/widgets/settings_ui.dart';
import '../../../core/utils/share_utils.dart';
import '../../referrals/services/referral_api_service.dart';
import '../../referrals/widgets/referral_share_card.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserProfile? userProfile;
  TabController? _tabController;
  AuthProvider? _authProvider;
  late ActivityApiService _activityApiService;
  late AchievementsApiService _achievementsApiService;
  
  Map<String, int> _userCounters = {
    'trades': 0,
    'gifts': 0,
    'giftsClaimed': 0,
    'donations': 0,
    'donatedByc': 0,
    'donatedKarma': 0,
    'receivedDonations': 0,
    'receivedDonationsByc': 0,
    'byc': 0,
    'communities': 0,
  };
  
  // Activity and achievements state
  List<Activity> _userActivities = [];
  bool _activitiesLoading = false;
  String? _activitiesError;
  
  bool _statsLoading = true;
  bool _isInitialized = false;
  bool _isLoadingProfile = true;
  Object? _loadError;
  bool _needsProfileSetup = false;
  bool _didRequestLoad = false;
  int _currentTabIndex = 0; // For fluid animation state
  
  // Cache timestamps for smart refetching
  DateTime? _lastProfileFetchAt;
  DateTime? _lastCountersFetchAt;
  DateTime? _lastActivitiesFetchAt;
  bool _profileInitialized = false;
  bool _countersInitialized = false;
  bool _activitiesInitialized = false;
  int _trophiesRefreshKey = 0; // Increment to force Trophies tab FutureBuilder to reload
  
  // Cache duration (3 minutes for profile data)
  static const Duration _cacheDuration = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listener for Fluid Tab Switcher
      _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController!.index;
          // Load activities when switching to activity tab
          if (_currentTabIndex == 1 && _userActivities.isEmpty && !_activitiesLoading) {
            _loadUserActivities();
          }
          // Trophies tab (index 2) uses FutureBuilder - force refresh when switching to show latest
          if (_currentTabIndex == 2) {
            _trophiesRefreshKey++;
          }
        });
      }
    });

    _isInitialized = true;
    ProfileSocialNotifier.instance.addListener(_onSocialStatsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLoadAfterAuth();
    });
  }

  void _onSocialStatsChanged() {
    if (!mounted || userProfile == null) return;
    _refreshSocialStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider ??= Provider.of<AuthProvider>(context, listen: false);
    _authProvider?.addListener(_handleAuthChange);
  }

  @override
  void dispose() {
    ProfileSocialNotifier.instance.removeListener(_onSocialStatsChanged);
    _authProvider?.removeListener(_handleAuthChange);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleAuthChange() {
    if (!mounted) return;
    _maybeLoadAfterAuth();
  }

  void _maybeLoadAfterAuth() {
    if (_didRequestLoad) return;
    final auth = _authProvider;
    if (auth == null || auth.isLoading) {
      return;
    }
    if (!auth.isAuthenticated) {
      setState(() {
        _loadError = 'Not logged in';
        _isLoadingProfile = false;
      });
      return;
    }
    _didRequestLoad = true;
    // Try to hydrate from local Hive cache first for faster initial render.
    _loadUserProfileFromCache().then((_) {
      // OPTIMIZATION: Load profile and counters in parallel instead of sequentially
      Future.wait([
        _loadUserProfile(),
        _loadUserCounters(),
      ]).catchError((e) {
        print('Error loading profile data: $e');
      });
    });
  }

  Future<void> _loadUserProfileFromCache() async {
    try {
      final cached = await ProfileCache.loadCurrent();
      if (cached != null && mounted) {
        setState(() {
          userProfile = cached;
          _isLoadingProfile = false;
          _loadError = null;
        });
      }
    } catch (_) {
      // Ignore cache failures; network fetch will still run.
    }
  }

  // --- UI SURFACES (aligned with SettingsUi / wallet) ---
  Widget _profileCard({
    required Widget child,
    Color? backgroundColor,
    double radius = SettingsUi.cardRadius,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: backgroundColor != null
            ? BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(radius),
              )
            : null,
        child: child,
      ),
    );
  }

  TextStyle _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        );
  }

  // --- LOGIC PRESERVATION: API CALLS ---
  
  Future<void> _loadUserProfile({bool force = false}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _profileInitialized && _lastProfileFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastProfileFetchAt!);
      if (cacheAge < _cacheDuration && userProfile != null) {
        print('[ProfileScreen] Using cached profile (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    try {
      final hadProfile = userProfile != null;
      setState(() {
        // Only show full-screen loader if we have no profile at all.
        _isLoadingProfile = !hadProfile;
        _loadError = null;
      });

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.id;
      
      if (userId == null) {
        if (auth.isLoading) {
          return;
        }
        setState(() {
          _loadError = 'Not logged in';
          _isLoadingProfile = false;
        });
        return;
      }

      // Call API to get user profile
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      
      final response = await apiClient.dio.get('/v1/users/me');
      final userData = response.data as Map<String, dynamic>;
      
      // Parse the response
      final profile = userData['profile'] as Map<String, dynamic>?;
      final displayName = (profile?['displayName'] as String?)?.trim();
      final safeDisplayName =
          (displayName != null && displayName.isNotEmpty) ? displayName : 'User';
      final nameParts = safeDisplayName.split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts.first : 'User';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      final username = profile?['username'] as String?;
      final bio = profile?['bio'] as String?;
      final phone = profile?['phone'] as String?;
      final avatarKey = profile?['avatarKey'] as String?;
      final kycStatus = profile?['kycStatus'] as String?;
      final kycNote = profile?['kycNote'] as String?;
      final email = userData['email'] as String? ?? '';
      final averageRating = (profile?['averageRating'] as num?)?.toDouble() ?? 0.0;
      final totalReviews = (profile?['totalReviews'] as num?)?.toInt() ?? 0;
      final followersCount = (profile?['followersCount'] as num?)?.toInt() ?? 0;
      final followingCount = (profile?['followingCount'] as num?)?.toInt() ?? 0;
      final donatedBycFromProfile = (profile?['donatedByc'] as num?)?.toInt();
      final donatedKarmaFromProfile = (profile?['donatedKarma'] as num?)?.toInt();
      
      // Get karma data
      final karmaProvider = Provider.of<KarmaProvider>(context, listen: false);
      await karmaProvider.initialize();
      // final karmaPoints = karmaProvider.totalKarma; // (Unused in local var but kept logic flow)
      // final karmaLevel = karmaProvider.level; // (Unused in local var but kept logic flow)
      
      setState(() {
        _needsProfileSetup = safeDisplayName == 'User' ||
            (username == null || username.trim().isEmpty);
        userProfile = UserProfile(
          id: userId,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          bio: bio,
          location: ProfileLocationUtils.fromProfile(
            profile != null ? Map<String, dynamic>.from(profile) : null,
          ),
          occupation: null,
          interests: [],
          avatar: avatarKey,
          stats: ProfileStats(
            totalTrades: _userCounters['trades'] ?? 0,
            successfulTrades: _userCounters['trades'] ?? 0,
            totalGifts: _userCounters['gifts'] ?? 0,
            totalDonations: _userCounters['donations'] ?? 0,
            totalCommunities: _userCounters['communities'] ?? 0,
            totalFollowers: followersCount,
            totalFollowing: followingCount,
            totalPosts: 0, // TODO: Implement posts count API
            totalLikes: 0, // TODO: Implement likes count API
            averageRating: averageRating,
            totalReviews: totalReviews,
          ),
          trustScore: trustScoreFromApi(profile),
          verification: profile?['verification'] is Map
              ? VerificationStatus.fromJson(
                  Map<String, dynamic>.from(profile!['verification'] as Map),
                )
              : VerificationStatus.fromApiProfile(
                  kycStatus: kycStatus,
                  kycNote: kycNote,
                  emailVerified: userData['emailVerifiedAt'] != null,
                  phoneVerified: profile?['phoneVerifiedAt'] != null,
                ),
          settings: ProfileSettings(),
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        _isLoadingProfile = false;
        if (donatedBycFromProfile != null || donatedKarmaFromProfile != null) {
          _userCounters = {
            ..._userCounters,
            if (donatedBycFromProfile != null) 'donatedByc': donatedBycFromProfile,
            if (donatedKarmaFromProfile != null) 'donatedKarma': donatedKarmaFromProfile,
          };
        }
        
        // Update cache metadata
        _lastProfileFetchAt = DateTime.now();
        _profileInitialized = true;
      });
      // Persist latest profile to Hive cache for faster subsequent loads.
      await ProfileCache.saveCurrent(userProfile!);
    } catch (e) {
      setState(() {
        _loadError = e;
        GracefulErrors.record(e, StackTrace.current, hint: 'ProfileScreen.loadProfile');
        _isLoadingProfile = false;
      });
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadUserCounters({bool force = false}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _countersInitialized && _lastCountersFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastCountersFetchAt!);
      if (cacheAge < _cacheDuration && _userCounters.isNotEmpty) {
        print('[ProfileScreen] Using cached counters (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    try {
      setState(() { _statsLoading = true; });
      
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tradeBackend = Provider.of<TradeBackendProvider>(context, listen: false);
      final userId = auth.currentUser?.id;
      
      if (userId == null) {
        print('ProfileScreen: No user ID found');
        setState(() { _statsLoading = false; });
        return;
      }

      print('ProfileScreen: Loading counters for user: $userId');

      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final giftApi = GiftApi(apiClient);
      final campaignApi = CampaignApi(apiClient);

      // OPTIMIZATION: Execute all API calls in parallel instead of sequentially
      final results = await Future.wait([
        // 1. Trades count
        tradeBackend.listMyTrades(ownerId: userId, page: 1, size: 1)
            .catchError((e) => {'total': 0, 'items': []}),
        
        // 2. Gifts given
        giftApi.listGifts(giverId: userId, page: 1, size: 1)
            .catchError((e) => {'total': 0, 'items': []}),
        
        // 3. Gifts received (only fetch count, not 100 items)
        giftApi.getGiftHistory(page: 1, size: 1)
            .catchError((e) => {'total': 0, 'items': []}),
        
        // 4. Donations history (only fetch count, not 100 items)
        campaignApi.getDonationHistory(page: 1, size: 1)
            .catchError((e) => {'total': 0, 'items': []}),
        
        // 5. Wallet balance
        WalletApi.create().then((api) => api.getWallet())
            .catchError((e) => {'balance': 0}),
        
        // 6. My campaigns (only fetch count, not 100 items)
        campaignApi.getMyCampaigns(page: 1, size: 1)
            .catchError((e) => {'items': [], 'total': 0}),
        
        // 7. Communities count
        apiClient.dio.get('/v1/communities/my')
            .then((res) => res.data as Map<String, dynamic>)
            .catchError((e) => {'total': 0}),

        // 8. Donor analytics (total BYC given + karma from donations)
        campaignApi.getDonorAnalytics()
            .catchError((e) => <String, dynamic>{}),

        // 9. Creator analytics (BYC received on user's campaigns)
        campaignApi.getCreatorAnalytics()
            .catchError((e) => <String, dynamic>{}),
      ]);

      // Parse results
      final tradesTotal = (results[0]['total'] as int?) ?? 0;
      final giftsTotal = (results[1]['total'] as int?) ?? 0;
      final giftsClaimedTotal = (results[2]['total'] as int?) ?? 0;
      final donationsTotal = (results[3]['total'] as int?) ?? 0;
      
      // Parse wallet balance
      final balanceValue = results[4]['balance'];
      double bycBalanceDouble = 0.0;
      if (balanceValue != null) {
        if (balanceValue is num) {
          bycBalanceDouble = balanceValue.toDouble();
        } else if (balanceValue is String) {
          bycBalanceDouble = double.tryParse(balanceValue) ?? 0.0;
        }
      }
      final bycBalance = bycBalanceDouble.round();

      final myCampaignsTotal = (results[5]['total'] as int?) ?? 0;
      final communitiesCount = (results[6]['total'] as int?) ?? 0;

      final donorAnalytics = results[7] as Map<String, dynamic>;
      final creatorAnalytics = results[8] as Map<String, dynamic>;

      final donatedBycAmount =
          double.tryParse(donorAnalytics['totalAmount']?.toString() ?? '') ?? 0.0;
      var donatedByc = donatedBycAmount.round();
      var donatedKarma = (donorAnalytics['totalKarma'] as num?)?.toInt() ?? 0;
      if (donatedByc == 0 && donatedKarma == 0) {
        try {
          final social = await UserSocialService.instance.getMyProfileSocialStats();
          donatedByc = social.donatedByc;
          donatedKarma = social.donatedKarma;
        } catch (_) {}
      }

      final receivedBycAmount =
          double.tryParse(creatorAnalytics['totalRaised']?.toString() ?? '') ??
          0.0;
      final receivedDonationsByc = receivedBycAmount.round();
      final receivedDonationsCount =
          (creatorAnalytics['totalDonations'] as num?)?.toInt() ??
          myCampaignsTotal;

      print('ProfileScreen: Loaded all counters in parallel');
      print('  Trades: $tradesTotal');
      print('  Gifts given: $giftsTotal');
      print('  Gifts received: $giftsClaimedTotal');
      print('  Donations: $donationsTotal');
      print('  Given BYC: $donatedByc');
      print('  Donation karma: $donatedKarma');
      print('  Received BYC: $receivedDonationsByc');
      print('  BYC Balance: $bycBalance');
      print('  Communities: $communitiesCount');

      Map<String, int> socialFollow = {};
      try {
        final social = await UserSocialService.instance.getMyProfileSocialStats();
        socialFollow = {
          'followers': social.followers,
          'following': social.following,
        };
        if (donatedByc == 0 && social.donatedByc > 0) {
          donatedByc = social.donatedByc;
        }
        if (donatedKarma == 0 && social.donatedKarma > 0) {
          donatedKarma = social.donatedKarma;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _userCounters = {
            'trades': tradesTotal,
            'gifts': giftsTotal,
            'giftsClaimed': giftsClaimedTotal,
            'donations': donationsTotal,
            'donatedByc': donatedByc,
            'donatedKarma': donatedKarma,
            'receivedDonations': receivedDonationsCount,
            'receivedDonationsByc': receivedDonationsByc,
            'byc': bycBalance,
            'communities': communitiesCount,
          };
          _statsLoading = false;
          
          // Update userProfile stats if profile is already loaded (preserve rating from API)
          if (userProfile != null) {
            final existingStats = userProfile!.stats;
            userProfile = userProfile!.copyWith(
              stats: ProfileStats(
                totalTrades: tradesTotal,
                successfulTrades: tradesTotal,
                totalGifts: giftsTotal,
                totalDonations: donationsTotal,
                totalCommunities: communitiesCount,
                totalFollowers: socialFollow['followers'] ?? existingStats.totalFollowers,
                totalFollowing: socialFollow['following'] ?? existingStats.totalFollowing,
                totalPosts: existingStats.totalPosts,
                totalLikes: existingStats.totalLikes,
                averageRating: existingStats.averageRating,
                totalReviews: existingStats.totalReviews,
              ),
            );
          }
          
          // Update cache metadata
          _lastCountersFetchAt = DateTime.now();
          _countersInitialized = true;
        });
        await _refreshTrustScoreFromApi();
      }
    } catch (e) {
      print('ProfileScreen: Error loading counters: $e');
      if (mounted) setState(() { _statsLoading = false; });
    }
  }

  /// Refresh followers, following, and Given BYC after follow/unfollow elsewhere.
  Future<void> _refreshSocialStats() async {
    try {
      final stats = await UserSocialService.instance.getMyProfileSocialStats();
      if (!mounted || userProfile == null) return;
      setState(() {
        final existing = userProfile!.stats;
        userProfile = userProfile!.copyWith(
          stats: ProfileStats(
            totalTrades: existing.totalTrades,
            successfulTrades: existing.successfulTrades,
            totalGifts: existing.totalGifts,
            totalDonations: existing.totalDonations,
            totalCommunities: existing.totalCommunities,
            totalFollowers: stats.followers,
            totalFollowing: stats.following,
            totalPosts: existing.totalPosts,
            totalLikes: existing.totalLikes,
            averageRating: existing.averageRating,
            totalReviews: existing.totalReviews,
          ),
        );
        _userCounters = {
          ..._userCounters,
          'donatedByc': stats.donatedByc,
          'donatedKarma': stats.donatedKarma,
        };
      });
    } catch (_) {
      // Non-fatal
    }
  }

  Future<void> _refreshTrustScoreFromApi() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final response = await apiClient.dio.get('/v1/users/me');
      final userData = response.data as Map<String, dynamic>;
      final profile = userData['profile'] as Map<String, dynamic>?;
      if (!mounted || userProfile == null || profile == null) return;
      setState(() {
        userProfile = userProfile!.copyWith(
          trustScore: trustScoreFromApi(profile),
        );
      });
    } catch (_) {
      // Non-fatal — profile still shows last known trust score
    }
  }

  /// Load user activity from API
  Future<void> _loadUserActivities({bool forceRefresh = false}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!forceRefresh && _activitiesInitialized && _lastActivitiesFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastActivitiesFetchAt!);
      if (cacheAge < _cacheDuration && _userActivities.isNotEmpty) {
        print('[ProfileScreen] Using cached activities (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    if (_activitiesLoading) return;
    
    try {
      setState(() {
        _activitiesLoading = true;
        _activitiesError = null;
      });

      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final activityService = ActivityApiService(apiClient);

      final response = await activityService.getUserActivity(
        page: 1,
        size: 20,
        forceRefresh: forceRefresh,
      );
      final activities = activityService.parseActivities(response['items'] ?? []);

      if (mounted) {
        setState(() {
          _userActivities = activities;
          _activitiesLoading = false;
          
          // Update cache metadata
          _lastActivitiesFetchAt = DateTime.now();
          _activitiesInitialized = true;
        });
      }
    } catch (e) {
      print('ProfileScreen: Error loading activities: $e');
      if (mounted) {
        setState(() {
          _activitiesError = GracefulErrors.userMessage(e);
          GracefulErrors.record(e, StackTrace.current, hint: 'ProfileScreen.activities');
          _activitiesLoading = false;
        });
      }
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _tabController == null) {
      return const Scaffold(
        body: BybataLoader(),
      );
    }

    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: SettingsUi.pageBackground(context),
        body: const BybataLoader(message: 'Loading profile...'),
      );
    }

    if (_loadError != null || userProfile == null) {
      final error = _loadError ?? 'Profile unavailable';
      return GracefulErrors.screen(
        error: error,
        title: error == 'Not logged in' ? 'Sign in required' : "Couldn't load profile",
        message: error == 'Not logged in'
            ? 'Please sign in to view your profile.'
            : GracefulErrors.userMessage(error),
        onRetry: error == 'Not logged in'
            ? null
            : () {
                setState(() => _loadError = null);
                _loadUserProfile(force: true);
                _loadUserCounters(force: true);
              },
        onGoBack: Navigator.canPop(context) ? () => Navigator.pop(context) : null,
      );
    }

    final pageBg = SettingsUi.pageBackground(context);

    return SafeScreen(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: pageBg,
        drawer: const AppSideDrawer(),
        body: RefreshIndicator(
          onRefresh: _onProfileRefresh,
          color: AppTheme.primaryColor,
          child: NestedScrollView(
            floatHeaderSlivers: false,
            clipBehavior: Clip.none,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            headerSliverBuilder: (innerContext, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: pageBg,
                    child: _buildProfileHeader(),
                  ),
                ),
                if (_needsProfileSetup)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: pageBg,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Material(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            leading: Icon(
                              Icons.info_outline,
                              color: AppColors.warning,
                            ),
                            title: const Text(
                              'Complete your profile',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                GuardedNavigator.push(context, 
                                  MaterialPageRoute(
                                    builder: (_) => EditProfileScreen(
                                      userProfile: userProfile!,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Edit'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    innerContext,
                  ),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfilePinnedTabDelegate(
                      backgroundColor: pageBg,
                      child: _buildFluidTabSwitcher(),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController!,
              clipBehavior: Clip.hardEdge,
              children: [
                _buildNestedTab(
                  key: const PageStorageKey<String>('profile_overview'),
                  slivers: _overviewTabSlivers(),
                ),
                _buildNestedTab(
                  key: const PageStorageKey<String>('profile_activity'),
                  slivers: _activityTabSlivers(),
                ),
                _buildAchievementsNestedTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Coordinates tab scroll with the profile header via [NestedScrollView].
  Widget _buildNestedTab({
    required Key key,
    required List<Widget> slivers,
  }) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: key,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            ...slivers,
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        );
      },
    );
  }

  List<Widget> _overviewTabSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            Row(
              children: [
                Expanded(child: _buildKarmaCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildTrustCard()),
              ],
            ),
            const SizedBox(height: 16),
            _buildBioCard(),
            const SizedBox(height: 16),
            _buildOverviewShortcuts(),
            const SizedBox(height: 16),
            _buildReferralCard(),
            const SizedBox(height: 20),
            Text('Your stats', style: _sectionTitleStyle(context)),
            const SizedBox(height: 12),
            _buildStatsGrid(),
          ]),
        ),
      ),
    ];
  }

  List<Widget> _activityTabSlivers() {
    if (_activitiesLoading && _userActivities.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: BybataLoadingIndicator(color: AppTheme.primaryColor)),
        ),
      ];
    }

    if (_activitiesError != null && _userActivities.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GracefulErrors.inline(
              error: _activitiesError!,
              title: "Couldn't load activity",
              onRetry: () => _loadUserActivities(forceRefresh: true),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            _buildDonationStatsCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent activity',
                    style: _sectionTitleStyle(context),
                  ),
                ),
                TextButton(
                  onPressed: () => GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const ActivityHistoryScreen(),
                    ),
                  ),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_userActivities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No activities yet',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else
              ..._userActivities.map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildActivityCardFromModel(activity),
                ),
              ),
          ]),
        ),
      ),
    ];
  }

  Widget _buildAchievementsNestedTab() {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_trophiesRefreshKey),
      future: _loadAchievementsFromApi(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildNestedTab(
            key: const PageStorageKey<String>('profile_trophies'),
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: const BybataLoader(),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return _buildNestedTab(
            key: const PageStorageKey<String>('profile_trophies'),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    const Text('Failed to load achievements'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return _buildNestedTab(
            key: const PageStorageKey<String>('profile_trophies'),
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No achievements')),
              ),
            ],
          );
        }

        final unlocked = data['unlocked'] as List? ?? [];
        final locked = data['locked'] as List? ?? [];

        return _buildNestedTab(
          key: const PageStorageKey<String>('profile_trophies'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAchievementHeader(data),
                  const SizedBox(height: 16),
                  if (unlocked.isNotEmpty) ...[
                    Text('Unlocked', style: _sectionTitleStyle(context)),
                    const SizedBox(height: 10),
                    ...unlocked.map((a) => _buildAchievementTile(a, true)),
                    const SizedBox(height: 8),
                  ],
                  if (locked.isNotEmpty) ...[
                    Text('Locked', style: _sectionTitleStyle(context)),
                    const SizedBox(height: 10),
                    ...locked.map((a) => _buildAchievementTile(a, false)),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onProfileRefresh() async {
    await _loadUserProfile(force: true);
    await _loadUserCounters(force: true);
    if (_currentTabIndex == 1) {
      await _loadUserActivities(forceRefresh: true);
    }
    if (_currentTabIndex == 2) {
      setState(() => _trophiesRefreshKey++);
    }
  }

  void _openProfileDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _buildProfileHeader() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = userProfile!;
    final topPad = Navigator.canPop(context)
        ? MediaQuery.paddingOf(context).top + 8
        : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad, 20, 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: isDark ? 0.28 : 0.14),
                    scheme.surface,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderIconButton(
                        icon: Icons.grid_view_rounded,
                        onTap: _openProfileDrawer,
                      ),
                      _buildHeaderIconButton(
                        icon: Icons.more_horiz_rounded,
                        onTap: _showActionMenu,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildProfileAvatar(profile, size: 96),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      VerifiedBadge(
                        isVerified: profile.isVerified,
                        size: 18,
                      ),
                    ],
                  ),
                  if (profile.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (!profile.isVerified) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _navigateToVerification,
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Get verified'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 14),
                  _buildQuickStatsRow(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildQuickActionChip(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: _navigateToEditProfile,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: _shareProfile,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Wallet',
                        onTap: () => WalletNavigator.toWalletHome(context),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        icon: Icons.star_outline_rounded,
                        label: 'Karma',
                        onTap: _navigateToKarmaScreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => KarmaNavigator.toEarnKarma(context),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: const Text(
                        'Learn and earn',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.karmaColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(UserProfile profile, {double size = 64}) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Text(
          profile.initials,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.35),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: profile.avatar != null && profile.avatar!.isNotEmpty
            ? CachedMediaImage(
                mediaKey: profile.avatar,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: placeholder,
                errorWidget: placeholder,
              )
            : placeholder,
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    final displayName =
        '${userProfile!.firstName} ${userProfile!.lastName}'.trim();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(
          '${userProfile!.stats.totalFollowers}',
          'Followers',
          onTap: () => _openFollowList(FollowListType.followers, displayName),
        ),
        Container(
          width: 1,
          height: 24,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        _buildStatItem(
          '${userProfile!.stats.totalFollowing}',
          'Following',
          onTap: () => _openFollowList(FollowListType.following, displayName),
        ),
        Container(
          width: 1,
          height: 24,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        _buildStatItem(userProfile!.stats.averageRating.toStringAsFixed(1), 'Rating'),
      ],
    );
  }

  void _openFollowList(FollowListType type, String userName) {
    final userId = userProfile?.id;
    if (userId == null || userId.isEmpty) return;
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserFollowersListScreen(
          userId: userId,
          userName: userName.isNotEmpty ? userName : 'You',
          type: type,
        ),
      ),
    ).then((_) {
      if (mounted) _refreshSocialStats();
    });
  }

  Widget _buildStatItem(String value, String label, {VoidCallback? onTap}) {
    final content = Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildFluidTabSwitcher() {
    const labels = ['Overview', 'Activity', 'Trophies'];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            alignment: Alignment(-1.0 + (_currentTabIndex * (2.0 / (labels.length - 1))), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(labels.length, (index) => Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                   setState(() => _currentTabIndex = index);
                   _tabController!.animateTo(index);
                },
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontWeight: _currentTabIndex == index
                          ? FontWeight.w900
                          : FontWeight.w600,
                      color: _currentTabIndex == index
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    child: Text(labels[index]),
                  ),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewShortcuts() {
    return SettingsGroupCard(
      title: 'QUICK LINKS',
      children: [
        SettingsNavTile(
          icon: Icons.history_rounded,
          title: 'Activity history',
          subtitle: 'See everything you have done',
          onTap: () => GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => const ActivityHistoryScreen(),
            ),
          ),
        ),
        SettingsNavTile(
          icon: Icons.emoji_events_outlined,
          title: 'All trophies',
          subtitle: 'Browse your full achievement list',
          onTap: () => GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => const profile_achievements.AchievementsScreen(),
            ),
          ),
        ),
        SettingsNavTile(
          icon: Icons.verified_outlined,
          title: 'Verification',
          subtitle: userProfile!.isVerified
              ? 'Your account is verified'
              : 'Verify to build trust',
          onTap: _navigateToVerification,
        ),
        SettingsNavTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Privacy, notifications, account',
          onTap: _navigateToSettings,
        ),
      ],
    );
  }

  Widget _buildReferralCard() {
    return FutureBuilder<ReferralStats>(
      future: ReferralApiService.create().then((s) => s.getMyReferralStats()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: const BybataLoader(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();
        return ReferralShareCard(stats: snapshot.data!);
      },
    );
  }

  Widget _buildBioCard() {
    final scheme = Theme.of(context).colorScheme;
    return SettingsGroupCard(
      title: 'ABOUT',
      children: [
        if (userProfile!.bio != null && userProfile!.bio!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              userProfile!.bio!,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.8),
                height: 1.45,
                fontSize: 14,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Add a short bio so others know you better.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        if (userProfile!.location != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    userProfile!.location!,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        if (userProfile!.interests.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: userProfile!.interests.map((interest) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.communityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    interest,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.communityColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        SettingsNavTile(
          icon: Icons.edit_outlined,
          title: 'Edit profile',
          subtitle: 'Photo, bio, and details',
          onTap: _navigateToEditProfile,
        ),
      ],
    );
  }

  Widget _buildKarmaCard() {
    return Consumer<KarmaProvider>(
      builder: (context, karmaProvider, child) {
        return _buildMetricCard(
          accent: AppTheme.karmaColor,
          icon: Icons.star_rounded,
          value: '${karmaProvider.totalKarma}',
          label: 'Karma',
          onTap: _navigateToKarmaScreen,
        );
      },
    );
  }

  Widget _buildTrustCard() {
    if (userProfile == null) return const SizedBox.shrink();
    final trust = userProfile!.trustScore;
    return _buildMetricCard(
      accent: AppTheme.successColor,
      icon: Icons.shield_outlined,
      value: formatTrustScoreDisplay(trust.score),
      label: trust.levelName,
      subtitle: 'Trust score',
      onTap: () => KarmaNavigator.toTrustLevel(context),
    );
  }

  Widget _buildMetricCard({
    required Color accent,
    required IconData icon,
    required String value,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
        child: _profileCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (userProfile == null) return const SizedBox.shrink();
    final stats = [
      ('Trades', Icons.swap_horiz, AppTheme.tradeColor, _userCounters['trades'] ?? 0, 'Trades'),
      ('Gifts', Icons.card_giftcard, AppTheme.giftColor, _userCounters['gifts'] ?? 0, 'Gifts'),
      ('Received', Icons.redeem, AppTheme.giftColor.withValues(alpha: 0.85), _userCounters['giftsClaimed'] ?? 0, 'Gifts claimed'),
      ('Donations', Icons.favorite, AppTheme.donationColor, _userCounters['donations'] ?? 0, 'Donations'),
      ('Given BYC', Icons.volunteer_activism, AppTheme.karmaColor, _userCounters['donatedByc'] ?? 0, 'Given BYC'),
      ('Balance', Icons.account_balance_wallet, AppTheme.successColor, _userCounters['byc'] ?? 0, 'BYC'),
    ];

    if (_statsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: const BybataLoader(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final (label, icon, color, value, navKey) = stats[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onCounterTap(navKey as String),
            borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
            child: _profileCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (color as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon as IconData, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          label as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build activity card from Activity model
  Widget _buildActivityCardFromModel(Activity activity) {
    final icon = _getActivityIcon(activity.type);
    final color = _getActivityColor(activity.type);
    final timeAgo = _getTimeAgo(activity.createdAt);
    final karmaText = activity.karmaPoints != null 
        ? '+${activity.karmaPoints} KARMA' 
        : '';

    final scheme = Theme.of(context).colorScheme;
    return _profileCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      radius: 16,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          activity.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${activity.description} • $timeAgo',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: karmaText.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  karmaText,
                  style: const TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// Get icon for activity type
  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.trade:
        return Icons.swap_horiz;
      case ActivityType.gift:
        return Icons.card_giftcard;
      case ActivityType.donation:
        return Icons.favorite;
      case ActivityType.community:
        return Icons.groups;
      case ActivityType.post:
        return Icons.article;
      case ActivityType.comment:
        return Icons.comment;
      case ActivityType.like:
        return Icons.thumb_up;
      case ActivityType.follow:
        return Icons.person_add;
      case ActivityType.achievement:
        return Icons.emoji_events;
      case ActivityType.verification:
        return Icons.verified_user;
      case ActivityType.karma:
        return Icons.star;
    }
  }

  /// Get color for activity type
  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.trade:
        return AppTheme.tradeColor;
      case ActivityType.gift:
        return AppTheme.giftColor;
      case ActivityType.donation:
        return AppTheme.donationColor;
      case ActivityType.community:
        return AppTheme.communityColor;
      case ActivityType.post:
        return Theme.of(context).colorScheme.primary;
      case ActivityType.comment:
        return Theme.of(context).colorScheme.secondary;
      case ActivityType.like:
        return Theme.of(context).colorScheme.tertiary;
      case ActivityType.follow:
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.8);
      case ActivityType.achievement:
        return AppTheme.karmaColor;
      case ActivityType.verification:
        return AppTheme.successColor;
      case ActivityType.karma:
        return AppTheme.karmaColor;
    }
  }

  /// Format time ago
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  Widget _buildDonationStatsCard() {
    return _profileCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.donationColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppTheme.donationColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Donation impact',
                style: _sectionTitleStyle(context),
              ),
            ],
          ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildDonationStatColumn(
                    "Given",
                    _userCounters['donations'] ?? 0,
                    "${_userCounters['donatedByc']} BYC · +${_userCounters['donatedKarma'] ?? 0} KARMA",
                    AppTheme.karmaColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: _buildDonationStatColumn(
                    "Received",
                    _userCounters['receivedDonations'] ?? 0,
                    "${_userCounters['receivedDonationsByc']} BYC",
                    AppTheme.successColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDonationStatColumn(String label, int count, String amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActivityCard(String title, String subtitle, IconData icon, Color color, String time, String karma) {
    return _profileCard(
      radius: 16,
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("$subtitle • $time", style: const TextStyle(fontSize: 11)),
        trailing: Text(
          karma,
          style: TextStyle(
            color: AppTheme.successColor,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementHeader(Map<String, dynamic> data) {
    final unlockedCount = data['unlockedCount'] as int? ?? 0;
    final total = data['total'] as int? ?? 1;
    
    // Safely calculate percentage, avoiding division by zero and NaN/Infinity
    final percentage = total > 0 
        ? ((unlockedCount / total) * 100).clamp(0.0, 100.0).round()
        : 0;
    
    return _profileCard(
      backgroundColor: Theme.of(context).colorScheme.onSurface,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: AppTheme.karmaColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$unlockedCount / $total Unlocked',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementTile(dynamic item, bool unlocked) {
    final scheme = Theme.of(context).colorScheme;
    final accent =
        unlocked ? AppTheme.successColor : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _profileCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        radius: 16,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.lock_outline,
              color: accent,
              size: 20,
            ),
          ),
          title: Text(
            item['name'] ?? 'Achievement',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: unlocked
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          subtitle: Text(
            item['description'] ?? '',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          trailing: unlocked
              ? Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20)
              : null,
        ),
      ),
    );
  }

  // --- HELPERS ---
  
  /// Load achievements from API
  Future<Map<String, dynamic>> _loadAchievementsFromApi() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final achievementsService = AchievementsApiService(apiClient);
      
      final response = await achievementsService.getUserAchievements();
      return achievementsService.parseAchievementStats(response);
    } catch (e) {
      print('ProfileScreen: Error loading achievements: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _loadAchievements() async {
     try {
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final response = await apiClient.dio.get('/v1/karma/achievements');
      return response.data as Map<String, dynamic>;
    } catch (e) { rethrow; }
  }

  void _showActionMenu() {
    final profile = userProfile;
    if (profile == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) => _ProfileActionSheet(
        displayName: profile.displayName,
        email: profile.email,
        isVerified: profile.isVerified,
        onEditProfile: () {
          Navigator.pop(sheetContext);
          _navigateToEditProfile();
        },
        onVerifyAccount: () {
          Navigator.pop(sheetContext);
          _navigateToVerification();
        },
        onSettings: () {
          Navigator.pop(sheetContext);
          _navigateToSettings();
        },
        onLogout: () {
          Navigator.pop(sheetContext);
          _confirmLogout();
        },
      ),
    );
  }

  void _navigateToEditProfile() {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userProfile: userProfile!),
      ),
    ).then((v) {
      // EditProfileScreen returns `true` on successful save; reload fresh data
      if (v == true) {
        _loadUserProfile();
        _loadUserCounters();
      }
    });
  }
  void _navigateToVerification() => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => VerificationScreen(userProfile: userProfile!))).then((v) {
    if (v == true) _loadUserProfile();
    else if (v != null && v is UserProfile) setState(() => userProfile = v);
  });
  void _navigateToSettings() => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => EnhancedSettingsScreen(userProfile: userProfile!))).then((v) { if(v!=null) setState(() => userProfile = v); });
  void _navigateToKarmaScreen() {
    // Initialize karma provider before navigation
    final karmaProvider = Provider.of<KarmaProvider>(context, listen: false);
    karmaProvider.initialize().then((_) {
      GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const KarmaScreen()));
    }).catchError((e) {
      AppToast.show(context, 'Failed to load karma data: $e');
    });
  }
  void _shareProfile() {
    final profile = userProfile;
    if (profile == null) {
      AppToast.show(context, 'Profile not loaded yet');
      return;
    }
    ShareUtils.shareProfile(
      context,
      displayName: profile.displayName,
      userId: profile.id,
    );
  }
  
  void _confirmLogout() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final bottomPad = MediaQuery.paddingOf(sheetContext).bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPad + 14),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: scheme.error.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.logout_rounded, color: scheme.error, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign out?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can sign back in anytime with your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _logout();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Sign out',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await AppRoutes.completeSignOut(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, GracefulErrors.userMessage(e));
    }
  }

  void _onCounterTap(String label) {
    switch (label) {
      case 'Trades': AppRoutes.navigateToMyTrades(context); break;
      case 'Gifts': AppRoutes.navigateToMyGifts(context); break;
      case 'Gifts claimed': AppRoutes.navigateToGiftHistory(context); break;
      case 'Donations': AppRoutes.navigateToDonationHistory(context); break;
      case 'Given BYC':
      case 'Donated BYC':
        AppRoutes.navigateToDonationHistory(context);
        break;
      case 'BYC': WalletNavigator.toWalletHome(context); break;
    }
  }
}

/// Floating account actions sheet from the profile header menu.
class _ProfileActionSheet extends StatelessWidget {
  final String displayName;
  final String email;
  final bool isVerified;
  final VoidCallback onEditProfile;
  final VoidCallback onVerifyAccount;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _ProfileActionSheet({
    required this.displayName,
    required this.email,
    required this.isVerified,
    required this.onEditProfile,
    required this.onVerifyAccount,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPad + 14),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.16),
              blurRadius: 32,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: isDark ? 0.28 : 0.14),
                      AppTheme.primaryColor.withValues(alpha: isDark ? 0.06 : 0.03),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Account options',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    _ProfileActionTile(
                      icon: Icons.edit_outlined,
                      label: 'Edit profile',
                      hint: 'Update photo, name & bio',
                      color: AppTheme.primaryColor,
                      onTap: onEditProfile,
                    ),
                    const SizedBox(height: 10),
                    _ProfileActionTile(
                      icon: isVerified
                          ? Icons.verified_rounded
                          : Icons.verified_outlined,
                      label: isVerified ? 'Verification' : 'Verify account',
                      hint: isVerified
                          ? 'Your account is verified'
                          : 'Build trust with verification',
                      color: AppTheme.tradeColor,
                      onTap: onVerifyAccount,
                      trailing: isVerified
                          ? Icon(Icons.check_circle_rounded,
                              size: 20, color: AppTheme.successColor)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _ProfileActionTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      hint: 'Privacy, notifications & more',
                      color: AppTheme.communityColor,
                      onTap: onSettings,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _ProfileActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  hint: 'Log out of this device',
                  color: scheme.error,
                  onTap: onLogout,
                  isDestructive: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDestructive
                ? color.withValues(alpha: isDark ? 0.12 : 0.06)
                : color.withValues(alpha: isDark ? 0.14 : 0.07),
            border: Border.all(
              color: color.withValues(alpha: isDestructive ? 0.28 : 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: isDark ? 0.85 : 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDestructive ? color : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.35),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opaque pinned tab bar for [NestedScrollView] — blocks content from showing through.
class _ProfilePinnedTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color backgroundColor;

  _ProfilePinnedTabDelegate({
    required this.child,
    required this.backgroundColor,
  });

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfilePinnedTabDelegate oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
  }
}