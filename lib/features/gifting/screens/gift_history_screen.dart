import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../core/widgets/hub_fluid_tab_switcher.dart';
import '../../../core/widgets/hub_mine_empty_state.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../../chat/models/chat_conversation.dart';
import '../../chat/providers/chat_provider.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../trade/models/trade_models.dart';
import '../models/gift_models.dart' as gift_models;
import '../providers/gift_provider.dart';
import 'gift_request_chat_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class GiftHistoryScreen extends StatefulWidget {
  const GiftHistoryScreen({super.key});

  @override
  State<GiftHistoryScreen> createState() => _GiftHistoryScreenState();
}

class _GiftHistoryScreenState extends State<GiftHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const _tabLabels = ['All', 'Given', 'Received', 'Chains'];

  late TabController _tabController;

  List<GiftClaim> _allHistory = [];
  List<GiftClaim> _filteredHistory = [];
  bool _isInitialLoading = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_onTabControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  void _onTabControllerUpdate() {
    if (_tabController.indexIsChanging) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _applyCurrentFilter();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerUpdate);
    _tabController.dispose();
    super.dispose();
  }

  String get _selectedFilter => _tabLabels[_tabController.index];

  void _loadHistory() {
    final giftProvider = Provider.of<GiftProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    () async {
      if (mounted) setState(() => _isInitialLoading = true);
      if (giftProvider.giftHistory.isEmpty && !giftProvider.isLoading) {
        await giftProvider.loadGiftHistory();
      }
      await giftProvider.loadGiftRequests(force: true);
      final currentUserId = auth.currentUser?.id;
      final items = giftProvider.giftHistory.toList();
      if (mounted) {
        setState(() {
          _allHistory = items;
          _filteredHistory = _applyFilters(items, currentUserId);
          _isInitialLoading = false;
        });
      }
    }();
  }

  Future<void> _refreshHistory() async {
    final giftProvider = Provider.of<GiftProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (mounted) setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        giftProvider.loadGiftHistory(force: true),
        giftProvider.loadGiftRequests(force: true),
      ]);
      final currentUserId = auth.currentUser?.id;
      final items = giftProvider.giftHistory.toList();
      if (mounted) {
        setState(() {
          _allHistory = items;
          _filteredHistory = _applyFilters(items, currentUserId);
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _applyCurrentFilter() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _filteredHistory = _applyFilters(_allHistory, auth.currentUser?.id);
    });
  }

  List<GiftClaim> _applyFilters(List<GiftClaim> history, String? currentUserId) {
    return history.where((claim) {
      if (_selectedFilter != 'All') {
        final isGiven =
            currentUserId != null && claim.gift.giver.id == currentUserId;
        final isChain = claim.gift.isChainGift == true;
        if (_selectedFilter == 'Given' && !isGiven) return false;
        if (_selectedFilter == 'Received' && isGiven) return false;
        if (_selectedFilter == 'Chains' && !isChain) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.claimedAt.compareTo(a.claimedAt));
  }

  Map<String, int> _calculateStats() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    var totalKarma = 0;
    var given = 0;
    var received = 0;
    var chains = 0;
    for (final claim in _filteredHistory) {
      totalKarma += claim.karmaAwarded;
      final isGiven =
          currentUserId != null && claim.gift.giver.id == currentUserId;
      if (isGiven) {
        given++;
      } else {
        received++;
      }
      if (claim.gift.isChainGift) chains++;
    }
    return {
      'totalKarma': totalKarma,
      'given': given,
      'received': received,
      'chains': chains,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: SettingsUi.pageBackground(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HubScreenTopBar(
            title: 'Gift History',
            onBack: () => Navigator.pop(context),
            trailingActions: [
              HubTopBarIconButton(
                icon: Icons.refresh_rounded,
                onTap: _isRefreshing ? () {} : _refreshHistory,
                isDark: isDark,
                iconColor: AppTheme.giftColor,
              ),
            ],
          ),
          Consumer<GiftProvider>(
            builder: (context, giftProvider, _) {
              final stats = _calculateStats();
              return _buildSummaryStrip(stats);
            },
          ),
          HubFluidTabSwitcher(
            controller: _tabController,
            labels: _tabLabels,
          ),
          Expanded(
            child: Consumer<GiftProvider>(
              builder: (context, giftProvider, _) =>
                  _buildHistoryBody(giftProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(Map<String, int> stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _summaryChip('KARMA', '${stats['totalKarma']}', Icons.bolt_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryChip('Given', '${stats['given']}', Icons.volunteer_activism_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryChip('Got', '${stats['received']}', Icons.card_giftcard_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryChip('Chains', '${stats['chains']}', Icons.link_rounded),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.giftColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.giftColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.giftColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryBody(GiftProvider giftProvider) {
    if (_isInitialLoading && _filteredHistory.isEmpty) {
      return const Center(child: BybataLoader(message: 'Loading history…'));
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    final incomingRequesters =
        _getIncomingRequesters(giftProvider, currentUserId);
    final showRequesters =
        _selectedFilter == 'All' && incomingRequesters.isNotEmpty;

    if (_filteredHistory.isEmpty && !showRequesters) {
      return RefreshIndicator(
        color: AppTheme.giftColor,
        onRefresh: _refreshHistory,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: HubMineEmptyState(
                accentColor: AppTheme.giftColor,
                icon: Icons.history_rounded,
                title: 'No gift history yet',
                subtitle: _selectedFilter == 'All'
                    ? 'Gifts you give or receive will show up here.'
                    : 'Nothing in this tab yet — try another filter.',
                buttonLabel: 'Browse gifts',
                onCreate: () => Navigator.pop(context),
                showCreateButton: false,
                hints: const [
                  'Given — gifts you shared',
                  'Received — gifts you claimed',
                  'Chains — pay-it-forward gifts',
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.giftColor,
      onRefresh: _refreshHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: (showRequesters ? 1 : 0) + _filteredHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (showRequesters && index == 0) {
            return _buildRequestersBanner(incomingRequesters);
          }
          final claim =
              _filteredHistory[showRequesters ? index - 1 : index];
          return _buildHistoryTile(claim);
        },
      ),
    );
  }

  List<gift_models.GiftRequest> _getIncomingRequesters(
    GiftProvider giftProvider,
    String? currentUserId,
  ) {
    if (currentUserId == null) return [];
    final seen = <String>{};
    return giftProvider.giftRequests.where((r) {
      if (r.gift.giver.id != currentUserId) return false;
      if (seen.contains(r.requester.id)) return false;
      seen.add(r.requester.id);
      return true;
    }).toList();
  }

  Widget _buildRequestersBanner(List<gift_models.GiftRequest> requests) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.giftColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.giftColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: AppTheme.giftColor),
              const SizedBox(width: 8),
              Text(
                'Pending requesters',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...requests.take(3).map(
                (request) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.giftColor.withValues(alpha: 0.12),
                    child: Text(
                      (request.requester.name.isNotEmpty
                              ? request.requester.name[0]
                              : '?')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.giftColor,
                      ),
                    ),
                  ),
                  title: Text(
                    request.requester.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    request.gift.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    color: AppTheme.giftColor,
                    onPressed: () => _startChatWithRequester(request),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(GiftClaim claim) {
    final scheme = Theme.of(context).colorScheme;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    final isGiven =
        currentUserId != null && claim.gift.giver.id == currentUserId;
    final isChain = claim.gift.isChainGift;
    final partnerLabel = isGiven
        ? 'To ${claim.gift.claimedBy?.name ?? 'recipient'}'
        : 'From ${claim.gift.giver.name}';

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showGiftDetails(claim, isGiven),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: claim.gift.type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  claim.gift.type.icon,
                  color: claim.gift.type.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.gift.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      partnerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _tagChip(
                          isGiven ? 'Given' : 'Received',
                          isGiven ? AppTheme.successColor : AppTheme.tradeColor,
                        ),
                        if (isChain)
                          _tagChip('Chain', AppTheme.karmaColor),
                        Text(
                          _formatDateAgo(claim.claimedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.karmaColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${claim.karmaAwarded}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.karmaColor,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(Icons.chat_bubble_outline_rounded,
                        size: 20, color: AppTheme.giftColor),
                    onPressed: () => _startChat(claim, isGiven),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _startChatWithRequester(gift_models.GiftRequest request) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser?.id == null) return;
    final partnerId = request.requester.id;
    if (partnerId.isEmpty || partnerId == auth.currentUser!.id) return;
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => GiftRequestChatScreen(
          request: request,
          partnerId: partnerId,
          partnerName: request.requester.name,
        ),
      ),
    );
  }

  void _navigateToPayItForward(String chainParentId) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    GuardedNavigator.pushNamed(context,
      AppConstants.createGiftRoute,
      arguments: {'chainParentId': chainParentId},
    );
  }

  void _showGiftDetails(GiftClaim claim, bool isGiven) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GiftDetailsBottomSheet(
        claim: claim,
        isGiven: isGiven,
        onChatPressed: () {
          Navigator.pop(context);
          _startChat(claim, isGiven);
        },
        onProfilePressed: () {
          Navigator.pop(context);
          _openPartnerProfile(claim, isGiven);
        },
        onPayItForwardPressed: !isGiven && (claim.gift.isChainGift == true)
            ? () {
                Navigator.pop(context);
                _navigateToPayItForward(claim.gift.id);
              }
            : null,
      ),
    );
  }

  void _openPartnerProfile(GiftClaim claim, bool isGiven) {
    final partner = isGiven ? claim.gift.claimedBy : claim.gift.giver;
    if (partner == null) return;
    final tradeUser = TradeUser(
      id: partner.id,
      name: partner.name,
      username: partner.username,
      avatar: partner.profileImageUrl,
      rating: partner.rating,
      completedTrades: partner.completedGifts,
      joinedDate: partner.joinedDate,
      isVerified: partner.isVerified,
      karmaPoints: partner.karmaPoints,
      trustBadges: const [],
    );
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: partner.id, user: tradeUser),
      ),
    );
  }

  Future<void> _startChat(GiftClaim claim, bool isGiven) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    if (currentUserId == null) return;

    final partnerId =
        isGiven ? (claim.gift.claimedBy?.id ?? '') : claim.gift.giver.id;
    final partnerName = isGiven
        ? (claim.gift.claimedBy?.name ?? 'Recipient')
        : claim.gift.giver.name;
    if (partnerId.isEmpty || partnerId == currentUserId) return;

    final requester = isGiven
        ? (claim.gift.claimedBy ?? _createGiftUserFromAuth(auth, currentUserId))
        : _createGiftUserFromAuth(auth, currentUserId);

    final request = gift_models.GiftRequest(
      id: claim.id,
      giftId: claim.giftId,
      gift: claim.gift,
      requester: requester,
      message: null,
      createdAt: claim.claimedAt,
      status: gift_models.GiftRequestStatus.approved,
      respondedAt: null,
      responseMessage: null,
    );

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final existing = chatProvider.findConversationInCache(
      contextId: claim.giftId,
      partnerId: partnerId,
    );

    if (!mounted) return;
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => GiftRequestChatScreen(
          request: request,
          partnerId: partnerId,
          partnerName: partnerName,
          existingConversation: existing,
        ),
      ),
    );
  }

  gift_models.GiftUser _createGiftUserFromAuth(
      AuthProvider auth, String userId) {
    final user = auth.currentUser;
    if (user == null) {
      return gift_models.GiftUser(
        id: userId,
        name: 'Unknown User',
        username: '@unknown',
        rating: 0.0,
        completedGifts: 0,
        karmaPoints: 0,
        joinedDate: DateTime.now(),
        isVerified: false,
      );
    }
    final displayName =
        user.displayName.isNotEmpty ? user.displayName : user.email;
    return gift_models.GiftUser(
      id: user.id,
      name: displayName,
      username: '@${displayName.replaceAll(' ', '').toLowerCase()}',
      rating: user.rating,
      completedGifts: 0,
      karmaPoints: user.karmaPoints,
      joinedDate: user.createdAt,
      isVerified: user.isVerified,
    );
  }

  String _formatDateAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// --- Gift details bottom sheet (unchanged logic, hub-themed) ---

class _GiftDetailsBottomSheet extends StatelessWidget {
  final GiftClaim claim;
  final bool isGiven;
  final VoidCallback onChatPressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onPayItForwardPressed;

  const _GiftDetailsBottomSheet({
    required this.claim,
    required this.isGiven,
    required this.onChatPressed,
    this.onProfilePressed,
    this.onPayItForwardPressed,
  });

  Color get _accent => AppTheme.giftColor;

  @override
  Widget build(BuildContext context) {
    final gift = claim.gift;
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gift.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            gift.category.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (gift.description.isNotEmpty) ...[
                        Text(
                          gift.description,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: scheme.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildInfoSection(
                        context,
                        title: isGiven ? 'Recipient' : 'Giver',
                        user: isGiven ? gift.claimedBy : gift.giver,
                        onProfilePressed: onProfilePressed,
                      ),
                      const SizedBox(height: 16),
                      _detailRow(context, Icons.bolt_rounded, 'Karma',
                          '${claim.karmaAwarded}'),
                      _detailRow(context, Icons.calendar_today_rounded, 'Claimed',
                          _formatDateTime(claim.claimedAt)),
                      if (gift.location != null && gift.location!.isNotEmpty)
                        _detailRow(context, Icons.location_on_outlined, 'Location',
                            gift.location!),
                      if (gift.metadata['redemptionDetails'] != null &&
                          gift.metadata['redemptionDetails']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Redemption details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          gift.metadata['redemptionDetails'].toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onPayItForwardPressed != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onPayItForwardPressed,
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Pay it forward'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.karmaColor,
                              side: const BorderSide(color: AppTheme.karmaColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (onProfilePressed != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onProfilePressed,
                                icon: const Icon(Icons.person_outline_rounded),
                                label: const Text('Profile'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _accent,
                                  side: BorderSide(color: _accent),
                                ),
                              ),
                            ),
                          if (onProfilePressed != null)
                            const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onChatPressed,
                              icon: const Icon(Icons.chat_rounded),
                              label: const Text('Chat'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required gift_models.GiftUser? user,
    VoidCallback? onProfilePressed,
  }) {
    if (user == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onProfilePressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildAvatar(user),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (user.isVerified)
                    Icon(Icons.verified_rounded,
                        color: AppTheme.tradeColor, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(gift_models.GiftUser user) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: _accent.withValues(alpha: 0.12),
        child: ClipOval(
          child: CachedMediaImage(
            mediaKey: user.profileImageUrl!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorWidget: Text(initial,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.giftColor)),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: _accent.withValues(alpha: 0.12),
      child: Text(initial,
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.giftColor)),
    );
  }

  Widget _detailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.giftColor),
          const SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
