import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
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
import '../../../core/models/listing_media.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../core/widgets/similar_items_section.dart';
import '../models/gift_models.dart' as gift_models;
import '../providers/gift_provider.dart';
import '../widgets/gift_claim_sheet.dart';
import '../../chat/models/chat_conversation.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/utils/item_context_chat_message.dart';
import '../../../widgets/completion_dialog.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/services/user_social_service.dart';
import '../../trade/models/trade_models.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class GiftDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gift;

  const GiftDetailsScreen({super.key, required this.gift});

  @override
  State<GiftDetailsScreen> createState() => _GiftDetailsScreenState();
}

class _GiftDetailsScreenState extends State<GiftDetailsScreen>
    with TickerProviderStateMixin, DetailsScreenAnimations {
  late DetailsDataManager _dataManager;

  bool _isClaimed = false;
  bool _hasPendingClaim = false;
  bool _isLiked = false;
  bool _isFollowing = false;
  bool _isBookmarked = false;
  int _likeCount = 0;
  int _viewCount = 0;
  List<gift_models.Gift> _similarGifts = [];
  bool _isLoadingSimilarGifts = false;
  bool _hasLoadedSimilarGifts = false;
  gift_models.Gift? _fullGift;
  String? _currentUserId;
  List<String> _resolvedImageUrls = [];

  bool get _isOwner {
    if (_fullGift != null && _currentUserId != null) {
      return _fullGift!.giver.id == _currentUserId;
    }
    return false;
  }

  String get _giftId => widget.gift['id']?.toString() ?? '';

  ListingMediaFields get _listingMedia {
    if (_fullGift != null) return _fullGift!.listingMedia;
    final raw = widget.gift['__raw'];
    if (raw is Map) {
      return ListingMediaFields.fromJson(Map<String, dynamic>.from(raw));
    }
    return ListingMediaFields.fromJson(widget.gift);
  }

  @override
  void initState() {
    super.initState();
    initDetailsAnimations();
    _dataManager = DetailsDataManager(
      itemId: widget.gift['id']?.toString() ?? '',
      itemType: 'GIFT',
    );
    _isClaimed = widget.gift['claimed'] == true;
    _loadGiftData();
    _incrementViewCount();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveOwnershipAndLoadGift();
      _loadGiverFollowState();
    });
  }

  @override
  void dispose() {
    disposeDetailsAnimations();
    _dataManager.dispose();
    super.dispose();
  }

  Future<void> _handleMarkCompleted() async {
    final giftId = widget.gift['id']?.toString() ?? '';
    final giftTitle = widget.gift['title']?.toString() ?? 'Gift';

    final result = await showDialog<CompletionResult>(
      context: context,
      builder: (_) => CompletionDialog(itemType: 'GIFT', itemTitle: giftTitle),
    );

    if (result != null && mounted) {
      try {
        const storage = FlutterSecureStorage();
        final baseUrl = await EnvConfig.getBaseUrl();
        final apiClient = ApiClient(baseUrl, storage);

        await apiClient.post(
          '/v1/interactions/GIFT/$giftId/complete',
          data: result.toJson(),
        );

        if (mounted) {
          AppToast.success(context, 'Gift marked as completed!', title: 'Done');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, 'Error: ${e.toString()}');
        }
      }
    }
  }

  void _loadGiftData() {
    setState(() {
      _likeCount = 0;
      _viewCount = 0;
      _similarGifts = [];
    });
  }

  Future<void> _resolveOwnershipAndLoadGift() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _currentUserId = auth.currentUser?.id;
    } catch (_) {
      _currentUserId = null;
    }

    final giftId = widget.gift['id']?.toString() ?? '';
    if (giftId.isEmpty) return;

    try {
      final giftProvider = Provider.of<GiftProvider>(context, listen: false);
      final g = await giftProvider.getGift(giftId);
      if (mounted) {
        setState(() {
          _fullGift = g;
          _viewCount = g?.viewCount ?? 0;
          _likeCount = g?.likeCount ?? 0;
        });
        _resolveGiftImages();
        await _checkPendingClaim();
        await _loadGiverFollowState();
      }
    } catch (_) {}
  }

  Future<void> _checkPendingClaim() async {
    if (_currentUserId == null) return;
    final giftId = widget.gift['id']?.toString() ?? '';
    if (giftId.isEmpty) return;
    try {
      final provider = Provider.of<GiftProvider>(context, listen: false);
      await provider.loadGiftRequests(
        force: true,
        status: gift_models.GiftRequestStatus.pending,
      );
      final hasForThisGift = provider.giftRequests.any(
        (r) =>
            r.giftId == giftId &&
            r.requester.id == _currentUserId &&
            r.status == gift_models.GiftRequestStatus.pending,
      );
      if (mounted && hasForThisGift) {
        setState(() => _hasPendingClaim = true);
      }
    } catch (_) {}
  }

  Future<void> _loadSimilarGifts() async {
    if (_isLoadingSimilarGifts || _hasLoadedSimilarGifts) return;
    setState(() => _isLoadingSimilarGifts = true);
    try {
      final items = await _dataManager.loadSimilarItems(limit: 8);
      final list = items
          .whereType<Map>()
          .map(
            (item) =>
                gift_models.Gift.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      if (mounted) {
        setState(() {
          _similarGifts = list;
          _hasLoadedSimilarGifts = true;
          _isLoadingSimilarGifts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _similarGifts = [];
          _hasLoadedSimilarGifts = true;
          _isLoadingSimilarGifts = false;
        });
      }
    }
  }

  Future<void> _resolveGiftImages() async {
    if (_fullGift == null || _fullGift!.imageUrls.isEmpty) return;

    final urls = await _dataManager.resolveMediaUrls(_fullGift!.imageUrls);
    if (mounted) setState(() => _resolvedImageUrls = urls);
  }

  Future<void> _incrementViewCount() async {
    final giftId = widget.gift['id']?.toString() ?? '';
    if (giftId.isEmpty) return;
    try {
      final giftProvider = Provider.of<GiftProvider>(context, listen: false);
      final res = await giftProvider.incrementGiftView(giftId);
      if (mounted) {
        final v = res['viewCount'] as int?;
        if (v != null) setState(() => _viewCount = v);
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (AppRoutes.requireSignIn(context)) return;
    final giftId = widget.gift['id']?.toString() ?? '';
    if (giftId.isEmpty) return;
    try {
      final giftProvider = Provider.of<GiftProvider>(context, listen: false);
      final res = _isLiked
          ? await giftProvider.unlikeGift(giftId)
          : await giftProvider.likeGift(giftId);
      if (mounted) {
        final likes = res['likes'] as int?;
        if (likes != null) {
          setState(() {
            _isLiked = !_isLiked;
            _likeCount = likes;
          });
        }
      }
    } catch (_) {}
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true, // Allow floating bottom bar
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                child: combinedTransition(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      if (_hasPendingClaim) ...[
                        _buildPendingRequestBanner(),
                        const SizedBox(height: 12),
                      ],
                      _buildGiftOverview(),
                      const SizedBox(height: 16),
                      _buildGiverInfo(),
                      const SizedBox(height: 16),
                      _buildGiftDetailsGrid(),
                      const SizedBox(height: 16),
                      _buildDescriptionSection(),
                      if (_hasTypeSpecificContent()) ...[
                        const SizedBox(height: 16),
                        _buildTypeSpecificInfo(),
                      ],
                      if (_hasLocation()) ...[
                        const SizedBox(height: 16),
                        _buildLocationInfo(),
                      ],
                      const SizedBox(height: 16),
                      DetailsCommentsCollapsible(
                        itemId: widget.gift['id']?.toString() ?? '',
                        itemType: 'GIFT',
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        onLoadComments: () =>
                            _dataManager.loadComments(limit: 50),
                        onAddComment: _dataManager.addComment,
                        onEditComment: _dataManager.updateComment,
                      ),
                      const SizedBox(height: 16),
                      SimilarItemsSection(
                        title: 'Similar Gifts',
                        leadingIcon: Icons.recommend_rounded,
                        isLoading: _isLoadingSimilarGifts,
                        hasLoaded: _hasLoadedSimilarGifts,
                        items: _similarGifts,
                        onExpand: _loadSimilarGifts,
                        listHeight: 190,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        emptyMessage: 'No similar gifts found.',
                        itemBuilder: (_, gift, __) =>
                            _buildSimilarGiftCard(gift as gift_models.Gift),
                      ),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(),
    );
  }

  Widget _buildGiftOverview() {
    final title = widget.gift['title']?.toString() ?? 'Gift';
    final category = widget.gift['category']?.toString() ?? 'General';
    final color = widget.gift['color'] as Color? ?? AppColors.primary;
    final icon =
        widget.gift['icon'] as IconData? ?? Icons.card_giftcard_rounded;
    final status =
        (_fullGift?.status == gift_models.GiftStatus.claimed ||
            _fullGift?.status == gift_models.GiftStatus.completed)
        ? 'Completed'
        : 'Available';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildOverviewBadge(icon, category, color),
              _buildOverviewBadge(
                Icons.bolt_rounded,
                '+${widget.gift['karma'] ?? 30} KARMA',
                AppColors.primary,
              ),
              _buildOverviewBadge(
                status == 'Completed'
                    ? Icons.check_circle_rounded
                    : Icons.fiber_manual_record_rounded,
                status,
                status == 'Completed' ? Colors.green : Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInlineStat(
                _isLiked ? Icons.favorite_rounded : Icons.favorite_border,
                _likeCount.toString(),
                _isLiked ? Colors.red : Colors.grey[700]!,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 18),
              _buildInlineStat(
                Icons.visibility_rounded,
                _viewCount.toString(),
                Colors.grey[700]!,
              ),
              const SizedBox(width: 18),
              _buildInlineStat(
                Icons.ios_share_rounded,
                'Share',
                Colors.grey[700]!,
                onTap: _shareGift,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStat(
    IconData icon,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftDetailsGrid() {
    final type = widget.gift['type']?.toString() ?? 'Gift';
    final requestCount = _fullGift?.requestCount ?? 0;

    return DetailCardGrid(
      items: [
        DetailCardItem(
          label: 'Type',
          value: type,
          icon: Icons.category_rounded,
          accentColor: AppColors.primary,
        ),
        DetailCardItem(
          label: 'Karma',
          value: '${widget.gift['karma'] ?? 30} pts',
          icon: Icons.stars_rounded,
          accentColor: Colors.amber[700],
        ),
        DetailCardItem(
          label: 'Requests',
          value: requestCount.toString(),
          icon: Icons.inbox_rounded,
          accentColor: Colors.orange,
        ),
      ],
    );
  }

  bool _hasLocation() {
    final loc = _fullGift?.location ?? widget.gift['location']?.toString();
    return loc != null && loc.trim().isNotEmpty;
  }

  bool _hasTypeSpecificContent() {
    return _fullGift != null || widget.gift['type'] != null;
  }

  Widget _buildDescriptionSection() {
    return CollapsibleSection(
      title: 'Description',
      leadingIcon: Icons.notes_rounded,
      initiallyExpanded: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      content: ExpandableDescription(
        description: widget.gift['description']?.toString() ?? '',
        maxLines: 4,
        textStyle: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final rawImages =
        _fullGift?.imageUrls ??
        List<String>.from(
          (widget.gift['mediaKeys'] ??
                  widget.gift['imageUrls'] ??
                  widget.gift['image_urls']) ??
              [],
        );
    final imagesToShow = _resolvedImageUrls.isNotEmpty
        ? _resolvedImageUrls
        : rawImages;

    return SliverAppBar(
      expandedHeight: 350,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white.withValues(alpha: 0.7),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: DetailsGlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: DetailsGlassIconButton(
            icon: _isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded,
            color: _isBookmarked ? Colors.purple : null,
            onTap: () => setState(() => _isBookmarked = !_isBookmarked),
          ),
        ),
        if (_isOwner && _fullGift?.status == gift_models.GiftStatus.active)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: DetailsGlassIconButton(
              icon: Icons.more_vert,
              onTap: () {},
              child: PopupMenuButton<String>(
                offset: const Offset(0, 40),
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'complete') _handleMarkCompleted();
                  if (value == 'delete') _deleteGift();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'complete',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green),
                        SizedBox(width: 12),
                        Text(
                          'Mark as Completed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (_fullGift != null &&
                      ListingDeleteRules.canDeleteGift(_fullGift!))
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.red),
                          SizedBox(width: 12),
                          Text(
                            'Delete Gift',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_listingMedia.hasMedia)
              ListingMediaView(
                media: _listingMedia,
                heroTag: 'gift-$_giftId',
                height: 280,
                enableZoom: !_listingMedia.isVideo,
                openFullscreenOnTap: true,
                videoMuted: false,
                autoplayVideo: true,
              )
            else
              _buildImagePlaceholder(context),

            // Smooth Gradient Overlay at bottom of image
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      context.pageBackground.withValues(alpha: 0.92),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (widget.gift['color'] as Color? ?? Colors.purple).withValues(
              alpha: 0.2,
            ),
            (widget.gift['color'] as Color? ?? Colors.purple).withValues(
              alpha: 0.05,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
              ),
            ],
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
              width: 2,
            ),
          ),
          child: Icon(
            widget.gift['icon'] as IconData? ?? Icons.card_giftcard_rounded,
            size: 50,
            color: widget.gift['color'] as Color? ?? Colors.purple,
          ),
        ),
      ),
    );
  }

  Widget _buildGiverInfo() {
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    final giverName =
        _fullGift?.giver.name ?? widget.gift['giver']?.toString() ?? 'Unknown';
    final avatarKey =
        _fullGift?.giver.profileImageUrl ??
        widget.gift['giverAvatarKey']?.toString();
    final giverId =
        _fullGift?.giver.id ?? widget.gift['giverId']?.toString() ?? '';
    final rating = _fullGift?.giver.rating ?? 4.8;
    final completedGifts = _fullGift?.giver.completedGifts ?? 0;
    final isVerified = _fullGift?.giver.isVerified ?? false;

    final isSelf = giverId.isNotEmpty && giverId == _currentUserId;

    return CreatorCard(
      userId: giverId,
      name: giverName,
      avatarUrl: avatarKey,
      rating: rating,
      isVerified: isVerified,
      subtitle: '$completedGifts gifts given',
      showButtons: isAuthed,
      onViewProfile: isAuthed ? _viewGiverProfile : null,
      onMessage: isAuthed ? _messageGiver : null,
      onSecondaryAction: isAuthed && !isSelf ? _toggleGiverFollow : null,
      secondaryButtonLabel: _isFollowing ? 'Following' : 'Follow',
    );
  }

  Future<void> _loadGiverFollowState() async {
    final giverId =
        _fullGift?.giver.id ?? widget.gift['giverId']?.toString() ?? '';
    if (giverId.isEmpty || giverId == _currentUserId) return;
    try {
      final following = await UserSocialService.instance.isFollowing(giverId);
      if (mounted) setState(() => _isFollowing = following);
    } catch (_) {}
  }

  Future<void> _toggleGiverFollow() async {
    if (AppRoutes.requireSignIn(context)) return;
    final giverId =
        _fullGift?.giver.id ?? widget.gift['giverId']?.toString() ?? '';
    if (giverId.isEmpty) return;
    if (giverId == _currentUserId) return;

    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !wasFollowing);
    try {
      if (wasFollowing) {
        await UserSocialService.instance.unfollow(giverId);
      } else {
        await UserSocialService.instance.follow(giverId);
      }
      if (mounted) {
        _showSnackBar(_isFollowing ? 'Followed' : 'Unfollowed');
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = wasFollowing);
    }
  }

  Future<void> _messageGiver() async {
    if (AppRoutes.requireSignIn(context)) return;
    if (_fullGift == null) {
      _showSnackBar('Loading gift details…');
      return;
    }
    if (_fullGift!.giver.id == _currentUserId) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final existing = chatProvider.findConversationInCache(
        contextId: _fullGift!.id,
        partnerId: _fullGift!.giver.id,
      );
      if (existing != null) {
        if (!mounted) return;
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversation: existing,
              chatType: ChatType.gifting,
            ),
          ),
        );
        return;
      }

      final conversation = await chatProvider.startDirectMessage(
        recipientId: _fullGift!.giver.id,
        recipientName: _fullGift!.giver.name,
        initialMessage: ItemContextChatMessage.giftIntroForGiver(_fullGift!),
        contextTitle: 'Gift: ${_fullGift!.title}',
        contextId: _fullGift!.id,
        apiType: 'DIRECT',
      );
      if (!mounted || conversation == null) return;
      GuardedNavigator.push(context, 
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversation: conversation,
            chatType: ChatType.gifting,
          ),
        ),
      );
      unawaited(chatProvider.sendListingThumbnailIfNeeded(
        conversationId: conversation.id,
        previewImageKey:
            ItemContextChatMessage.previewImageKeyForGift(_fullGift!),
      ));
    } catch (e) {
      if (mounted) _showSnackBar('Could not open chat');
    }
  }

  Widget _buildPendingRequestBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: Colors.grey[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your request is pending. The giver will approve or decline.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSpecificInfo() {
    final gift = _fullGift;
    final typeLabel = gift?.type.label ??
        widget.gift['type']?.toString() ??
        'Gift';
    final duration = gift?.expiresAt != null
        ? gift!.timeRemaining
        : (widget.gift['expires']?.toString() ?? 'No time limit');
    final claims = gift != null
        ? '${gift.currentClaims}/${gift.maxClaims} claimed'
        : 'Single claim';

    return CollapsibleSection(
      title: 'Gift Details',
      leadingIcon: Icons.info_outline_rounded,
      initiallyExpanded: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      content: Column(
        children: [
          _buildInfoRow('Type', typeLabel, Icons.card_giftcard_rounded),
          _buildInfoRow('Duration', duration, Icons.access_time_rounded),
          _buildInfoRow('Claims', claims, Icons.people_alt_rounded),
          if (gift?.minimumKarmaLevel != null)
            _buildInfoRow(
              'Min Karma',
              gift!.minimumKarmaLevel!.name,
              Icons.stars_rounded,
            ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    final location =
        _fullGift?.location ?? widget.gift['location']?.toString() ?? '';

    return CollapsibleSection(
      title: 'Location',
      leadingIcon: Icons.location_on_rounded,
      initiallyExpanded: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_rounded, color: Colors.grey[600], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  onPressed: _showLocationMap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(
                    'View Map',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarGiftCard(gift_models.Gift gift) {
    return GestureDetector(
      onTap: () => AppRoutes.navigateToGiftDetails(context, gift),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: gift.category.color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  gift.category.icon,
                  size: 36,
                  color: gift.category.color,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '+${gift.karmaReward} KARMA',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    final isOwner =
        (_currentUserId != null &&
        ((_fullGift != null && _fullGift!.giver.id == _currentUserId) ||
            (widget.gift['giverId'] == _currentUserId)));
    if (!isAuthed && !isOwner) {
      return ContextualActionBar(
        actions: [
          ContextualAction(
            label: 'Sign in to Request Gift',
            icon: Icons.login_rounded,
            isPrimary: true,
            onPressed: () => AppRoutes.requireSignIn(context),
          ),
        ],
      );
    }
    if (_isClaimed) {
      return ContextualActionBar(
        actions: [
          ContextualAction(
            label: 'Leave Review',
            icon: Icons.star_rounded,
            onPressed: _leaveReview,
          ),
          ContextualAction(
            label: 'Say Thanks',
            icon: Icons.favorite_rounded,
            isPrimary: true,
            onPressed: _sendThankYou,
          ),
        ],
      );
    }

    if (_hasPendingClaim && !isOwner) {
      return ContextualActionBar(
        actions: [
          ContextualAction(
            label: 'Message',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: _messageGiver,
          ),
          ContextualAction(
            label: 'Pending',
            icon: Icons.hourglass_top_rounded,
            isPrimary: true,
            flex: 2,
            onPressed: null,
          ),
        ],
      );
    }

    return ContextualActionBar(
      actions: isOwner
          ? [
              ContextualAction(
                label: 'Edit Gift',
                icon: Icons.edit_rounded,
                isPrimary: true,
                onPressed: _editGift,
              ),
            ]
          : [
              ContextualAction(
                label: 'Request gift',
                icon: Icons.card_giftcard_rounded,
                isPrimary: true,
                onPressed: _claimGift,
              ),
            ],
    );
  }

  void _editGift() {
    if (_fullGift == null) {
      _showSnackBar('Unable to load full gift details');
      return;
    }
    AppRoutes.navigateToEditGift(context, _fullGift!);
  }

  Future<void> _deleteGift() async {
    final gift = _fullGift;
    if (gift == null) {
      _showSnackBar('Unable to load gift details');
      return;
    }
    final confirmed = await confirmDeleteListing(
      context,
      title: gift.title,
      itemLabel: 'gift',
      blockedReason: ListingDeleteRules.giftDeleteBlockedReason(gift),
    );
    if (!confirmed || !mounted) return;

    final provider = Provider.of<GiftProvider>(context, listen: false);
    final success = await provider.deleteGift(gift.id);
    if (!mounted) return;
    if (success) {
      showDeleteListingResult(context, success: true, message: 'Gift deleted');
      Navigator.pop(context);
    } else {
      showDeleteListingResult(
        context,
        success: false,
        message: provider.error ?? 'Failed to delete gift',
      );
    }
  }

  // Action methods
  Future<void> _claimGift() async {
    if (AppRoutes.requireSignIn(context)) return;
    final result = await showGiftClaimSheet(
      context,
      gift: widget.gift,
      fullGift: _fullGift,
    );

    if (!mounted || result == null) return;

    if (result['success'] == true) {
      setState(() => _hasPendingClaim = true);
      final message = result['message']?.toString() ??
          'Request sent. Waiting for the giver to approve.';
      AppToast.success(context, message, title: 'Request sent');
      if (!mounted) return;
      await followUpGiftClaimResult(
        context,
        result,
        fullGift: _fullGift,
        giftMap: widget.gift,
      );
    }
  }

  void _sendThankYou() {
    _showSnackBar('Thank you message sent! +5 KARMA for gratitude.');
  }

  void _leaveReview() {
    _showReviewDialog();
  }

  void _shareGift() {
    final id = widget.gift['id']?.toString() ?? '';
    final title = widget.gift['title']?.toString() ?? 'Gift';
    ShareUtils.shareGift(context, id: id, title: title);
  }

  void _viewGiverProfile() {
    if (AppRoutes.requireSignIn(context)) return;
    final giverId = _fullGift?.giver.id ?? widget.gift['giverId']?.toString();
    if (giverId == null || giverId.isEmpty) {
      _showSnackBar('Unable to open giver profile');
      return;
    }
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: giverId,
          user: _fullGift != null
              ? TradeUser(
                  id: _fullGift!.giver.id,
                  name: _fullGift!.giver.name,
                  username: _fullGift!.giver.username,
                  avatar: _fullGift!.giver.profileImageUrl,
                  rating: _fullGift!.giver.rating,
                  completedTrades: _fullGift!.giver.completedGifts,
                  joinedDate: _fullGift!.giver.joinedDate,
                  isVerified: _fullGift!.giver.isVerified,
                  karmaPoints: _fullGift!.giver.karmaPoints,
                  trustBadges: const [],
                )
              : null,
        ),
      ),
    );
  }

  void _showLocationMap() {
    _showSnackBar('Opening location map...');
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Leave a Review',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rate your experience with this gift:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                Icon(Icons.star_outline_rounded, color: Colors.amber, size: 36),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: context.recessedInputDecoration(hint: 'Write your review...'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Review submitted! +10 KARMA for feedback.');
            },
            child: const Text(
              'Submit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    AppToast.info(context, message);
  }
}
