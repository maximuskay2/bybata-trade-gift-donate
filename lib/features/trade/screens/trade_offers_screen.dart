import 'package:flutter/material.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../models/trade_models.dart';
import 'counter_offer_screen.dart';
import '../../../core/navigation/app_routes.dart';
import 'package:provider/provider.dart';
import '../providers/trade_backend_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../utils/trade_offers_loader.dart';
import 'trade_chat_screen.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class TradeOffersScreen extends StatefulWidget {
  final Trade? selectedTrade;

  const TradeOffersScreen({super.key, this.selectedTrade});

  @override
  State<TradeOffersScreen> createState() => _TradeOffersScreenState();
}

class _TradeOffersScreenState extends State<TradeOffersScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;

  bool _isLoading = false;
  int _selectedTabIndex = 0;

  final List<String> _tabs = ['Received', 'Sent'];
  
  List<TradeOffer> _allOffers = [];
  List<TradeOffer> _receivedOffers = [];
  List<TradeOffer> _sentOffers = [];

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

    _loadOffers();
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

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final backend = Provider.of<TradeBackendProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    try {
      final loaded = await TradeOffersLoader.load(
        backend: backend,
        userId: userId,
        filterTradeId: widget.selectedTrade?.id,
      );

      if (!mounted) return;
      setState(() {
        _allOffers = loaded;
        _receivedOffers = loaded
            .where((offer) => offer.recipient.id == userId)
            .toList();
        _sentOffers =
            loaded.where((offer) => offer.offerer.id == userId).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.error(context, 'Failed to load offers: $e');
    }
  }

  List<TradeOffer> _getCurrentOffers() {
    return _selectedTabIndex == 0 ? _receivedOffers : _sentOffers;
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), // ByBata Base
      body: SafeArea(
        child: Column(
          children: [
            _build3DHeader(context, primaryColor),
            _buildStatsCards(primaryColor),
            _buildFluidTabSwitcher(primaryColor),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _isLoading 
                      ? _buildLoadingState(primaryColor)
                      : _buildOffersList(primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DHeader(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: _build3DContainer(
              radius: 12,
              child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trade Offers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                Text(
                  widget.selectedTrade != null ? 'For "${widget.selectedTrade!.title}"' : 'All Offers',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _build3DContainer(
            radius: 12,
            child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.swap_horiz, color: primaryColor, size: 24)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Color primaryColor) {
    final pending = _receivedOffers.where((o) => o.status == OfferStatus.pending).length + _sentOffers.where((o) => o.status == OfferStatus.pending).length;
    final accepted = _allOffers.where((o) => o.status == OfferStatus.accepted).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildStatTile('Received', '${_receivedOffers.length}', Icons.inbox, AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatTile('Sent', '${_sentOffers.length}', Icons.send, Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatTile('Pending', '$pending', Icons.hourglass_empty, Colors.orange)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatTile('Accepted', '$accepted', Icons.check_circle, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return _build3DContainer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFluidTabSwitcher(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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

  Widget _buildOffersList(Color primaryColor) {
    final currentOffers = _getCurrentOffers();
    List<TradeOffer> toShow;
    if (widget.selectedTrade != null) {
      toShow = currentOffers.where((o) => o.targetTrade.id == widget.selectedTrade!.id).toList();
    } else {
      toShow = currentOffers;
    }
    return RefreshIndicator(
      onRefresh: () async => _loadOffers(),
      color: primaryColor,
      child: toShow.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [SizedBox(height: MediaQuery.of(context).size.height * 0.3), _buildEmptyState(primaryColor)],
            )
          : _buildOfferListView(toShow, primaryColor),
    );
  }

  Widget _buildOfferListView(List<TradeOffer> offers, Color primaryColor) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        final isReceived = _selectedTabIndex == 0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _build3DContainer(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20, 
                        backgroundColor: primaryColor.withValues(alpha: 0.1), 
                        child: Text((isReceived ? offer.offerer.name : offer.recipient.name)[0], style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isReceived ? offer.offerer.name : offer.recipient.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(offer.timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: offer.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(offer.statusText, style: TextStyle(color: offer.statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (offer.isItemOffer) 
                    Row(
                      children: [
                        Expanded(child: _buildTradeCard(isReceived ? offer.targetTrade : offer.offeredTrade!, isReceived ? "They Want:" : "You Offered:", primaryColor)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.swap_horiz, color: Colors.grey)),
                        Expanded(child: _buildTradeCard(isReceived ? offer.offeredTrade! : offer.targetTrade, isReceived ? "For Your:" : "They Want:", primaryColor)),
                      ],
                    ),
                  if (offer.isCashOffer)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[200]!)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.attach_money, color: Colors.green[700]),
                        Text("Cash Offer: \$${offer.amount}", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  if (offer.message.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                      child: Text(offer.message, style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 16),
                  _buildActionButtons(offer, primaryColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTradeCard(Trade trade, String label, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(trade.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(trade.categoryName, style: TextStyle(fontSize: 11, color: primaryColor)),
      ]),
    );
  }

  Widget _buildActionButtons(TradeOffer offer, Color primaryColor) {
    if (_selectedTabIndex == 0) { // Received
      if (offer.status == OfferStatus.pending) {
        return Row(
          children: [
            Expanded(child: _buildActionButton('Accept', Icons.check, Colors.green, () => _acceptOffer(offer))),
            const SizedBox(width: 8),
            Expanded(child: _buildActionButton('Counter', Icons.swap_horiz, AppColors.primary, () => _makeCounterOffer(offer))),
            const SizedBox(width: 8),
            _buildIconButton(Icons.chat_bubble_outline, primaryColor, () => _openTradeChat(offer)),
            const SizedBox(width: 8),
            _buildIconButton(Icons.close, Colors.red, () => _declineOffer(offer)),
          ],
        );
      } else {
        return Row(children: [
          Expanded(child: _buildActionButton('View', Icons.visibility, Colors.grey, () => _viewTradeDetails(offer.targetTrade))),
          if (offer.status == OfferStatus.accepted) ...[
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton('Chat', Icons.chat, primaryColor, () => _openTradeChat(offer))),
          ],
        ]);
      }
    } else { // Sent
      // Show Finalize button for accepted cash offers
      if (offer.status == OfferStatus.acceptedAwaitingFinalization && offer.isCashOffer) {
        return Row(children: [
          Expanded(child: _buildActionButton('View', Icons.visibility, Colors.grey, () => _viewTradeDetails(offer.targetTrade))),
          const SizedBox(width: 12),
          Expanded(child: _buildActionButton('Finalize', Icons.check_circle, Colors.green, () => _finalizeOffer(offer))),
        ]);
      }
      return Row(children: [
        Expanded(child: _buildActionButton('View', Icons.visibility, Colors.grey, () => _viewTradeDetails(offer.targetTrade))),
        if (offer.status == OfferStatus.pending) ...[
          const SizedBox(width: 8),
          Expanded(child: _buildActionButton('Message', Icons.chat, primaryColor, () => _openTradeChat(offer))),
          const SizedBox(width: 8),
          Expanded(child: _buildActionButton('Withdraw', Icons.undo, Colors.orange, () => _withdrawOffer(offer))),
        ],
      ]);
    }
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    String message;
    String buttonText;
    IconData icon;

    if (_selectedTabIndex == 0) {
      message = 'No offers received yet.\nYour active trades will attract offers!';
      buttonText = 'View My Trades';
      icon = Icons.inbox_outlined;
    } else {
      message = 'You haven\'t sent any offers yet.\nStart exploring trades to make offers!';
      buttonText = 'Browse Trades';
      icon = Icons.send_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(buttonText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS ---
  Future<void> _acceptOffer(TradeOffer offer) async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.acceptOffer(offer.id);
      if (!mounted) return;
      if (success) {
        await _loadOffers();
        if (!mounted) return;
        AppToast.success(context, 'Offer accepted! Awaiting finalization');
      } else {
        AppToast.error(context, backend.error ?? 'Failed');
      }
    } catch (e) {
      AppToast.error(context, 'Error accepting offer');
    }
  }

  Future<void> _finalizeOffer(TradeOffer offer) async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.finalizeOffer(offer.id);
      if (!mounted) return;
      if (success) {
        await _loadOffers();
        if (!mounted) return;
        AppToast.success(context, 'Trade finalized! Payment transferred!');
      } else {
        AppToast.error(context, backend.error ?? 'Failed to finalize');
      }
    } catch (e) {
      AppToast.error(context, 'Error finalizing offer');
    }
  }
  
  Future<void> _makeCounterOffer(TradeOffer offer) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser == null) return;

      if (mounted) {
        // Received tab: current user is owner, use CounterOfferScreen (pick from counterparty's items)
        GuardedNavigator.push(context, MaterialPageRoute(
          builder: (_) => CounterOfferScreen(
            targetTrade: offer.targetTrade,
            offerId: offer.id,
            parentOfferId: offer.id,
            counterpartyUserId: offer.offerer.id,
            counterpartyName: offer.offerer.name,
            counterpartyOfferedTrade: offer.offeredTrade,
          ),
        ));
      }
    } catch (_) {}
  }

  Future<void> _withdrawOffer(TradeOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Offer'),
        content: const Text('Are you sure you want to withdraw this offer? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.withdrawOffer(offer.id);
      if (!mounted) return;
      if (success) {
        await _loadOffers();
        if (!mounted) return;
        AppToast.warning(context, 'Offer withdrawn');
      } else {
        AppToast.error(context, backend.error ?? 'Failed to withdraw');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Error: $e');
    }
  }

  Future<void> _declineOffer(TradeOffer offer) async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.rejectOffer(offer.id);
      if (!mounted) return;
      if (success) {
        await _loadOffers();
        if (!mounted) return;
        AppToast.warning(context, 'Offer declined');
      }
    } catch (_) {}
  }

  Future<void> _openTradeChat(TradeOffer offer) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isReceived = offer.recipient.id == auth.currentUser?.id;
    final partnerId = isReceived ? offer.offerer.id : offer.recipient.id;
    final partnerName = isReceived ? offer.offerer.name : offer.recipient.name;
    GuardedNavigator.push(context, MaterialPageRoute(builder: (_) => TradeChatScreen(
      trade: offer.targetTrade,
      partnerId: partnerId,
      partnerName: partnerName,
      offerId: offer.id,
      offerStatus: offer.status.toString().split('.').last.toLowerCase(),
      isOwner: isReceived,
    )));
  }

  void _viewTradeDetails(Trade trade) => AppRoutes.navigateToTradeDetails(context, trade);
}