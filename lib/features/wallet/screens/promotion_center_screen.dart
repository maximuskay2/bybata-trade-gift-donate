import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:ui'; // For BackdropFilter
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../donations/providers/campaign_provider.dart';
import '../../gifting/providers/gift_provider.dart';
import '../../trade/providers/trade_backend_provider.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import '../utils/promotion_error_handler.dart';
import '../../../core/constants/ad_placement_keys.dart';
import '../../../core/widgets/enhanced_form_field.dart';
import '../../../core/widgets/cached_media_image.dart';
import 'edit_ad_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class PromotionCenterScreen extends StatefulWidget {
  final String? initialType;
  
  const PromotionCenterScreen({super.key, this.initialType});

  @override
  State<PromotionCenterScreen> createState() => _PromotionCenterScreenState();
}

class _PromotionCenterScreenState extends State<PromotionCenterScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final WalletService _walletService = WalletService();
  final TradeBackendProvider _tradeProvider = TradeBackendProvider();
  GiftProvider? _giftProvider;
  CampaignProvider? _campaignProvider;
  ApiClient? _apiClient;

  bool _loadingTrades = false;
  String? _tradesError;
  List<Map<String, dynamic>> _myTrades = [];

  // Ambient Orbs
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _orbAnimation = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';
    await _ensureApiClient();
    if (!_walletService.isInitialized && userId.isNotEmpty) {
      await _walletService.initializeWallet(userId);
    }
    await _walletService.refreshPromotionData();
    if (!mounted) return;
    await Future.wait([
      if (_giftProvider != null) _giftProvider!.loadMyGifts(force: true),
      if (_campaignProvider != null) _campaignProvider!.loadMyCampaigns(force: true),
      _loadMyTrades(userId),
    ]);
  }

  Future<void> _ensureApiClient() async {
    if (_apiClient != null) return;
    const storage = FlutterSecureStorage();
    final baseUrl = await EnvConfig.getBaseUrl();
    _apiClient = ApiClient(baseUrl, storage);
    _giftProvider = GiftProvider(_apiClient!);
    _campaignProvider = CampaignProvider(_apiClient!);
    if (mounted) setState(() {});
  }

  Future<void> _loadMyTrades(String userId) async {
    if (userId.isEmpty) return;
    setState(() {
      _loadingTrades = true;
      _tradesError = null;
    });
    try {
      final response = await _tradeProvider.listMyTrades(ownerId: userId, page: 1, size: 20);
      final items = (response['items'] as List?) ?? [];
      setState(() {
        _myTrades = items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    } catch (e) {
      setState(() {
        _tradesError = 'Failed to load trades: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingTrades = false);
      }
    }
  }

  // --- 3D UI ENGINE ---
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, required bool isDark, double radius = 24}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.6),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Promotion Center',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary; // Blue
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    final orbOpacity = isDark ? 0.25 : 0.12;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _walletService),
        ChangeNotifierProvider.value(value: _tradeProvider),
        if (_giftProvider != null) ChangeNotifierProvider.value(value: _giftProvider!),
        if (_campaignProvider != null) ChangeNotifierProvider.value(value: _campaignProvider!),
      ],
      child: Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        appBar: _buildGlassAppBar(isDark),
        body: Stack(
          children: [
            // Ambient Background Orbs
            Positioned(
              top: MediaQuery.of(context).size.height * 0.1, right: -100,
              child: AnimatedBuilder(
                animation: _orbAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * _orbAnimation.value),
                    child: Container(
                      width: 350, height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: orbOpacity),
                        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: orbOpacity + 0.05), blurRadius: 120)],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.2, left: -80,
              child: AnimatedBuilder(
                animation: _orbAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -30 * _orbAnimation.value),
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orangeAccent.withValues(alpha: orbOpacity - 0.05),
                        boxShadow: [BoxShadow(color: Colors.orangeAccent.withValues(alpha: orbOpacity), blurRadius: 90)],
                      ),
                    ),
                  );
                },
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(primaryColor, isDark),
                  const SizedBox(height: 20),
                  _buildTabBar(primaryColor, isDark),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildTradeTab(isDark, primaryColor),
                        _buildGiftTab(isDark, primaryColor),
                        _buildCampaignTab(isDark, primaryColor),
                        _buildAdsTab(isDark, primaryColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Floating Create Ad Button
            Align(
              alignment: Alignment.centerRight,
              child: _buildCreateAdButton(primaryColor, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _buildGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(20),
        radius: 24,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryColor.withValues(alpha: 0.3), primaryColor.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 2),
              ),
              child: Icon(Icons.rocket_launch_rounded, color: primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boost your listings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pay BYC to show your trade, gift, or campaign higher in feeds. Use Create Ad for custom campaigns with links.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(Color primaryColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(4),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: primaryColor, 
              boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Trades'),
              Tab(text: 'Gifts'),
              Tab(text: 'Campaigns'),
              Tab(text: 'Ads'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAdButton(Color primaryColor, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (!auth.isAuthenticated) {
          AppRoutes.navigateToCreateTrade(context, routeOverride: '/wallet/create-ad');
          return;
        }
        await GuardedNavigator.pushNamed(context, '/wallet/create-ad');
        if (mounted) await _refreshAll();
      },
      child: Container(
        height: 140,
        width: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
          boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(-4, 4))],
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            const SizedBox(height: 12),
            RotatedBox(
              quarterTurns: 3,
              child: const Text(
                'CREATE AD',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB CONTENT ---

  Widget _buildTradeTab(bool isDark, Color primaryColor) {
    return _buildListingTab(
      title: 'Your Trades',
      description: 'Select a trade to boost. Drafts saved with BYC promo appear here—add funds and boost to publish.',
      isLoading: _loadingTrades,
      error: _tradesError,
      isDark: isDark,
      primaryColor: primaryColor,
      items: _myTrades
          .map(
            (e) => _ListingItem(
              id: e['id']?.toString() ?? '',
              title: e['title']?.toString() ?? 'Untitled trade',
              imageMediaKey: _firstMediaKeyFromMap(e),
            ),
          )
          .toList(),
      onBoost: (item) => _openPromotionPicker(referenceType: 'trade', referenceId: item.id, title: item.title, isDark: isDark),
    );
  }

  Widget _buildGiftTab(bool isDark, Color primaryColor) {
    if (_giftProvider == null) return _buildLoadingState(primaryColor);
    return Consumer<GiftProvider>(
      builder: (context, giftProvider, child) {
        final items = giftProvider.myGifts
            .map(
              (gift) => _ListingItem(
                id: gift.id,
                title: gift.title,
                imageMediaKey:
                    gift.imageUrls.isNotEmpty ? gift.imageUrls.first : null,
              ),
            )
            .toList();
        return _buildListingTab(
          title: 'Your Gifts',
          description: 'Boost your gifts to reach more people.',
          isLoading: giftProvider.isLoading,
          error: giftProvider.myGiftsError,
          isDark: isDark,
          primaryColor: primaryColor,
          items: items,
          onBoost: (item) => _openPromotionPicker(referenceType: 'gift', referenceId: item.id, title: item.title, isDark: isDark),
        );
      },
    );
  }

  Widget _buildCampaignTab(bool isDark, Color primaryColor) {
    if (_campaignProvider == null) return _buildLoadingState(primaryColor);
    return Consumer<CampaignProvider>(
      builder: (context, campaignProvider, child) {
        final items = campaignProvider.myCampaigns
            .map(
              (campaign) => _ListingItem(
                id: campaign.id,
                title: campaign.title,
                imageMediaKey:
                    campaign.images.isNotEmpty ? campaign.images.first : null,
              ),
            )
            .toList();
        return _buildListingTab(
          title: 'Your Campaigns',
          description: 'Promote your cause to get more support.',
          isLoading: campaignProvider.isLoading,
          error: campaignProvider.error,
          isDark: isDark,
          primaryColor: primaryColor,
          items: items,
          onBoost: (item) => _openPromotionPicker(referenceType: 'campaign', referenceId: item.id, title: item.title, isDark: isDark),
        );
      },
    );
  }

  Widget _buildListingTab({
    required String title,
    required String description,
    required bool isLoading,
    required String? error,
    required List<_ListingItem> items,
    required void Function(_ListingItem item) onBoost,
    required bool isDark,
    required Color primaryColor,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: primaryColor,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          _buildGlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isLoading) _buildLoadingState(primaryColor)
          else if (error != null) _buildErrorState(error)
          else if (items.isEmpty) _buildEmptyState('No items found to promote.', isDark)
          else ...items.map((item) => _buildListingCard(item, onBoost, isDark, primaryColor)),
          const SizedBox(height: 80), // Padding for scrolling past ad button
        ],
      ),
    );
  }

  Widget _buildAdsTab(bool isDark, Color primaryColor) {
    return Consumer<WalletService>(
      builder: (context, walletService, child) {
        final ads = [...walletService.scheduledAds]
          ..sort((a, b) {
            final sa = a['status']?.toString() ?? '';
            final sb = b['status']?.toString() ?? '';
            if (sa == 'ACTIVE' && sb != 'ACTIVE') return -1;
            if (sb == 'ACTIVE' && sa != 'ACTIVE') return 1;
            return 0;
          });
        return RefreshIndicator(
          onRefresh: _refreshAll,
          color: primaryColor,
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            _buildGlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your ads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                    'Custom creatives in feeds. Select multiple placements when creating — each surface adds to your BYC total.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (ads.isEmpty) _buildEmptyState('No ads yet. Tap CREATE AD to run in one or more feeds.', isDark),
            ...ads.map((ad) => _buildAdCard(ad, isDark, primaryColor)),
            const SizedBox(height: 80),
          ],
        ),
        );
      },
    );
  }

  // --- CARDS & ITEMS ---

  Widget _buildListingCard(_ListingItem item, void Function(_ListingItem item) onBoost, bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100]!,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                    width: 2,
                  ),
                ),
                child: item.imageMediaKey != null &&
                        item.imageMediaKey!.trim().isNotEmpty
                    ? CachedMediaImage(
                        mediaKey: item.imageMediaKey,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        placeholder: _listingThumbnailPlaceholder(isDark),
                        errorWidget: _listingThumbnailPlaceholder(isDark),
                      )
                    : _listingThumbnailPlaceholder(isDark),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 2),
                  Text('ID: ${item.id.substring(0, item.id.length > 8 ? 8 : item.id.length)}...', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => onBoost(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Text('BOOST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad, bool isDark, Color primaryColor) {
    final status = ad['status']?.toString() ?? 'SCHEDULED';
    final keysRaw = ad['placementKeys'];
    final placementKeys = keysRaw is List
        ? keysRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final singleKey = ad['placementKey']?.toString();
    if (placementKeys.isEmpty && singleKey != null && singleKey.isNotEmpty) {
      placementKeys.add(singleKey);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdThumbnail(ad, isDark),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ad['title']?.toString() ?? 'Ad Campaign',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          _buildStatusChip(status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ad['description']?.toString() ?? 'No description',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if ((ad['destinationUrl']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.link_rounded, size: 14, color: primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ad['destinationUrl'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            if (placementKeys.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: placementKeys.map((k) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(k, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primaryColor)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            if (status == 'PENDING_REVIEW')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Awaiting admin approval before this ad can go live.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.amber[200] : Colors.amber[800],
                  ),
                ),
              ),
            if (status == 'REJECTED')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'This ad was rejected. Tap Edit to fix and resubmit for review.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.red[200] : Colors.red[800],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_canEditAd(status))
                  _buildAdActionButton('Edit', Icons.edit_rounded, primaryColor, isDark, () => _openEditAd(ad)),
                _buildAdActionButton('Metrics', Icons.analytics_rounded, primaryColor, isDark, () => _showAdMetrics(ad, isDark)),
                if (status == 'ACTIVE') _buildAdActionButton('Pause', Icons.pause_rounded, Colors.orange, isDark, () => _updateAdStatus(ad, 'PAUSED')),
                if (status == 'PAUSED') _buildAdActionButton('Resume', Icons.play_arrow_rounded, Colors.green, isDark, () => _updateAdStatus(ad, 'ACTIVE')),
                if (status == 'PENDING_REVIEW' || status == 'SCHEDULED' || status == 'ACTIVE' || status == 'PAUSED')
                  _buildAdActionButton('Cancel', Icons.close_rounded, Colors.red, isDark, () => _updateAdStatus(ad, 'CANCELLED')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdThumbnail(Map<String, dynamic> ad, bool isDark) {
    final mediaType = ad['mediaType']?.toString().toUpperCase() ?? 'IMAGE';
    String? key;
    if (mediaType == 'VIDEO') {
      key = ad['videoKey']?.toString().trim();
    }
    key ??= _firstAdMediaKey(ad);
    final thumbUrl = ad['thumbnailUrl']?.toString().trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 56,
        child: thumbUrl != null && thumbUrl.startsWith('http')
            ? CachedMediaImage(
                mediaKey: thumbUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: _listingThumbnailPlaceholder(isDark),
                errorWidget: _listingThumbnailPlaceholder(isDark),
              )
            : (key != null && key.isNotEmpty)
                ? CachedMediaImage(
                    mediaKey: key,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: _listingThumbnailPlaceholder(isDark),
                    errorWidget: _listingThumbnailPlaceholder(isDark),
                  )
                : _listingThumbnailPlaceholder(isDark),
      ),
    );
  }

  bool _canEditAd(String status) {
    return status == 'PENDING_REVIEW' ||
        status == 'REJECTED' ||
        status == 'SCHEDULED' ||
        status == 'PAUSED' ||
        status == 'ACTIVE';
  }

  Future<void> _openEditAd(Map<String, dynamic> ad) async {
    final updated = await GuardedNavigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditAdScreen(ad: ad)),
    );
    if (updated == true && mounted) {
      await _refreshAll();
    }
  }

  Widget _buildAdActionButton(String label, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    String label = status;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        label = 'LIVE';
        break;
      case 'PAUSED':
        color = Colors.orange;
        break;
      case 'CANCELLED':
      case 'REJECTED':
        color = Colors.red;
        break;
      case 'PENDING_REVIEW':
        color = Colors.amber;
        label = 'IN REVIEW';
        break;
      case 'SCHEDULED':
        color = AppColors.primary;
        break;
      case 'EXPIRED':
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
            child: Icon(Icons.inbox_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(message, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)));
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Center(child: Padding(padding: const EdgeInsets.all(40), child: BybataLoadingIndicator(color: primaryColor)));
  }

  // --- PROMOTION PURCHASE WITH ENHANCED ERROR HANDLING ---
  Future<void> _openPromotionPicker({required String referenceType, required String referenceId, required String title, required bool isDark}) async {
    await _showBoostModal(referenceType: referenceType, referenceId: referenceId, title: title, isDark: isDark);
  }

  String _placementLabelForReference(String referenceType) {
    switch (referenceType.toLowerCase()) {
      case 'trade':
        return AdPlacementKeys.screenLabel(AdPlacementKeys.tradeFeed) ?? 'Trades feed';
      case 'gift':
        return AdPlacementKeys.screenLabel(AdPlacementKeys.giftFeed) ?? 'Gifts feed';
      case 'campaign':
      case 'donation':
        return AdPlacementKeys.screenLabel(AdPlacementKeys.campaignFeed) ?? 'Donations feed';
      default:
        return 'Home feed';
    }
  }

  Map<String, dynamic>? _pickBoostTypeForReference(
    List<dynamic> types,
    String referenceType,
  ) {
    final needle = referenceType.toLowerCase();
    for (final raw in types) {
      final t = Map<String, dynamic>.from(raw as Map);
      final slug = (t['slug'] ?? '').toString().toLowerCase();
      if (needle == 'trade' && slug.contains('trade')) return t;
      if (needle == 'gift' && slug.contains('gift')) return t;
      if ((needle == 'campaign' || needle == 'donation') &&
          (slug.contains('campaign') || slug.contains('donation'))) {
        return t;
      }
    }
    if (types.isEmpty) return null;
    return Map<String, dynamic>.from(types.first as Map);
  }

  Future<void> _showBoostModal({
    required String referenceType,
    required String referenceId,
    required String title,
    required bool isDark,
  }) async {
    final config = await _walletService.fetchBoostConfig();
    if (config == null) {
      await _showBoostUnavailableModal(
        title,
        'Boost configuration is unavailable right now.',
        isDark,
      );
      return;
    }
    final types = (config['boostTypes'] as List?) ?? [];
    final configs = (config['configs'] as List?) ?? [];
    if (types.isEmpty || configs.isEmpty) {
      await _showBoostUnavailableModal(
        title,
        'Boost options are not configured yet. Please try again later.',
        isDark,
      );
      return;
    }

    final pickedType = _pickBoostTypeForReference(types, referenceType);
    if (pickedType == null) {
      await _showBoostUnavailableModal(title, 'No boost plan available.', isDark);
      return;
    }

    String selectedTypeId = pickedType['id']?.toString() ?? '';
    Map<String, dynamic> selectedConfig = configs.firstWhere(
      (c) => c['boostTypeId']?.toString() == selectedTypeId,
      orElse: () => configs.first,
    );
    final minDays = (selectedConfig['minDays'] as int?) ?? 1;
    final maxDays = (selectedConfig['maxDays'] as int?) ?? 30;
    final allPlacements = (config['placements'] as List?) ?? [];
    final availablePlacements =
        _placementsForConfig(selectedConfig, allPlacements);
    final adPricing = _adPricingFromConfig(config);
    final defaultPlacement = _defaultPlacementKeyForReference(referenceType);
    final selectableDates = _selectableBoostDateKeys(maxDays);
    final initialDate = selectableDates.isNotEmpty ? selectableDates.first : _isoDateKey(DateTime.now());
    final Set<String> selectedDates = {initialDate};
    final Set<String> selectedPlacementKeys = {
      if (availablePlacements.any((p) => p['key']?.toString() == defaultPlacement))
        defaultPlacement
      else if (availablePlacements.isNotEmpty)
        availablePlacements.first['key']!.toString(),
    };

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dayCount = selectedDates.length;
            final cost = _walletService.computeBoostPurchaseTotal(
              config: selectedConfig,
              dayCount: dayCount,
              placementKeys: selectedPlacementKeys,
              adPricing: adPricing,
            );

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E24).withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.9),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Boost "$title"',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pick the days and feeds where you want extra visibility. Taps open your listing in the app.',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Boost days ($dayCount selected · $minDays–$maxDays allowed)',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectableDates.map((iso) {
                                  final selected = selectedDates.contains(iso);
                                  return FilterChip(
                                    label: Text(
                                      _formatBoostDayLabel(iso),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : (isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        if (selected) {
                                          if (selectedDates.length > 1) {
                                            selectedDates.remove(iso);
                                          }
                                        } else if (selectedDates.length < maxDays) {
                                          selectedDates.add(iso);
                                        }
                                      });
                                    },
                                    selectedColor: AppColors.primary,
                                    checkmarkColor: Colors.white,
                                    backgroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.grey[100],
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Where to show',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (availablePlacements.isEmpty)
                                Text(
                                  'No placements available.',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: availablePlacements.map((placement) {
                                    final key = placement['key']?.toString() ?? '';
                                    final label = AdPlacementKeys.screenLabel(key) ??
                                        placement['title']?.toString() ??
                                        key;
                                    final selected =
                                        selectedPlacementKeys.contains(key);
                                    return FilterChip(
                                      label: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : (isDark ? Colors.white : Colors.black87),
                                        ),
                                      ),
                                      selected: selected,
                                      onSelected: (_) {
                                        setState(() {
                                          if (selected) {
                                            if (selectedPlacementKeys.length > 1) {
                                              selectedPlacementKeys.remove(key);
                                            }
                                          } else {
                                            selectedPlacementKeys.add(key);
                                          }
                                        });
                                      },
                                      selectedColor: AppColors.primary,
                                      checkmarkColor: Colors.white,
                                      backgroundColor: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.grey[100],
                                    );
                                  }).toList(),
                                ),
                              if (selectedPlacementKeys.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  '${selectedPlacementKeys.length} placement(s) × $dayCount day(s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total cost',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${cost.toStringAsFixed(2)} BYC',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () async {
                                if (dayCount < minDays || dayCount > maxDays) {
                                  _showSnackBarWithAction(
                                    'Select $minDays–$maxDays day(s) to boost.',
                                    type: ToastType.warning,
                                    isDark: isDark,
                                  );
                                  return;
                                }
                                if (selectedPlacementKeys.isEmpty) {
                                  _showSnackBarWithAction(
                                    'Select at least one placement.',
                                    type: ToastType.warning,
                                    isDark: isDark,
                                  );
                                  return;
                                }
                                _showLoadingDialog('Activating boost...', isDark);
                                try {
                                  final sortedDates = selectedDates.toList()..sort();
                                  final ok = await _walletService.purchaseBoost(
                                    referenceType: referenceType,
                                    referenceId: referenceId,
                                    boostTypeId: selectedTypeId,
                                    boostDates: sortedDates,
                                    placementKeys: selectedPlacementKeys.toList(),
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(context);

                                  if (ok) {
                                    final successMsg =
                                        PromotionSuccessHandler.getSuccessMessage(
                                      itemTitle: title,
                                      promotionType: 'boost',
                                      days: dayCount,
                                    );
                                    _showSnackBarWithAction(
                                      successMsg,
                                      type: ToastType.success,
                                      duration: const Duration(seconds: 4),
                                      isDark: isDark,
                                    );
                                    Navigator.pop(context);
                                    await _refreshAll();
                                  } else {
                                    final backendError = _walletService.error ??
                                        'Failed to activate boost';
                                    final userFriendlyMsg =
                                        PromotionErrorHandler.parseErrorMessage(
                                      backendError,
                                    );
                                    final isRetryable =
                                        PromotionErrorHandler.isRetryable(
                                      backendError,
                                    );
                                    _showSnackBarWithAction(
                                      userFriendlyMsg,
                                      type: ToastType.error,
                                      actionLabel:
                                          isRetryable ? 'Retry' : null,
                                      isDark: isDark,
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  _showSnackBarWithAction(
                                    'Something went wrong. Please try again.',
                                    type: ToastType.error,
                                    isDark: isDark,
                                  );
                                }
                              },
                              child: const Text(
                                'Start boost',
                                style: TextStyle(fontWeight: FontWeight.w800),
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
      },
    );
  }

  Future<void> _showBoostUnavailableModal(String title, String message, bool isDark) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                Text('Boost "$title"', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text(message, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Suggested Setup', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Run Days:', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)), Text('7', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Cost:', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)), Text('25 BYC', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Placement:', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)), Text('Featured feed', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _defaultPlacementKeyForReference(String referenceType) {
    switch (referenceType.toLowerCase()) {
      case 'trade':
        return AdPlacementKeys.tradeFeed;
      case 'gift':
        return AdPlacementKeys.giftFeed;
      case 'campaign':
      case 'donation':
        return AdPlacementKeys.campaignFeed;
      default:
        return AdPlacementKeys.homeFeed;
    }
  }

  Map<String, double> _adPricingFromConfig(Map<String, dynamic> config) {
    final raw = config['adPricing'];
    if (raw is! Map) {
      return {
        'tradeBycPerDay': 2.5,
        'giftBycPerDay': 2,
        'donationBycPerDay': 2,
        'normalBycPerDay': 3,
      };
    }
    return {
      'tradeBycPerDay': _toDouble(raw['tradeBycPerDay']),
      'giftBycPerDay': _toDouble(raw['giftBycPerDay']),
      'donationBycPerDay': _toDouble(raw['donationBycPerDay']),
      'normalBycPerDay': _toDouble(raw['normalBycPerDay']),
    };
  }

  List<String> _selectableBoostDateKeys(int maxDays) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return List.generate(maxDays, (i) => _isoDateKey(start.add(Duration(days: i))));
  }

  String _isoDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatBoostDayLabel(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final d = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]} ${d.day}/${d.month}';
  }

  List<Map<String, dynamic>> _placementsForConfig(Map<String, dynamic> config, List placements) {
    final allowed = (config['placementKeys'] as List?)?.map((e) => e.toString()).toList();
    if (allowed == null || allowed.isEmpty) {
      return placements.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    }
    return placements.where((p) => allowed.contains(p['key']?.toString())).map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  List<int> _daysOptionsForConfig(Map<String, dynamic> config) {
    final minDays = (config['minDays'] as int?) ?? 1;
    final maxDays = (config['maxDays'] as int?) ?? 30;
    final tiers = config['tiers'];
    if (tiers is List && tiers.isNotEmpty) {
      final days = <int>[];
      for (final tier in tiers) {
        final map = Map<String, dynamic>.from(tier as Map);
        final min = (map['minDays'] as int?) ?? (map['days'] as int?) ?? minDays;
        final max = (map['maxDays'] as int?) ?? min;
        for (var d = min; d <= max; d++) {
          if (!days.contains(d)) days.add(d);
        }
      }
      days.sort();
      return days;
    }
    return List<int>.generate(maxDays - minDays + 1, (i) => minDays + i);
  }

  double _calculateBoostCost(Map<String, dynamic> config, int days) {
    final model = (config['pricingModel']?.toString() ?? 'FIXED').toUpperCase();
    if (model == 'DAILY') return _toDouble(config['dailyCostBYC']) * days;
    if (model == 'TIERED') {
      final tiers = config['tiers'];
      if (tiers is List) {
        for (final tier in tiers) {
          final map = Map<String, dynamic>.from(tier as Map);
          final min = (map['minDays'] as int?) ?? (map['days'] as int?) ?? 1;
          final max = (map['maxDays'] as int?) ?? min;
          if (days >= min && days <= max) return _toDouble(map['cost']);
        }
      }
    }
    return _toDouble(config['baseCostBYC']);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Widget _buildDropdownField({required String label, required String value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!)),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: isDark ? Colors.grey[900] : Colors.white,
              icon: Icon(Icons.expand_more_rounded, color: isDark ? Colors.white : Colors.black87),
              decoration: const InputDecoration(border: InputBorder.none),
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateAdStatus(Map<String, dynamic> ad, String status) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = ad['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await _walletService.updateAdStatus(adScheduleId: id, status: status);
    if (!ok) _showSnackBarWithAction(_walletService.error ?? 'Failed to update status', type: ToastType.error, isDark: isDark);
  }

  Future<void> _showAdMetrics(Map<String, dynamic> ad, bool isDark) async {
    final id = ad['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final data = await _walletService.getAdPerformance(id);
    if (data == null) {
      _showSnackBarWithAction(_walletService.error ?? 'Failed to load metrics', type: ToastType.error, isDark: isDark);
      return;
    }
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Ad Performance', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            _metricRow('Views', data['viewCount'], isDark), 
            _metricRow('Clicks', data['clickCount'], isDark),
            _metricRow('CTR', _formatCtr(data['clickThroughRate']), isDark), 
            _metricRow('Cost', _formatCost(data['cost']), isDark),
            _metricRow('Status', data['status'], isDark),
          ]
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)))],
      )
    );
  }

  Widget _metricRow(String label, dynamic value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)), 
          Text(value?.toString() ?? '-', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87))
        ]
      )
    );
  }

  String _formatCtr(dynamic value) { if (value is num) return '${value.toStringAsFixed(2)}%'; final parsed = double.tryParse(value?.toString() ?? ''); return parsed == null ? '-' : '${parsed.toStringAsFixed(2)}%'; }
  String _formatCost(dynamic value) { if (value is num) return '${value.toStringAsFixed(2)} BYC'; final parsed = double.tryParse(value?.toString() ?? ''); return parsed == null ? '-' : '${parsed.toStringAsFixed(2)} BYC'; }

  void _showSnackBarWithAction(
    String message, {
    ToastType type = ToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    required bool isDark,
  }) {
    AppToast.show(
      context,
      message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  void _showLoadingDialog(String message, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BybataLoadingIndicator(size: BybataLoadingSize.compact),
              const SizedBox(height: 20),
              Text(message, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconFor(ToastType type) {
    switch (type) {
      case ToastType.success: return Icons.check_circle_rounded;
      case ToastType.error: return Icons.error_outline_rounded;
      case ToastType.warning: return Icons.warning_amber_rounded;
      case ToastType.info: return Icons.info_outline_rounded;
    }
  }

  ({Color background, Color foreground}) _getColorFor(ToastType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case ToastType.success: return (background: isDark ? Colors.green.shade900 : Colors.green.shade100, foreground: isDark ? Colors.greenAccent : Colors.green.shade800);
      case ToastType.error: return (background: isDark ? Colors.red.shade900 : Colors.red.shade100, foreground: isDark ? Colors.redAccent : Colors.red.shade800);
      case ToastType.warning: return (background: isDark ? Colors.orange.shade900 : Colors.orange.shade100, foreground: isDark ? Colors.orangeAccent : Colors.orange.shade800);
      case ToastType.info: return (background: isDark ? AppColors.primary : AppColors.primary.withValues(alpha: 0.12), foreground: isDark ? AppColors.primary : AppColors.primary);
    }
  }
}

/// First image/video storage key from an ad schedule payload.
String? _firstAdMediaKey(Map<String, dynamic> ad) {
  final mediaType = ad['mediaType']?.toString().toUpperCase() ?? 'IMAGE';
  if (mediaType == 'VIDEO') {
    final vk = ad['videoKey']?.toString().trim();
    if (vk != null && vk.isNotEmpty) return vk;
  }
  return _firstMediaKeyFromMap(ad);
}

/// First storage key or URL from trade/gift/campaign API payloads.
String? _firstMediaKeyFromMap(Map<String, dynamic> data) {
  final keys = data['mediaKeys'];
  if (keys is List && keys.isNotEmpty) {
    final first = keys.first?.toString().trim();
    if (first != null && first.isNotEmpty) return first;
  }
  final images = data['images'] ?? data['imageUrls'] ?? data['image_urls'];
  if (images is List && images.isNotEmpty) {
    final first = images.first?.toString().trim();
    if (first != null && first.isNotEmpty) return first;
  }
  final thumb = data['thumbnailKey']?.toString().trim();
  if (thumb != null && thumb.isNotEmpty) return thumb;
  final image = data['image']?.toString().trim();
  if (image != null && image.isNotEmpty) return image;
  final imageUrl = data['imageUrl']?.toString().trim();
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  return null;
}

Widget _listingThumbnailPlaceholder(bool isDark) {
  return ColoredBox(
    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100]!,
    child: Icon(
      Icons.image_rounded,
      color: isDark ? Colors.grey[500] : Colors.grey[400],
      size: 26,
    ),
  );
}

class _ListingItem {
  final String id;
  final String title;
  final String? imageMediaKey;

  const _ListingItem({
    required this.id,
    required this.title,
    this.imageMediaKey,
  });
}