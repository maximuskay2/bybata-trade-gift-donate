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
import '../../../core/widgets/collapsible_section.dart';
import '../../../core/widgets/contextual_action_bar.dart';
import '../../../core/widgets/creator_card.dart';
import '../../../core/widgets/detail_card_grid.dart';
import '../../../core/widgets/details_comments_collapsible.dart';
import '../../../core/widgets/details_glass_controls.dart';
import '../../../core/widgets/expandable_description.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../core/widgets/metadata_badge.dart';
import '../../../core/widgets/similar_items_section.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/services/user_social_service.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
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

  List<String> _resolvedImageUrls = [];
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
    final urls = await _dataManager.resolveMediaUrls(widget.trade.images);
    if (mounted) setState(() => _resolvedImageUrls = urls);
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
    final primaryColor = AppColors.primary;
    final hPad = context.horizontalPadding;
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;

    return Scaffold(
      backgroundColor: context.pageBackground,
      body: Stack(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildMediaSliverAppBar(primaryColor),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: combinedTransition(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildTitleAndPrice(primaryColor),
                          const SizedBox(height: 20),
                          CreatorCard(
                            userId: widget.trade.owner.id,
                            name: widget.trade.owner.name,
                            avatarUrl: widget.trade.owner.avatar,
                            rating: widget.trade.owner.rating,
                            isVerified: widget.trade.owner.isVerified,
                            subtitle:
                                '${widget.trade.owner.completedTrades} completed trades',
                            showButtons: isAuthed,
                            onViewProfile: isAuthed ? _viewOwnerProfile : null,
                            onMessage: isAuthed ? _messageOwner : null,
                            onSecondaryAction:
                                isAuthed && !_isOwner ? _toggleOwnerFollow : null,
                            secondaryButtonLabel:
                                _isFollowing ? 'Following' : 'Follow',
                          ),
                          const SizedBox(height: 20),
                          DetailCardGrid(
                            items: [
                              DetailCardItem(
                                label: 'Condition',
                                value: widget.trade.condition.displayText,
                                icon: Icons.inventory_2_rounded,
                              ),
                              DetailCardItem(
                                label: 'Pickup',
                                value: widget.trade.allowPickup ? 'Yes' : 'No',
                                icon: Icons.local_shipping_rounded,
                              ),
                              DetailCardItem(
                                label: 'Negotiable',
                                value: widget.trade.isNegotiable ? 'Yes' : 'No',
                                icon: Icons.handshake_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          CollapsibleSection(
                            title: 'Description',
                            leadingIcon: Icons.notes_rounded,
                            initiallyExpanded: true,
                            content: ExpandableDescription(
                              description: widget.trade.description,
                              maxLines: 4,
                            ),
                          ),
                          if (widget.trade.interestedItems.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            CollapsibleSection(
                              title: 'Looking For',
                              leadingIcon: Icons.search_rounded,
                              initiallyExpanded: false,
                              content: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: widget.trade.interestedItems
                                    .map((item) => MetadataBadge(label: item))
                                    .toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          DetailsCommentsCollapsible(
                            itemId: widget.trade.id,
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
                            itemBuilder: (ctx, item, _) {
                              final title = item is Map
                                  ? item['title']?.toString() ?? 'Trade'
                                  : 'Trade';
                              final location = item is Map
                                  ? item['location']?.toString() ?? 'Remote'
                                  : 'Remote';
                              return _SimilarTradeTile(
                                title: title,
                                location: location,
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

  Widget _buildMediaSliverAppBar(Color primaryColor) {
    final imagesToShow = _resolvedImageUrls.isNotEmpty
        ? _resolvedImageUrls
        : widget.trade.images;

    return SliverAppBar(
      expandedHeight: 380,
      backgroundColor: context.pageBackground,
      elevation: 0,
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: DetailsGlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: DetailsGlassIconButton(
            icon: _isFavorited ? Icons.favorite : Icons.favorite_border,
            color: _isFavorited ? Colors.red : null,
            onTap: _toggleLike,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: DetailsGlassIconButton(
            icon: Icons.share,
            onTap: () => ShareUtils.shareTrade(
              context,
              id: widget.trade.id,
              title: widget.trade.title,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ListingMediaView(
          media: widget.trade.listingMedia,
          heroTag: 'trade_${widget.trade.id}',
          height: 280,
          enableZoom: !widget.trade.listingMedia.isVideo,
          openFullscreenOnTap: true,
          videoMuted: false,
          autoplayVideo: true,
        ),
      ),
    );
  }

  Widget _buildTitleAndPrice(Color primary) {
    final muted = context.secondaryText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.trade.title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: context.primaryText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  MetadataBadge.category(category: widget.trade.categoryName),
                  const SizedBox(width: 10),
                  Icon(Icons.location_on, size: 14, color: muted),
                  Text(
                    widget.trade.location.isNotEmpty
                        ? ' ${widget.trade.location}'
                        : ' Remote',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        DetailsGlassCard(
          child: Column(
            children: [
              Text(
                'Est. Value',
                style: TextStyle(
                  fontSize: 10,
                  color: muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${widget.trade.estimatedValue}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isOwner = auth.currentUser?.id == widget.trade.owner.id;
        if (!auth.isAuthenticated && !isOwner) {
          return ContextualActionBar(
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
  final VoidCallback? onTap;

  const _SimilarTradeTile({
    required this.title,
    required this.location,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: context.surfaceCardDecoration(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
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
              style: TextStyle(color: context.secondaryText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
