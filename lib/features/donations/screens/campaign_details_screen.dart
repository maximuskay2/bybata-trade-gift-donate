import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/models/chat_conversation.dart';
import 'donation_chat_screen.dart';
import '../../../core/compliance/ios_campaign_support.dart';
import '../models/donation_models.dart';
import '../api/campaign_api.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bybata/features/storage/repository/storage_repository.dart';
import '../../../core/navigation/main_navigation.dart';
import 'dart:io';
import '../../../core/widgets/app_toast.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/completion_dialog.dart';
import '../providers/campaign_provider.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/managers/details_data_manager.dart';
import '../../../core/mixins/details_screen_animations.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/campaign_progress_card.dart';
import '../../../core/widgets/collapsible_section.dart';
import '../../../core/widgets/contextual_action_bar.dart';
import '../../../core/widgets/creator_card.dart';
import '../../../core/widgets/detail_card_grid.dart';
import '../../../core/widgets/details_comments_collapsible.dart';
import '../../../core/widgets/expandable_description.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../core/widgets/similar_items_section.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/services/user_social_service.dart';
import '../../trade/models/trade_models.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class CampaignDetailsScreen extends StatefulWidget {
  final Campaign campaign;

  const CampaignDetailsScreen({super.key, required this.campaign});

  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen>
    with TickerProviderStateMixin, DetailsScreenAnimations {
  ColorScheme get _scheme => Theme.of(context).colorScheme;
  late DetailsDataManager _dataManager;
  bool _isFollowing = false;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isBookmarked = false;
  final ImagePicker _picker = ImagePicker();
  List<String> _updateImages = [];
  Campaign?
  _currentCampaign; // Track current campaign state for real-time updates
  List<String> _resolvedImageUrls = [];
  int _currentImageIndex = 0;
  List<dynamic> _relatedCampaigns = [];
  bool _isLoadingRelatedCampaigns = false;
  bool _hasLoadedRelatedCampaigns = false;

  bool get _isOwner {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.currentUser?.id ==
        (_currentCampaign ?? widget.campaign).creator.id;
  }

  Campaign get _displayCampaign => _currentCampaign ?? widget.campaign;

  void _goHome() {
    GuardedNavigator.pushAndRemoveUntil(context,
      MaterialPageRoute(
        builder: (_) => const MainNavigation(initialScreen: 'home'),
      ),
      (route) => false,
    );
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _goHome();
    }
  }

  @override
  void initState() {
    super.initState();
    initDetailsAnimations();
    _dataManager = DetailsDataManager(
      itemId: widget.campaign.id,
      itemType: 'CAMPAIGN',
    );
    _currentCampaign = widget.campaign;
    _likeCount = widget.campaign.likesCount;

    // Set up real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeUpdates();
      _resolveCampaignImages();
      _loadCreatorSocialState();
    });
  }

  @override
  void dispose() {
    // Clean up real-time listener
    final campaignProvider = Provider.of<CampaignProvider>(
      context,
      listen: false,
    );
    campaignProvider.removeCampaignUpdateCallback(widget.campaign.id);
    disposeDetailsAnimations();
    _dataManager.dispose();
    super.dispose();
  }

  Future<void> _resolveCampaignImages() async {
    if (_displayCampaign.images.isEmpty) {
      return;
    }

    final urls = await _dataManager.resolveMediaUrls(_displayCampaign.images);
    if (mounted) setState(() => _resolvedImageUrls = urls);
  }

  Future<void> _loadRelatedCampaigns() async {
    if (_isLoadingRelatedCampaigns || _hasLoadedRelatedCampaigns) return;
    setState(() => _isLoadingRelatedCampaigns = true);
    final items = await _dataManager.loadSimilarItems(
      limit: 8,
      queryParameters: {
        'category': _displayCampaign.category.name,
        'status': CampaignStatus.active.name,
      },
    );
    if (!mounted) return;
    setState(() {
      _relatedCampaigns = items;
      _hasLoadedRelatedCampaigns = true;
      _isLoadingRelatedCampaigns = false;
    });
  }

  void _setupRealtimeUpdates() {
    final campaignProvider = Provider.of<CampaignProvider>(
      context,
      listen: false,
    );

    // Ensure real-time is started
    campaignProvider.startRealtime();

    // Register callback for this campaign
    campaignProvider.onCampaignUpdate(widget.campaign.id, (updateData) {
      if (mounted && updateData['type'] == 'donation') {
        _handleRealtimeDonation(updateData);
      }
    });
  }

  Future<void> _handleRealtimeDonation(Map<String, dynamic> data) async {
    if (!mounted) return;

    try {
      // Refresh campaign data
      final campaignProvider = Provider.of<CampaignProvider>(
        context,
        listen: false,
      );
      final updatedCampaign = await campaignProvider.getCampaign(
        widget.campaign.id,
      );

      if (updatedCampaign != null && mounted) {
        setState(() {
          _currentCampaign = updatedCampaign;
        });
        await _resolveCampaignImages();

        // Show notification for new donation
        final amount = data['amount'] as double?;
        if (amount != null) {
          final scheme = Theme.of(context).colorScheme;
          AppToast.success(
            context,
            'New donation: ${amount.toStringAsFixed(0)} BYC',
            title: 'Donation received',
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling real-time donation update: $e');
    }
  }

  Future<void> _handleMarkCompleted() async {
    final result = await showDialog<CompletionResult>(
      context: context,
      builder: (_) => CompletionDialog(
        itemType: 'CAMPAIGN',
        itemTitle: _displayCampaign.title,
      ),
    );

    if (result != null && mounted) {
      try {
        const storage = FlutterSecureStorage();
        final baseUrl = await EnvConfig.getBaseUrl();
        final apiClient = ApiClient(baseUrl, storage);

        await apiClient.post(
          '/v1/interactions/CAMPAIGN/${_displayCampaign.id}/complete',
          data: result.toJson(),
        );

        if (mounted) {
          AppToast.success(context, 'Campaign marked as completed!', title: 'Done');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, 'Error: ${e.toString()}');
        }
      }
    }
  }

  Color get _donationGreen => AppTheme.donationColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final donationTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _donationGreen,
        secondary: _donationGreen,
      ),
    );

    return Theme(
      data: donationTheme,
      child: PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        body: SafeArea(
          top: true,
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // App Bar with Campaign Image
              _buildSliverAppBar(),

              // Campaign Header Info
              SliverToBoxAdapter(child: _buildCampaignHeader()),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.horizontalPadding,
                    0,
                    context.horizontalPadding,
                    120,
                  ),
                  child: combinedTransition(
                    Column(
                      children: [
                        _buildCampaignDetailsGrid(),
                        const SizedBox(height: 20),
                        _buildStorySection(),
                        const SizedBox(height: 16),
                        _buildRewardsSection(),
                        const SizedBox(height: 16),
                        _buildUpdatesSection(),
                        const SizedBox(height: 16),
                        _buildSupportersSection(),
                        const SizedBox(height: 16),
                        DetailsCommentsCollapsible(
                          itemId: _displayCampaign.id,
                          itemType: 'CAMPAIGN',
                          backgroundColor: _scheme.surface,
                          onLoadComments: () =>
                              _dataManager.loadComments(limit: 50),
                          onAddComment: _dataManager.addComment,
                          onEditComment: _dataManager.updateComment,
                        ),
                        const SizedBox(height: 16),
                        SimilarItemsSection(
                          title: 'Related Campaigns',
                          leadingIcon: Icons.travel_explore_rounded,
                          isLoading: _isLoadingRelatedCampaigns,
                          hasLoaded: _hasLoadedRelatedCampaigns,
                          items: _relatedCampaigns,
                          onExpand: _loadRelatedCampaigns,
                          listHeight: 150,
                          backgroundColor: _scheme.surface,
                          emptyMessage: 'No related campaigns found.',
                          itemBuilder: (_, item, __) {
                            final title = item is Map
                                ? item['title']?.toString() ?? 'Campaign'
                                : 'Campaign';
                            final raised = item is Map
                                ? item['raisedAmount']?.toString() ??
                                    item['raised']?.toString() ??
                                    '-'
                                : '-';
                            final id = item is Map
                                ? item['id']?.toString()
                                : null;
                            return _RelatedCampaignTile(
                              title: title,
                              raised: raised,
                              onTap: id != null && id.isNotEmpty
                                  ? () => AppRoutes.navigateToCampaignDetailsById(
                                      context,
                                      id,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildActionBar(),
      ),
    ),
    );
  }

  Widget _buildSliverAppBar() {
    final imagesToShow = _resolvedImageUrls.isNotEmpty
        ? _resolvedImageUrls
        : _displayCampaign.images;

    return SliverAppBar(
      expandedHeight: imagesToShow.isNotEmpty ? 320.0 : 250.0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: _handleBack,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Slidable campaign images (uploaded by creator during campaign creation)
            if (_displayCampaign.listingMedia.hasMedia)
              ListingMediaView(
                media: _displayCampaign.listingMedia,
                heroTag: 'campaign-${_displayCampaign.id}',
                height: 320,
                enableZoom: !_displayCampaign.listingMedia.isVideo,
                openFullscreenOnTap: true,
                videoMuted: false,
                autoplayVideo: true,
              )
            else
              _buildCategoryPlaceholder(),
            // Gradient overlay - IgnorePointer so swipes pass through to PageView
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Image counter badge
            if (!_displayCampaign.listingMedia.isVideo &&
                imagesToShow.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${imagesToShow.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.red : null,
          ),
          onPressed: _toggleLike,
          tooltip: _likeCount > 0 ? '$_likeCount likes' : 'Like',
        ),
        IconButton(
          icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () {
            setState(() {
              _isBookmarked = !_isBookmarked;
            });
            _showSnackBar(
              _isBookmarked ? 'Campaign bookmarked!' : 'Bookmark removed',
            );
          },
        ),
        PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text('Share Donation'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag, color: _scheme.error),
                  SizedBox(width: 8),
                  Text('Report Donation'),
                ],
              ),
            ),
            if (_isOwner && _displayCampaign.status == CampaignStatus.active)
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: _scheme.secondary),
                    SizedBox(width: 8),
                    Text('Mark as Completed'),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            if (value == 'share') {
              _shareCampaign();
            } else if (value == 'report') {
              _reportCampaign();
            } else if (value == 'complete') {
              _handleMarkCompleted();
            }
          },
        ),
      ],
    );
  }

  Widget _buildVerificationBanner() {
    return Material(
      color: AppTheme.donationColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: AppTheme.donationColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Under verification',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your campaign will go live after our team reviews it. You can track it from My Campaigns.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: _scheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  AppRoutes.navigateToDonationsHub(context, tabIndex: 1);
                },
                child: const Text('Go to Donations'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignHeader() {
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    final pendingReview =
        _isOwner && _displayCampaign.status == CampaignStatus.draft;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingReview) ...[
            _buildVerificationBanner(),
            const SizedBox(height: 12),
          ],
          // Title and Status Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _displayCampaign.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  if (widget.campaign.isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _scheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'FEATURED',
                        style: TextStyle(
                          color: _scheme.onSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_displayCampaign.status == CampaignStatus.completed)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _scheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _scheme.secondary),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: _scheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              color: _scheme.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_displayCampaign.isUrgent) ...[
                    if (_displayCampaign.isFeatured) const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _scheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'URGENT',
                        style: TextStyle(
                          color: _scheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          CreatorCard(
            userId: _displayCampaign.creator.id,
            name: _displayCampaign.creator.name,
            avatarUrl: _displayCampaign.creator.profileImage,
            rating: _displayCampaign.creator.trustLevel.toDouble(),
            isVerified: _displayCampaign.creator.isVerified,
            subtitle:
                '${_displayCampaign.creator.trustLevelLabel} creator • ${_displayCampaign.creator.location}',
            showButtons: isAuthed,
            onViewProfile: isAuthed ? _viewCreatorProfile : null,
            onMessage: isAuthed ? _openCampaignChat : null,
            onSecondaryAction:
                isAuthed && !_isOwner ? _toggleCreatorFollow : null,
            secondaryButtonLabel: _isFollowing ? 'Following' : 'Follow',
          ),
          const SizedBox(height: 16),

          CampaignProgressCard(
            formattedRaised: _displayCampaign.formattedRaised,
            formattedGoal: _displayCampaign.formattedGoal,
            progressPercentage: _displayCampaign.progressPercentage,
            progressColor: _donationGreen,
            raisedColor: _donationGreen,
            stats: [
              CampaignProgressStat(
                icon: Icons.people,
                value: '${_displayCampaign.supportersCount}',
                label: 'supporters',
              ),
              CampaignProgressStat(
                icon: Icons.schedule,
                value: _formatDeadlineDays(_displayCampaign.deadline),
                label: 'left',
              ),
              CampaignProgressStat(
                icon: Icons.visibility,
                value: '${_displayCampaign.viewsCount}',
                label: 'views',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignDetailsGrid() {
    return DetailCardGrid(
      items: [
        DetailCardItem(
          label: 'Location',
          value: _shortLocation(_displayCampaign.location),
          icon: Icons.location_on_rounded,
        ),
        DetailCardItem(
          label: 'Created',
          value: _formatDaysAgo(_displayCampaign.createdAt),
          icon: Icons.event_rounded,
        ),
        DetailCardItem(
          label: 'Deadline',
          value: _formatDeadlineDays(_displayCampaign.deadline),
          icon: Icons.schedule_rounded,
        ),
      ],
    );
  }

  Widget _buildStorySection() {
    return CollapsibleSection(
      title: 'Campaign Story',
      leadingIcon: Icons.notes_rounded,
      initiallyExpanded: true,
      backgroundColor: _scheme.surface,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpandableDescription(
            description: _displayCampaign.story,
            maxLines: 4,
          ),
          if (_displayCampaign.beneficiaryInfo != null) ...[
            const SizedBox(height: 16),
            _buildDetailRow('Beneficiary', _displayCampaign.beneficiaryInfo!),
          ],
          if (_displayCampaign.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _displayCampaign.tags.map((tag) {
                return Chip(
                  label: Text('#$tag'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _scheme.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: _scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewardsSection() {
    return CollapsibleSection(
      title: 'Rewards',
      leadingIcon: Icons.card_giftcard_rounded,
      initiallyExpanded: _displayCampaign.rewardTiers.isNotEmpty,
      backgroundColor: _scheme.surface,
      content: _displayCampaign.rewardTiers.isEmpty
          ? Text(
              'This campaign does not offer reward tiers.',
              style: TextStyle(
                color: _scheme.onSurface.withValues(alpha: 0.65),
              ),
            )
          : Column(
              children: _displayCampaign.rewardTiers.map((tier) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRewardTierSummary(tier),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRewardTierSummary(RewardTier tier) {
    return ActionShadowCard(
      onTap: tier.isAvailable ? () => _selectRewardTier(tier) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tier.isAvailable
                  ? _scheme.primary.withValues(alpha: 0.12)
                  : _scheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tier.formattedMinimumDonation,
              style: TextStyle(
                color: tier.isAvailable
                    ? _scheme.primary
                    : _scheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tier.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _scheme.onSurface.withValues(alpha: 0.68),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tier.availabilityText,
                  style: TextStyle(
                    color: tier.isAvailable ? _scheme.secondary : _scheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesSection() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isFounder = auth.currentUser?.id == _displayCampaign.creator.id;

    return CollapsibleSection(
      title: 'Updates',
      leadingIcon: Icons.update_rounded,
      initiallyExpanded: _displayCampaign.updates.isNotEmpty || isFounder,
      backgroundColor: _scheme.surface,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFounder)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _showPostUpdateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Post Update'),
              ),
            ),
          if (isFounder) const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: CampaignApi(
              ApiClient(EnvConfig.defaultBaseUrl, const FlutterSecureStorage()),
            ).getCampaignUpdates(_displayCampaign.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: const BybataLoader(),
                );
              }
              if (items.isEmpty && _displayCampaign.updates.isEmpty) {
                return Text(
                  'No updates yet.',
                  style: TextStyle(
                    color: _scheme.onSurface.withValues(alpha: 0.65),
                  ),
                );
              }
              if (items.isNotEmpty) {
                return Column(
                  children: items
                      .take(4)
                      .map((u) => _buildApiUpdateSummary(u))
                      .toList(),
                );
              }
              return Column(
                children: _displayCampaign.updates
                    .take(4)
                    .map(_buildModelUpdateSummary)
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApiUpdateSummary(Map<String, dynamic> update) {
    final title = update['title']?.toString() ?? 'Campaign update';
    final content = update['content']?.toString() ?? '';
    final createdAt = update['createdAt']?.toString();
    return _buildUpdateTile(title, content, createdAt);
  }

  Widget _buildModelUpdateSummary(CampaignUpdate update) {
    return _buildUpdateTile(
      update.title,
      update.content,
      update.createdAt.toIso8601String(),
    );
  }

  Widget _buildUpdateTile(String title, String content, String? createdAt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ShadowCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _scheme.onSurface.withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatDate(DateTime.tryParse(createdAt) ?? DateTime.now()),
                style: TextStyle(
                  color: _scheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupportersSection() {
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    final donations = _displayCampaign.donations.take(5).toList();
    return CollapsibleSection(
      title: 'Supporters',
      leadingIcon: Icons.groups_rounded,
      initiallyExpanded: isAuthed && donations.isNotEmpty,
      backgroundColor: _scheme.surface,
      content: !isAuthed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_displayCampaign.supportersCount} people have supported this campaign.',
                  style: TextStyle(
                    color: _scheme.onSurface.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => AppRoutes.requireSignIn(context),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Sign in to see supporters'),
                ),
              ],
            )
          : donations.isEmpty
          ? Text(
              'No supporters yet.',
              style: TextStyle(
                color: _scheme.onSurface.withValues(alpha: 0.65),
              ),
            )
          : Column(
              children: donations.map((donation) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _scheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      donation.donorName.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(
                    donation.donorName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_formatDate(donation.donatedAt)),
                  trailing: Text(
                    donation.formattedAmount,
                    style: TextStyle(
                      color: _scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _showPostUpdateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Update'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Share a progress update…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Images (optional)'),
                  TextButton.icon(
                    onPressed: () async {
                      final XFile? file = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                        maxWidth: 1920,
                      );
                      if (file != null) {
                        setState(() {
                          _updateImages.add(file.path);
                        });
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _updateImages.map((path) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: File(path).existsSync()
                            ? Image.file(
                                File(path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: _scheme.surfaceContainerHighest,
                              ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: _scheme.error,
                          ),
                          onPressed: () {
                            setState(() {
                              _updateImages.remove(path);
                            });
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              try {
                final client = ApiClient(
                  EnvConfig.defaultBaseUrl,
                  const FlutterSecureStorage(),
                );
                final api = CampaignApi(client);
                final storageRepo = StorageRepository(client.dio);
                final uploadedKeys = <String>[];
                for (final path in _updateImages) {
                  if (File(path).existsSync()) {
                    final bytes = await File(path).readAsBytes();
                    final lower = path.toLowerCase();
                    final isPng = lower.endsWith('.png');
                    final isJpg =
                        lower.endsWith('.jpg') || lower.endsWith('.jpeg');
                    final ext = isPng
                        ? 'png'
                        : isJpg
                        ? 'jpg'
                        : 'bin';
                    final contentType = isPng
                        ? 'image/png'
                        : isJpg
                        ? 'image/jpeg'
                        : 'application/octet-stream';
                    final meta = await storageRepo.createUploadUrl(
                      domain: 'campaign-updates',
                      ext: ext,
                      contentType: contentType,
                    );
                    final uploadUrl =
                        (meta['uploadUrl'] ?? meta['url'] ?? '') as String;
                    final key =
                        (meta['key'] ?? meta['objectKey'] ?? meta['path'] ?? '')
                            as String;
                    if (uploadUrl.isNotEmpty && key.isNotEmpty) {
                      await storageRepo.uploadToSignedUrl(
                        uploadUrl: uploadUrl,
                        bytes: bytes,
                        contentType: contentType,
                      );
                      uploadedKeys.add(key);
                    }
                  }
                }
                await api.postCampaignUpdate(
                  _displayCampaign.id,
                  type: 'TEXT',
                  content: text,
                  mediaKeys: uploadedKeys.isNotEmpty ? uploadedKeys : null,
                );
                if (mounted && ctx.mounted) {
                  Navigator.pop(ctx);
                  AppToast.success(ctx, 'Update posted');
                  _updateImages = [];
                  setState(() {});
                }
              } catch (e) {
                if (ctx.mounted) {
                  AppToast.error(ctx, 'Failed to post update');
                }
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = auth.currentUser?.id == _displayCampaign.creator.id;
    return ContextualActionBar(
      accentColor: _donationGreen,
      actions: [
        ContextualAction(
          label: 'Share',
          icon: Icons.share_rounded,
          onPressed: _shareCampaign,
        ),
        if (isOwner)
          ContextualAction(
            label: 'Manage',
            icon: Icons.edit_rounded,
            isPrimary: true,
            flex: 2,
            onPressed: () => AppRoutes.navigateToCampaignManagement(
              context,
              widget.campaign,
            ),
          )
        else if (!auth.isAuthenticated)
          ContextualAction(
            label: CampaignSupportCompliance.blocksInAppDonations
                ? 'Support on web'
                : 'Sign in to Donate',
            icon: Icons.login_rounded,
            isPrimary: true,
            flex: 2,
            onPressed: () {
              if (CampaignSupportCompliance.blocksInAppDonations) {
                CampaignSupportCompliance.openWebSupport(
                  context,
                  campaignId: _displayCampaign.id,
                  campaign: _displayCampaign,
                );
              } else {
                AppRoutes.requireSignIn(context);
              }
            },
          )
        else
          ContextualAction(
            label: CampaignSupportCompliance.detailPrimaryLabel(
              isAuthenticated: true,
            ),
            icon: Icons.volunteer_activism_rounded,
            isPrimary: true,
            flex: 2,
            onPressed: _donateToCampaign,
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: _scheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _shortLocation(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown') return 'Remote';
    if (trimmed.length <= 18) return trimmed;
    return '${trimmed.substring(0, 16)}…';
  }

  String _formatDaysAgo(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  String _formatDeadlineDays(DateTime deadline) {
    if (_displayCampaign.isExpired) return 'Ended';
    final days = deadline.difference(DateTime.now()).inDays;
    if (days < 0) return 'Ended';
    if (days == 0) return 'Today';
    if (days == 1) return '1 day';
    return '$days days';
  }

  String _formatDate(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  void _donateToCampaign() {
    CampaignSupportCompliance.handleSupportTap(
      context,
      campaign: _displayCampaign,
    );
  }

  void _shareCampaign() {
    final campaign = _displayCampaign;
    ShareUtils.shareCampaign(
      context,
      id: campaign.id.toString(),
      title: campaign.title,
    );
  }

  void _reportCampaign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Donation'),
        content: const Text('Are you sure you want to report this donation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Donation reported');
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _selectRewardTier(RewardTier tier) {
    _showSnackBar('Selected reward tier: ${tier.title}');
  }

  Future<void> _loadCreatorSocialState() async {
    if (_isOwner) return;
    final creatorId = _displayCampaign.creator.id;
    if (creatorId.isEmpty) return;
    try {
      final following = await UserSocialService.instance.isFollowing(creatorId);
      if (mounted) setState(() => _isFollowing = following);
    } catch (_) {}
  }

  Future<void> _toggleCreatorFollow() async {
    if (AppRoutes.requireSignIn(context)) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final creatorId = _displayCampaign.creator.id;
    if (creatorId.isEmpty || creatorId == auth.currentUser!.id) return;

    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !wasFollowing);
    try {
      if (wasFollowing) {
        await UserSocialService.instance.unfollow(creatorId);
      } else {
        await UserSocialService.instance.follow(creatorId);
      }
      if (mounted) {
        _showSnackBar(_isFollowing ? 'Followed' : 'Unfollowed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = wasFollowing);
        _showSnackBar('Failed to update follow status');
      }
    }
  }

  Future<void> _toggleLike() async {
    if (AppRoutes.requireSignIn(context)) return;
    try {
      final provider = Provider.of<CampaignProvider>(context, listen: false);
      final res = _isLiked
          ? await provider.unlikeCampaign(_displayCampaign.id)
          : await provider.likeCampaign(_displayCampaign.id);
      final likes = res['likes'] as int?;
      if (mounted && likes != null) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount = likes;
        });
      }
    } catch (_) {
      if (mounted) _showSnackBar('Could not update like');
    }
  }

  void _viewCreatorProfile() {
    if (AppRoutes.requireSignIn(context)) return;
    final creator = _displayCampaign.creator;
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: creator.id,
          user: TradeUser(
            id: creator.id,
            name: creator.name,
            username: creator.name,
            avatar: creator.profileImage,
            rating: creator.trustLevel.toDouble(),
            completedTrades: creator.campaignsCreated,
            joinedDate: DateTime.now(),
            isVerified: creator.isVerified,
          ),
        ),
      ),
    );
  }

  void _openCampaignChat() async {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.currentUser?.id;

      if (currentUserId == null) {
        AppRoutes.showLoginRequired(context);
        return;
      }

      // Don't allow chatting with yourself
      if (currentUserId == _displayCampaign.creator.id) {
        _showSnackBar('Cannot chat with yourself');
        return;
      }

      // Try to find existing conversation in cache (refresh deferred to chat screen).
      final existing = chatProvider.findConversationInCache(
        contextId: _displayCampaign.id,
        partnerId: _displayCampaign.creator.id,
      );

      if (mounted) {
        GuardedNavigator.push(context,
          MaterialPageRoute(
            builder: (context) => DonationChatScreen(
              campaign: _displayCampaign,
              partnerId: _displayCampaign.creator.id,
              partnerName: _displayCampaign.creator.name,
              existingConversation: existing,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Failed to open chat: $e');
    }
  }

  void _showSnackBar(String message) {
    AppToast.show(context, message);
  }

  Widget _buildCategoryPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _donationGreen.withValues(alpha: 0.8),
            _donationGreen,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _scheme.surface.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _displayCampaign.categoryIcon,
              size: 60,
              color: _scheme.onPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _scheme.surface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _displayCampaign.categoryLabel,
              style: TextStyle(
                color: _scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCampaignTile extends StatelessWidget {
  final String title;
  final String raised;
  final VoidCallback? onTap;

  const _RelatedCampaignTile({
    required this.title,
    required this.raised,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.volunteer_activism_rounded, color: AppTheme.donationColor),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              'Raised: $raised',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
