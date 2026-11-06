import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../common/widgets/verified_badge.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/guest_browse_helpers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../trade/models/trade_models.dart';
import '../../community/screens/dm_inbox_screen.dart';
import '../../wallet/screens/transfer_byc_screen.dart';
import '../../trade/screens/trade_details_loader.dart';
import '../../gifting/screens/gift_details_loader.dart';
import '../../donations/screens/campaign_details_loader.dart';
import 'user_items_list_screen.dart';
import 'user_followers_list_screen.dart';
import '../widgets/report_user_sheet.dart';
import '../../../core/errors/graceful_errors.dart';
import '../services/profile_social_notifier.dart';
import '../services/user_social_service.dart';
import '../../../core/utils/trust_score_utils.dart';
import '../../../core/utils/profile_location_utils.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final TradeUser? user; 
  
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.user,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  TradeUser? _user;
  bool _isLoading = true;
  Object? _loadError;
  bool _isFollowing = false;
  List<Map<String, dynamic>> _userTrades = [];
  List<Map<String, dynamic>> _userGifts = [];
  List<Map<String, dynamic>> _userCampaigns = [];
  List<Map<String, dynamic>> _userReviews = [];
  int _totalReviews = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  int _donatedByc = 0;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isGiftBYCNavigating = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapProfile());
  }

  Future<void> _bootstrapProfile() async {
    if (!mounted) return;
    if (!context.read<AuthProvider>().isAuthenticated) {
      setState(() => _isLoading = false);
      AppRoutes.showLoginRequired(context);
      return;
    }
    await _initializeProfile();
  }

  Widget _buildAvatar(Color primaryColor) {
    final avatarKey = _user?.avatar;
    final initials = _user?.name.isNotEmpty == true
        ? _user!.name.substring(0, 1).toUpperCase()
        : 'U';
    final fallback = SizedBox(
      width: 80,
      height: 80,
      child: CircleAvatar(
        radius: 40,
        backgroundColor: primaryColor.withValues(alpha: 0.1),
        child: Text(
          initials,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
        ),
      ),
    );
    if (avatarKey == null || avatarKey.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: CachedMediaImage(
        mediaKey: avatarKey,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: fallback,
        errorWidget: fallback,
      ),
    );
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({required Widget child, Color? color, double radius = 24}) {
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }

  // --- API CALLS ---
  Future<void> _initializeProfile() async {
    setState(() { _isLoading = true; });
    try {
      await _fetchUserProfile();
      await Future.wait([
        _fetchUserTrades(),
        _fetchUserGifts(),
        _fetchUserCampaigns(),
        _fetchUserReviews(),
        _fetchFollowCounts(),
        _checkFollowingStatus(),
      ]);
      if (Provider.of<AuthProvider>(context, listen: false).currentUser?.id != widget.userId) {
        await _checkLikeStatus();
      }
    } catch (e, st) {
      GracefulErrors.record(e, st, hint: 'UserProfileScreen');
      if (mounted) {
        setState(() => _loadError = e);
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  
  Future<void> _fetchUserProfile() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      
      final response = await apiClient.get('/v1/users/${widget.userId}');
      final userData = response.data as Map<String, dynamic>;
      final profile = userData['profile'] as Map<String, dynamic>? ?? {};
      
      // Map API response to TradeUser model
      final displayName = profile['displayName'] as String? ?? 'User';
      final email = userData['email'] as String? ?? '';
      final bio = profile['bio'] as String?;
      final location = ProfileLocationUtils.fromProfile(profile);
      final avatarKey = profile['avatarKey'] as String?;
      final karmaPoints = (profile['karmaPoints'] as num?)?.toInt() ?? 0;
      final trustParsed = trustScoreFromApi(profile);
      final trustScore = trustParsed.score;
      final rating = (profile['rating'] as num?)?.toDouble() ?? 0.0;
      final completedTrades = (profile['completedTrades'] as num?)?.toInt() ?? 0;
      _applySocialStatsFromProfile(profile);
      _totalReviews = (profile['totalReviews'] as num?)?.toInt() ?? 0;
      final kycStatus = profile['kycStatus'] as String?;
      final isVerified = kycStatus == 'VERIFIED';
      final createdAtStr = userData['createdAt'] as String?;
      final joinedDate = createdAtStr != null 
          ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
          : DateTime.now();
      
      _user = TradeUser(
        id: widget.userId,
        name: displayName,
        username: email,
        avatar: avatarKey,
        rating: rating,
        completedTrades: completedTrades,
        joinedDate: joinedDate,
        isVerified: isVerified,
        location: location,
        bio: bio,
        karmaPoints: karmaPoints,
        trustBadges: const [], // Trust badges not available in API yet
        trustScore: trustScore,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> _fetchUserTrades() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      
      final response = await apiClient.get(
        '/v1/trades',
        queryParameters: {
          'ownerId': widget.userId,
          'page': 1,
          'size': 20,
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      
      _userTrades = items.map<Map<String, dynamic>>((trade) {
        final owner = trade['owner'] as Map<String, dynamic>?;
        final ownerProfile = owner?['profile'] as Map<String, dynamic>?;
        final category = trade['category'] as String? ?? 'OTHERS';
        final status = trade['status'] as String? ?? 'OPEN';
        final createdAtStr = trade['createdAt'] as String?;
        final createdAt = createdAtStr != null 
            ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
            : DateTime.now();
        
        return {
          'id': trade['id'] as String? ?? '',
          'title': trade['title'] as String? ?? 'Untitled',
          'status': status,
          'category': category,
          'createdAt': createdAt,
          'ownerName': ownerProfile?['displayName'] as String? ?? 'User',
        };
      }).toList();
    } catch (e) {
      _userTrades = [];
      // Silently fail - trades are optional
    }
  }

  Future<void> _fetchUserGifts() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);

      final response = await apiClient.get(
        '/v1/gifts',
        queryParameters: {
          'giverId': widget.userId,
          'page': 1,
          'size': 20,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];

      _userGifts = items.map<Map<String, dynamic>>((gift) {
        final raw = gift is Map<String, dynamic> ? gift : Map<String, dynamic>.from(gift as Map);
        final mediaKeys = <String>[];
        if (raw['mediaKeys'] is List) {
          for (final k in raw['mediaKeys'] as List) {
            if (k != null) mediaKeys.add(k.toString());
          }
        }
        return {
          'id': raw['id']?.toString() ?? '',
          'title': raw['title']?.toString() ?? 'Untitled',
          'status': raw['status']?.toString() ?? 'ACTIVE',
          'category': raw['category']?.toString() ?? 'OTHERS',
          'mediaKeys': mediaKeys,
        };
      }).toList();
    } catch (e) {
      _userGifts = [];
    }
  }

  Future<void> _fetchUserCampaigns() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);

      final response = await apiClient.get(
        '/v1/campaigns',
        queryParameters: {
          'founderId': widget.userId,
          'page': 1,
          'size': 20,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];

      _userCampaigns = items.map<Map<String, dynamic>>((campaign) {
        final raw = campaign is Map<String, dynamic> ? campaign : Map<String, dynamic>.from(campaign as Map);
        final mediaKeys = <String>[];
        final thumb = raw['thumbnailKey']?.toString();
        if (thumb != null && thumb.isNotEmpty) mediaKeys.add(thumb);
        if (raw['mediaKeys'] is List) {
          for (final k in raw['mediaKeys'] as List) {
            if (k != null) mediaKeys.add(k.toString());
          }
        }
        return {
          'id': raw['id']?.toString() ?? '',
          'title': raw['title']?.toString() ?? 'Untitled',
          'status': raw['status']?.toString() ?? 'ACTIVE',
          'category': raw['category']?.toString() ?? 'OTHERS',
          'mediaKeys': mediaKeys,
        };
      }).toList();
    } catch (e) {
      _userCampaigns = [];
    }
  }

  void _applySocialStatsFromProfile(Map<String, dynamic> profile) {
    _followersCount = (profile['followersCount'] as num?)?.toInt() ?? 0;
    _followingCount = (profile['followingCount'] as num?)?.toInt() ?? 0;
    _donatedByc = (profile['donatedByc'] as num?)?.toInt() ?? 0;
  }

  Future<void> _fetchFollowCounts() async {
    try {
      final stats =
          await UserSocialService.instance.getProfileSocialStats(widget.userId);
      if (mounted) {
        setState(() {
          _followersCount = stats.followers;
          _followingCount = stats.following;
          _donatedByc = stats.donatedByc;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkFollowingStatus() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null || currentUser.id == widget.userId) {
      _isFollowing = false;
      return;
    }
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final response = await apiClient.get('/v1/users/${widget.userId}/follow-status');
      final data = response.data as Map<String, dynamic>;
      if (mounted) setState(() => _isFollowing = data['isFollowing'] == true);
    } catch (_) {
      _isFollowing = false;
    }
  }

  Future<void> _fetchUserReviews() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final response = await apiClient.get(
        '/v1/users/${widget.userId}/reviews',
        queryParameters: {'page': 1, 'size': 20},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _userReviews = items.map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r as Map)).toList();
          _totalReviews = (data['total'] as num?)?.toInt() ?? _userReviews.length;
        });
      }
    } catch (_) {
      _userReviews = [];
    }
  }

  Future<void> _checkLikeStatus() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null || currentUser.id == widget.userId) return;
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final response = await apiClient.get('/v1/users/${widget.userId}/like-status');
      final data = response.data as Map<String, dynamic>;
      if (mounted) setState(() => _isLiked = data['isLiked'] == true);
    } catch (_) {
      _isLiked = false;
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) {
      AppToast.show(context, 'Sign in to like profiles');
      return;
    }
    if (currentUser.id == widget.userId) return;
    final wasLiked = _isLiked;
    setState(() => _isLiked = !_isLiked);
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      if (wasLiked) {
        await apiClient.delete('/v1/users/${widget.userId}/like');
        if (mounted) setState(() => _likesCount = (_likesCount - 1).clamp(0, 999999));
      } else {
        await apiClient.post('/v1/users/${widget.userId}/like');
        if (mounted) setState(() => _likesCount++);
      }
      if (mounted) {
        AppToast.show(context, _isLiked ? 'Profile liked! +5 karma for them' : 'Profile unliked');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLiked = wasLiked);
        AppToast.show(context, 'Failed: ${e.toString()}');
      }
    }
  }
  
  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = scheme.primary;
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;

    if (!isAuthed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const GuestSignInPrompt(
          title: 'Sign in to view profiles',
          message:
              'Member profiles, messages, and activity are available after you sign in.',
        ),
      );
    }
    
    if (_isLoading) {
      return const Scaffold(body: BybataLoader());
    }
    if (_loadError != null || _user == null) {
      return GracefulErrors.screen(
        error: _loadError ?? 'User not found',
        title: "Couldn't load profile",
        onRetry: () {
          setState(() {
            _loadError = null;
            _isLoading = true;
          });
          _initializeProfile();
        },
        onGoBack: () => Navigator.maybePop(context),
      );
    }
    
    return Scaffold(
      backgroundColor: scheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _build3DSliverAppBar(primaryColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // FIX: Centralized Header
                  _buildProfileHeaderCard(primaryColor),
                  const SizedBox(height: 24),
                  _buildActionButtons(primaryColor),
                  const SizedBox(height: 24),
                  _buildStatsSection(primaryColor),
                  const SizedBox(height: 16),
                  _buildFollowersFollowingSection(primaryColor),
                  const SizedBox(height: 24),
                  _buildActiveTradesSection(primaryColor),
                  const SizedBox(height: 24),
                  _buildActiveGiftsSection(primaryColor),
                  const SizedBox(height: 24),
                  _buildActiveCampaignsSection(primaryColor),
                  const SizedBox(height: 24),
                  _buildReviewsSection(primaryColor),
                  const SizedBox(height: 24),
                  _buildTrustSafetySection(primaryColor),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _build3DSliverAppBar(Color primaryColor) {
    return SliverAppBar(
      expandedHeight: 80, // Reduced height since avatar is in the body card now
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.background,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: _build3DContainer(
            radius: 12,
            child: Icon(
              Icons.arrow_back_ios_new,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          _user?.name ?? 'User Profile',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileHeaderCard(Color primaryColor) {
    return _build3DContainer(
      child: Padding(
        padding: const EdgeInsets.all(24),
        // FIX: Ensure full width and centering
        child: SizedBox(
          width: double.infinity, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // FIX: Explicit center alignment
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: _buildAvatar(primaryColor),
                  ),
                  VerifiedBadge(isVerified: _user?.isVerified == true, size: 22, showTooltip: true),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _user?.name ?? 'User',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  VerifiedBadgeInline(isVerified: _user?.isVerified == true, size: 20),
                ],
              ),
              if (_user?.location != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // FIX: Center row items
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _user!.location!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]
                ),
              ],
              const SizedBox(height: 16),
              if (_user?.bio != null) 
                Text(
                  _user!.bio!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 16),
              if (_user?.trustBadges.isNotEmpty == true)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center, // FIX: Center wrap items
                  children: _user!.trustBadges.map((badge) => _buildBadgePill(badge)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBadgePill(TrustBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: badge.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(badge.icon, size: 12, color: badge.color),
        const SizedBox(width: 4),
        Text(badge.title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badge.color)),
      ]),
    );
  }
  
  Widget _buildActionButtons(Color primaryColor) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser?.id == _user?.id) return const SizedBox.shrink();
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _messageUser,
                child: _build3DContainer(
                  color: Theme.of(context).colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        "Message",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _toggleFollow,
                child: _buildFollowButton(primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _toggleLike,
              child: _build3DContainer(
                radius: 16,
                color: _isLiked ? AppTheme.karmaColor.withValues(alpha: 0.2) : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? AppTheme.karmaColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _showMoreOptions,
              child: _build3DContainer(
                radius: 16,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Gift BYC Button
        GestureDetector(
          onTap: _giftBYC,
          child: _build3DContainer(
            color: AppTheme.karmaColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.card_giftcard,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Gift BYC",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatsSection(Color primaryColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                'Trades',
                '${_user?.completedTrades ?? 0}',
                Icons.swap_horiz,
                AppTheme.tradeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatTile(
                'Rating',
                _user?.rating.toStringAsFixed(1) ?? '0.0',
                Icons.star,
                AppTheme.karmaColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatTile(
                'Reviews',
                '$_totalReviews',
                Icons.rate_review,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                'Given BYC',
                '$_donatedByc',
                Icons.volunteer_activism,
                AppTheme.karmaColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFollowButton(Color primaryColor) {
    final following = _isFollowing;
    final labelStyle = TextStyle(
      color: primaryColor,
      fontWeight: FontWeight.bold,
      fontSize: 16,
      height: 1.1,
    );

    return _build3DContainer(
      color: following ? primaryColor.withValues(alpha: 0.12) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Row(
              key: ValueKey<bool>(following),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  following
                      ? Icons.check_rounded
                      : Icons.person_add_alt_1_rounded,
                  size: 18,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  following ? 'Following' : 'Follow',
                  style: labelStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return _build3DContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowersFollowingSection(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _viewFollowers,
            child: _build3DContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$_followersCount',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Followers',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _viewFollowing,
            child: _build3DContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_alt_1_outlined, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$_followingCount',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Following',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveTradesSection(Color primaryColor) {
    final activeTrades = _userTrades.where((trade) {
      final status = trade['status'] as String? ?? '';
      return status == 'OPEN' || status == 'Active';
    }).toList();
    if (activeTrades.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Active Trades (${activeTrades.length})", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          TextButton(onPressed: _viewAllTrades, child: Text("View All", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: activeTrades.length,
            itemBuilder: (context, index) {
              final trade = activeTrades[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    final id = trade['id']?.toString() ?? '';
                    if (id.isNotEmpty) {
                      GuardedNavigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => TradeDetailsLoader(tradeId: id),
                        ),
                      );
                    }
                  },
                  child: SizedBox(
                    width: 140,
                    child: _build3DContainer(
                      radius: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.category, color: primaryColor.withValues(alpha: 0.5), size: 24),
                            const Spacer(),
                            Text(trade['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              trade['category'],
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveGiftsSection(Color primaryColor) {
    final activeGifts = _userGifts.where((g) {
      final s = g['status']?.toString() ?? '';
      return s == 'ACTIVE' || s == 'OPEN' || s.isEmpty;
    }).toList();
    if (activeGifts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Gifts (${activeGifts.length})", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          TextButton(onPressed: _viewAllGifts, child: Text("View All", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: activeGifts.length,
            itemBuilder: (context, index) {
              final gift = activeGifts[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    final id = gift['id']?.toString() ?? '';
                    if (id.isNotEmpty) {
                      GuardedNavigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => GiftDetailsLoader(giftId: id),
                        ),
                      );
                    }
                  },
                  child: SizedBox(
                    width: 140,
                    child: _build3DContainer(
                      radius: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.card_giftcard, color: AppTheme.karmaColor.withValues(alpha: 0.8), size: 24),
                            const Spacer(),
                            Text(gift['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              gift['category'] ?? 'Gift',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCampaignsSection(Color primaryColor) {
    final activeCampaigns = _userCampaigns.where((c) {
      final s = c['status']?.toString() ?? '';
      return s == 'ACTIVE' || s == 'OPEN' || s.isEmpty;
    }).toList();
    if (activeCampaigns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Donations (${activeCampaigns.length})", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          TextButton(onPressed: _viewAllCampaigns, child: Text("View All", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: activeCampaigns.length,
            itemBuilder: (context, index) {
              final campaign = activeCampaigns[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    final id = campaign['id']?.toString() ?? '';
                    if (id.isNotEmpty) {
                      GuardedNavigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => CampaignDetailsLoader(campaignId: id),
                        ),
                      );
                    }
                  },
                  child: SizedBox(
                    width: 140,
                    child: _build3DContainer(
                      radius: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.volunteer_activism, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8), size: 24),
                            const Spacer(),
                            Text(campaign['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              campaign['category'] ?? 'Campaign',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildReviewsSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Reviews (${_userReviews.length})", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          if (_userReviews.isNotEmpty) TextButton(onPressed: _viewAllReviews, child: Text("View All", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        if (_userReviews.isEmpty)
          _build3DContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  "No reviews yet",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          )
        else 
          Column(children: _userReviews.take(2).map((r) => _buildReviewItem(r)).toList()),
      ],
    );
  }
  
  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _build3DContainer(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            child: Text(
              (review['reviewer']?.toString() ?? 'U').substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          title: Text(review['reviewer']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(review['comment']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 14, color: AppTheme.karmaColor),
              Text(
                review['rating'].toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTrustSafetySection(Color primaryColor) {
    return _build3DContainer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTrustRow("Identity Verified", _user?.isVerified == true, Icons.verified_user),
            const Divider(),
            _buildTrustRow("Responsive Trader", true, Icons.flash_on),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustRow(String label, bool isActive, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: isActive
              ? AppTheme.successColor
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const Spacer(),
        if (isActive) Icon(Icons.check_circle, color: AppTheme.successColor, size: 18),
      ],
    );
  }

  // --- ACTIONS ---
  Color _getTrustColor(double score) => score >= 0.8
      ? AppTheme.successColor
      : (score >= 0.6
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary);
  
  void _messageUser() {
    if (AppRoutes.requireSignIn(context)) return;
    if (_user == null) {
      AppToast.show(context, "User information not available");
      return;
    }
    
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => DMInboxScreen(
          partnerId: widget.userId,
          partnerName: _user!.name,
        ),
      ),
    );
  }
  
  void _giftBYC() async {
    if (AppRoutes.requireSignIn(context)) return;
    if (_isGiftBYCNavigating) return;
    if (_user == null) {
      AppToast.show(context, "User information not available");
      return;
    }
    _isGiftBYCNavigating = true;
    try {
      // Fetch user email if not already available
      String? recipientEmail = _user!.username;
      if (recipientEmail == null || recipientEmail.isEmpty || !recipientEmail.contains('@')) {
        // Try to fetch from API if username doesn't look like an email
        try {
          final baseUrl = await EnvConfig.getBaseUrl();
          final storage = const FlutterSecureStorage();
          final apiClient = ApiClient(baseUrl, storage);
          final response = await apiClient.get('/v1/users/${widget.userId}');
          final userData = response.data as Map<String, dynamic>;
          recipientEmail = userData['email'] as String? ?? recipientEmail;
        } catch (e) {
          // Fallback to username if API call fails
        }
      }

      if (recipientEmail == null || recipientEmail.isEmpty) {
        AppToast.show(context, "Unable to get recipient email");
        return;
      }

      // Navigate to transfer screen with recipient details pre-filled
      if (!mounted) return;
      await GuardedNavigator.push(context,
        MaterialPageRoute(
          builder: (_) => TransferBYCScreen(
            recipientId: widget.userId,
            recipientEmail: recipientEmail,
            recipientName: _user!.name,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGiftBYCNavigating = false);
    }
  }
  void _toggleFollow() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) {
      AppToast.show(context, 'Sign in to follow users');
      return;
    }
    if (currentUser.id == widget.userId) return;

    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !_isFollowing);

    try {
      if (wasFollowing) {
        await UserSocialService.instance.unfollow(widget.userId);
      } else {
        await UserSocialService.instance.follow(widget.userId);
      }
      await _fetchFollowCounts();
      ProfileSocialNotifier.instance.notifyFollowChanged();
      if (mounted) {
        AppToast.show(context, _isFollowing ? 'Followed' : 'Unfollowed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = wasFollowing);
        AppToast.error(context, GracefulErrors.userMessage(e));
      }
    }
  }
  void _showMoreOptions() {
    showModalBottomSheet(context: context, builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.block), title: const Text("Block"), onTap: () { Navigator.pop(context); _blockUser(); }),
      ListTile(leading: const Icon(Icons.flag), title: const Text("Report"), onTap: () { Navigator.pop(context); _reportUser(); }),
    ]));
  }
  void _viewFollowers() {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserFollowersListScreen(
          userId: widget.userId,
          userName: _user?.name ?? 'User',
          type: FollowListType.followers,
        ),
      ),
    ).then((_) {
      if (mounted) _fetchFollowCounts();
    });
  }

  void _viewFollowing() {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserFollowersListScreen(
          userId: widget.userId,
          userName: _user?.name ?? 'User',
          type: FollowListType.following,
        ),
      ),
    ).then((_) {
      if (mounted) _fetchFollowCounts();
    });
  }

  void _viewAllTrades() {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserItemsListScreen(
          userId: widget.userId,
          userName: _user?.name ?? 'User',
          type: UserItemsType.trades,
        ),
      ),
    );
  }

  void _viewAllGifts() {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserItemsListScreen(
          userId: widget.userId,
          userName: _user?.name ?? 'User',
          type: UserItemsType.gifts,
        ),
      ),
    );
  }

  void _viewAllCampaigns() {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserItemsListScreen(
          userId: widget.userId,
          userName: _user?.name ?? 'User',
          type: UserItemsType.campaigns,
        ),
      ),
    );
  }

  void _viewAllReviews() {} 
  void _blockUser() => AppToast.show(context, "User blocked");
  void _reportUser() {
    if (_user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportUserSheet(
        reportedUserId: widget.userId,
        reportedUserName: _user!.name,
      ),
    );
  }
  void _shareProfile() {
    final target = _user;
    final displayName = target?.name ?? 'Check out this profile';
    final username = target?.username;
    final id = target?.id ?? widget.userId;
    ShareUtils.shareProfile(
      context,
      displayName: displayName,
      userId: id,
      username: username,
    );
  }
}