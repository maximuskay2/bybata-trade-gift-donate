import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/managers/details_data_manager.dart';
import '../../../core/mixins/details_screen_animations.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/widgets/contextual_action_bar.dart';
import '../../../core/widgets/creator_card.dart';
import '../../../core/widgets/details_comments_collapsible.dart';
import '../../../core/widgets/expandable_description.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../core/widgets/similar_items_section.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/services/user_social_service.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
import '../widgets/even_trade_panel.dart';
import 'trade_chat_screen.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class TradeDetailsScreen extends StatefulWidget {
  final trade_models.Trade trade;

  const TradeDetailsScreen({super.key, required this.trade});

  @override
  State<TradeDetailsScreen> createState() => _TradeDetailsScreenState();
}

class _TradeDetailsScreenState extends State<TradeDetailsScreen>
    with TickerProviderStateMixin, DetailsScreenAnimations {
  late DetailsDataManager _dataManager;

  bool _isFavorited = false;
  int _likeCount = 0;
  bool _isFollowing = false;
  bool _isLoadingSimilarTrades = false;
  bool _hasLoadedSimilarTrades = false;

  List<trade_models.Trade> _userActiveTrades = [];
  List<dynamic> _similarTrades = [];

  @override
  void initState() {
    super.initState();
    initDetailsAnimations();
    _dataManager = DetailsDataManager(
      itemId: widget.trade.id,
      itemType: 'TRADE',
    );
    _likeCount = widget.trade.favoriteCount;
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwnerSocialState());
  }

  @override
  void dispose() {
    disposeDetailsAnimations();
    _dataManager.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUserActiveTrades(),
      _resolveTradeImages(),
    ]);
    if (mounted) {
      setState(() {
        _likeCount = widget.trade.favoriteCount;
      });
    }
  }

  bool get _isOwner {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.currentUser?.id == widget.trade.owner.id;
  }

  Future<void> _loadOwnerSocialState() async {
    if (_isOwner) return;
    final ownerId = widget.trade.owner.id;
    if (ownerId.isEmpty) return;
    try {
      final following = await UserSocialService.instance.isFollowing(ownerId);
      if (mounted) setState(() => _isFollowing = following);
    } catch (_) {}
  }

  Future<void> _toggleOwnerFollow() async {
    if (AppRoutes.requireSignIn(context)) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ownerId = widget.trade.owner.id;
    if (ownerId.isEmpty || ownerId == auth.currentUser!.id) return;

    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !wasFollowing);
    try {
      if (wasFollowing) {
        await UserSocialService.instance.unfollow(ownerId);
      } else {
        await UserSocialService.instance.follow(ownerId);
      }
      if (mounted) {
        AppToast.show(context, _isFollowing ? 'Followed' : 'Unfollowed');
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = wasFollowing);
    }
  }

  Future<void> _toggleLike() async {
    if (AppRoutes.requireSignIn(context)) return;
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final res = _isFavorited
          ? await backend.unlikeTrade(widget.trade.id)
          : await backend.likeTrade(widget.trade.id);
      final likes = res['likes'] as int?;
      if (mounted && likes != null) {
        setState(() {
          _isFavorited = !_isFavorited;
          _likeCount = likes;
        });
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Could not update like');
      }
    }
  }

  Future<void> _loadUserActiveTrades() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        if (mounted) setState(() => _userActiveTrades = []);
        return;
      }

      final res = await backend.listMyTrades(
        ownerId: currentUser.id,
        page: 1,
        size: 50,
        forceRefresh: true,
      );
      if (!mounted) return;

      final items = (res['items'] as List?) ?? [];
      final mapped = items
          .whereType<Map>()
          .map(
            (item) => trade_models.Trade.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (t) =>
                t.status == trade_models.TradeStatus.active ||
                t.status == trade_models.TradeStatus.inOffer,
          )
          .toList();
      setState(() => _userActiveTrades = mapped);
    } catch (_) {
      if (mounted) setState(() => _userActiveTrades = []);
    }
  }

  Future<void> _resolveTradeImages() async {
    // Warm the media cache so the photo well can paint without a second fetch.
    await _dataManager.resolveMediaUrls(widget.trade.images);
  }

  Future<void> _loadSimilarTrades() async {
    if (_isLoadingSimilarTrades || _hasLoadedSimilarTrades) return;
    setState(() => _isLoadingSimilarTrades = true);
    final items = await _dataManager.loadSimilarItems(
      limit: 8,
      queryParameters: {'category': widget.trade.categoryName},
    );
    if (!mounted) return;
    setState(() {
      _similarTrades = items;
      _hasLoadedSimilarTrades = true;
      _isLoadingSimilarTrades = false;
    });
  }

  void _onInterestedPressed() {
    if (AppRoutes.requireSignIn(context)) return;
    AppRoutes.navigateToNegotiation(
      context,
      targetTrade: widget.trade,
      userTrades: _userActiveTrades,
    );
  }

  void _viewOwnerProfile() {
    if (AppRoutes.requireSignIn(context)) return;
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: widget.trade.owner.id,
          user: widget.trade.owner,
        ),
      ),
    );
  }

  void _messageOwner() {
    if (AppRoutes.requireSignIn(context)) return;
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (_) => TradeChatScreen(
          trade: widget.trade,
          partnerId: widget.trade.owner.id,
          partnerName: widget.trade.owner.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = context.horizontalPadding;
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvas = isDark ? const Color(0xFF120E18) : const Color(0xFFF6F3FF);
    final trade = widget.trade;
    final photoHeight =
        (MediaQuery.sizeOf(context).height * 0.42).clamp(300.0, 440.0);

    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: canvas,
                foregroundColor: context.primaryText,
                centerTitle: true,
                title: const Text(
                  'Trade',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => Navigator.maybePop(context),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => ShareUtils.shareTrade(
                      context,
                      id: trade.id,
                      title: trade.title,
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: combinedTransition(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhotoWell(isDark, photoHeight),
                        const SizedBox(height: 18),
                        _buildHeadline(),
                        if (trade.status == trade_models.TradeStatus.cancelled) ...[
                          const SizedBox(height: 16),
                          EvenTradePanel(
                            tradeId: trade.id,
                            tradeStatus: 'CANCELLED',
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildFactWrap(),
                        const SizedBox(height: 22),
                        _sectionTitle('Listed by', AppColors.primary),
                        const SizedBox(height: 10),
                        CreatorCard(
                          userId: trade.owner.id,
                          name: trade.owner.name,
                          avatarUrl: trade.owner.avatar,
                          rating: trade.owner.rating,
                          isVerified: trade.owner.isVerified,
                          subtitle:
                              '${trade.owner.completedTrades} completed trades',
                          showButtons: isAuthed,
                          onViewProfile: isAuthed ? _viewOwnerProfile : null,
                          onMessage: isAuthed ? _messageOwner : null,
                          onSecondaryAction:
                              isAuthed && !_isOwner ? _toggleOwnerFollow : null,
                          secondaryButtonLabel:
                              _isFollowing ? 'Following' : 'Follow',
                        ),
                        if (trade.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _sectionTitle('Description', const Color(0xFF42A5F5)),
                          const SizedBox(height: 8),
                          ExpandableDescription(
                            description: trade.description,
                            maxLines: 4,
                            expandButtonText: 'Read More',
                          ),
                        ],
                        if (trade.interestedItems.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _sectionTitle('Looking for', const Color(0xFFEC407A)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: trade.interestedItems
                                .map(
                                  (item) => _softPill(
                                    item,
                                    fill: const Color(0xFFFCE4EC),
                                    ink: const Color(0xFFC2185B),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 22),
                        DetailsCommentsCollapsible(
                          itemId: trade.id,
                          itemType: 'TRADE',
                          onLoadComments: () =>
                              _dataManager.loadComments(limit: 50),
                          onAddComment: _dataManager.addComment,
                          onEditComment: _dataManager.updateComment,
                        ),
                        const SizedBox(height: 20),
                        SimilarItemsSection(
                          title: 'Similar Trades',
                          isLoading: _isLoadingSimilarTrades,
                          hasLoaded: _hasLoadedSimilarTrades,
                          items: _similarTrades,
                          onExpand: _loadSimilarTrades,
                          emptyMessage: 'No similar trades found.',
                          itemBuilder: (ctx, item, index) {
                            final title = item is Map
                                ? item['title']?.toString() ?? 'Trade'
                                : 'Trade';
                            final location = item is Map
                                ? item['location']?.toString() ?? 'Remote'
                                : 'Remote';
                            return _SimilarTradeTile(
                              title: title,
                              location: location,
                              toneIndex: index,
                              onTap: () {
                                final id = item is Map
                                    ? item['id']?.toString()
                                    : null;
                                if (id != null && id.isNotEmpty) {
                                  AppRoutes.navigateToTradeDetailsById(
                                    context,
                                    id,
                                  );
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildActionBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWell(bool isDark, double height) {
    final innerHeight = height - 20;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF3A2A5C),
                  Color(0xFF1A3348),
                  Color(0xFF4A2033),
                ]
              : const [
                  Color(0xFFEDE7F6),
                  Color(0xFFFFF3D6),
                  Color(0xFFE3F2FD),
                  Color(0xFFFCE4EC),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: isDark ? const Color(0xFF1A1524) : Colors.white,
            child: SizedBox(
              height: innerHeight,
              width: double.infinity,
              child: ListingMediaView(
                media: widget.trade.listingMedia,
                heroTag: 'trade_${widget.trade.id}',
                height: innerHeight,
                fit: BoxFit.contain,
                enableZoom: !widget.trade.listingMedia.isVideo,
                openFullscreenOnTap: true,
                videoMuted: false,
                autoplayVideo: true,
                showPageIndicator: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color accent) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    final trade = widget.trade;
    final muted = context.secondaryText;
    final place = trade.location.trim().isNotEmpty ? trade.location.trim() : 'Remote';
    final hasValue = trade.estimatedValue > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trade.title,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: context.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${trade.categoryName} · $place',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trade.owner.rating > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppTheme.karmaColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trade.owner.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.primaryText,
                      ),
                    ),
                  ],
                ),
              ],
              if (hasValue) ...[
                const SizedBox(height: 14),
                Text(
                  'Est. value',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${trade.estimatedValue}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.primaryLight
                        : AppColors.primaryDark,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildLikeButton(),
      ],
    );
  }

  Widget _buildLikeButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: _isFavorited ? 'Unlike listing' : 'Like listing',
      child: Column(
        children: [
          Material(
            color: _isFavorited
                ? const Color(0xFFFFE4EC)
                : (isDark ? const Color(0xFF2A2438) : Colors.white),
            elevation: _isFavorited ? 2 : 0,
            shadowColor: const Color(0x55E91E63),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleLike,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _isFavorited
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorited
                      ? const Color(0xFFE91E63)
                      : context.primaryText,
                ),
              ),
            ),
          ),
          if (_likeCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$_likeCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFactWrap() {
    final trade = widget.trade;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _softPill(
          trade.condition.displayText,
          icon: Icons.inventory_2_outlined,
          fill: const Color(0xFFEDE7F6),
          ink: AppColors.primaryDark,
        ),
        _softPill(
          trade.allowPickup ? 'Pickup' : 'No pickup',
          icon: Icons.place_outlined,
          fill: const Color(0xFFE3F2FD),
          ink: const Color(0xFF1565C0),
        ),
        _softPill(
          trade.isNegotiable ? 'Negotiable' : 'Fixed swap',
          icon: Icons.handshake_outlined,
          fill: const Color(0xFFFFF3D6),
          ink: const Color(0xFFB45309),
        ),
      ],
    );
  }

  Widget _softPill(
    String label, {
    IconData? icon,
    Color fill = Colors.white,
    Color ink = AppColors.primaryDark,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? ink.withValues(alpha: 0.22) : fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: isDark ? Colors.white : ink),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isOwner = auth.currentUser?.id == widget.trade.owner.id;
        if (!auth.isAuthenticated && !isOwner) {
          return ContextualActionBar(
            accentColor: AppTheme.tradeColor,
            actions: [
              ContextualAction(
                label: 'Sign in to Trade',
                icon: Icons.login_rounded,
                isPrimary: true,
                onPressed: () => AppRoutes.requireSignIn(context),
              ),
            ],
          );
        }
        return ContextualActionBar(
          accentColor: AppTheme.tradeColor,
          actions: isOwner
              ? [
                  if (ListingDeleteRules.canDeleteTrade(widget.trade))
                    ContextualAction(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      onPressed: _deleteTrade,
                    ),
                  ContextualAction(
                    label: 'Edit Trade',
                    icon: Icons.edit_rounded,
                    isPrimary: true,
                    onPressed: () =>
                        AppRoutes.navigateToEditTrade(context, widget.trade),
                  ),
                ]
              : [
                  ContextualAction(
                    label: 'Chat',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: _messageOwner,
                  ),
                  ContextualAction(
                    label: 'Make Offer',
                    icon: Icons.handshake_rounded,
                    isPrimary: true,
                    flex: 2,
                    onPressed: _onInterestedPressed,
                  ),
                ],
        );
      },
    );
  }

  Future<void> _deleteTrade() async {
    final trade = widget.trade;
    final confirmed = await confirmDeleteListing(
      context,
      title: trade.title,
      itemLabel: 'trade',
      blockedReason: ListingDeleteRules.tradeDeleteBlockedReason(trade),
    );
    if (!confirmed || !mounted) return;

    final backend = Provider.of<TradeBackendProvider>(context, listen: false);
    final success = await backend.deleteTrade(trade.id);
    if (!mounted) return;
    if (success) {
      showDeleteListingResult(context, success: true, message: 'Trade deleted');
      Navigator.pop(context);
    } else {
      showDeleteListingResult(
        context,
        success: false,
        message: backend.error ?? 'Failed to delete trade',
      );
    }
  }
}

class _SimilarTradeTile extends StatelessWidget {
  final String title;
  final String location;
  final int toneIndex;
  final VoidCallback? onTap;

  const _SimilarTradeTile({
    required this.title,
    required this.location,
    required this.toneIndex,
    this.onTap,
  });

  static const _fills = <Color>[
    Color(0xFFEDE7F6),
    Color(0xFFFFF3D6),
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFCE4EC),
  ];

  static const _inks = <Color>[
    AppColors.primaryDark,
    Color(0xFFB45309),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFC2185B),
  ];

  @override
  Widget build(BuildContext context) {
    final fill = _fills[toneIndex.abs() % _fills.length];
    final ink = _inks[toneIndex.abs() % _inks.length];
    final isDark = context.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? ink.withValues(alpha: 0.28) : fill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: isDark ? Colors.white : ink,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.primaryText,
              ),
            ),
            const Spacer(),
            Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
