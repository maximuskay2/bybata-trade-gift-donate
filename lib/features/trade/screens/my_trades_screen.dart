import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../models/trade_models.dart';
import 'trade_offers_screen.dart';
import 'create_trade_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/trade_backend_provider.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class MyTradesScreen extends StatefulWidget {
  const MyTradesScreen({super.key});

  @override
  State<MyTradesScreen> createState() => _MyTradesScreenState();
}

class _MyTradesScreenState extends State<MyTradesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;

  bool _isLoading = false;
  int _selectedTabIndex = 0;

  final List<String> _tabs = ['Active', 'Pending', 'Completed', 'Expired'];
  
  List<Trade> _activeTrades = [];
  List<Trade> _pendingTrades = [];
  List<Trade> _completedTrades = [];
  List<Trade> _expiredTrades = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });

    _loadUserTrades();
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({required Widget child, Color color = Colors.white, double radius = 24}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 10), blurRadius: 20, spreadRadius: -2),
          BoxShadow(color: Colors.white.withValues(alpha: 0.9), offset: const Offset(-5, -5), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }

  Future<void> _loadUserTrades() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final me = auth.currentUser;
      if (me == null) {
        setState(() {
          _activeTrades = [];
          _pendingTrades = [];
          _completedTrades = [];
          _expiredTrades = [];
          _isLoading = false;
        });
        return;
      }

      final res = await backend.listMyTrades(
        ownerId: me.id,
        page: 1,
        size: 100,
        forceRefresh: false,
      );
      final items = (res['items'] as List?) ?? [];
      final mapped = <Trade>[];
      for (final raw in items) {
        if (raw is! Map) continue;
        try {
          mapped.add(Trade.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _activeTrades = mapped
            .where((t) =>
                t.status == TradeStatus.active ||
                t.status == TradeStatus.inOffer)
            .toList();
        _pendingTrades =
            mapped.where((t) => t.status == TradeStatus.pending).toList();
        _completedTrades =
            mapped.where((t) => t.status == TradeStatus.completed).toList();
        _expiredTrades =
            mapped.where((t) => t.status == TradeStatus.cancelled).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.show(context, 'Failed to load your trades');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, primaryColor),
            _buildFluidTabSwitcher(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _isLoading
                      ? _buildLoadingState(primaryColor)
                      : RefreshIndicator(
                          onRefresh: _loadUserTrades,
                          color: primaryColor,
                          child: TabBarView(
                            controller: _tabController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            children: [
                              _buildTradesList(
                                _activeTrades,
                                primaryColor,
                                'No active trades',
                              ),
                              _buildTradesList(
                                _pendingTrades,
                                primaryColor,
                                'No draft trades',
                              ),
                              _buildTradesList(
                                _completedTrades,
                                primaryColor,
                                'No completed trades',
                              ),
                              _buildTradesList(
                                _expiredTrades,
                                primaryColor,
                                'No cancelled trades',
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(primaryColor),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: _build3DContainer(
                  radius: 12,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("My Trades", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                  Text("Manage Activity", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const TradeOffersScreen())),
            child: _build3DContainer(
              radius: 12,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.inbox, color: primaryColor, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidTabSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 50,
      decoration: BoxDecoration(color: Colors.grey[300]!.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            alignment: Alignment(-1.0 + (_selectedTabIndex * (2.0 / (_tabs.length - 1))), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / _tabs.length,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
              ),
            ),
          ),
          Row(
            children: List.generate(_tabs.length, (index) => Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                   setState(() => _selectedTabIndex = index);
                   _tabController.animateTo(index);
                },
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontWeight: _selectedTabIndex == index ? FontWeight.w900 : FontWeight.w600,
                      color: _selectedTabIndex == index ? Colors.black : Colors.grey[600],
                      fontSize: 12,
                    ),
                    child: Text(_tabs[index]),
                  ),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Center(child: BybataLoadingIndicator(color: primaryColor));
  }

  Widget _buildTradesList(List<Trade> trades, Color primaryColor, String emptyMsg) {
    if (trades.isEmpty) return _buildEmptyState(primaryColor, emptyMsg);

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: trades.length,
      itemBuilder: (context, index) {
        final trade = trades[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => AppRoutes.navigateToTradeDetails(context, trade),
            child: _build3DContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: Icon(trade.categoryIcon, color: primaryColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trade.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(trade.timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ShareUtils.shareTrade(context, id: trade.id, title: trade.title),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.share_outlined, size: 20, color: primaryColor),
                          ),
                        ),
                        _buildStatusBadge(trade.statusText, trade.statusColor),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (trade.status == TradeStatus.active ||
                        trade.status == TradeStatus.inOffer)
                      Row(
                        children: [
                          Expanded(child: _buildActionButton("Offers", Icons.inbox, AppColors.primary, () => _viewOffers(trade))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildActionButton("Edit", Icons.edit, Colors.orange, () => _editTrade(trade))),
                        ],
                      ),
                    if (trade.status == TradeStatus.pending)
                      Row(
                        children: [
                          Expanded(child: _buildActionButton("Edit", Icons.edit, Colors.orange, () => _editTrade(trade))),
                          if (ListingDeleteRules.canDeleteTrade(trade)) ...[
                            const SizedBox(width: 12),
                            Expanded(child: _buildActionButton("Delete", Icons.delete_outline, Colors.red, () => _deleteTrade(trade))),
                          ],
                        ],
                      ),
                    if (trade.status == TradeStatus.active &&
                        ListingDeleteRules.canDeleteTrade(trade))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildActionButton("Delete", Icons.delete_outline, Colors.red, () => _deleteTrade(trade)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const CreateTradeScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add),
            label: const Text("Create Trade"),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: FloatingActionButton(
        onPressed: () => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const CreateTradeScreen())),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _viewOffers(Trade trade) {
    GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => TradeOffersScreen(selectedTrade: trade)));
  }

  void _editTrade(Trade trade) {
    AppRoutes.navigateToEditTrade(context, trade);
  }

  Future<void> _deleteTrade(Trade trade) async {
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
      _loadUserTrades();
    } else {
      showDeleteListingResult(
        context,
        success: false,
        message: backend.error ?? 'Failed to delete trade',
      );
    }
  }
}