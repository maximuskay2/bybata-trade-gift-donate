import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../../../features/search/utils/search_item_view_data.dart';
import '../widgets/trade_listing_preview.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/item_selection_widget.dart';
import '../widgets/offer_timeline_widget.dart';
import '../widgets/even_trade_panel.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../../features/chat/models/chat_conversation.dart';
import 'trade_chat_screen.dart';
import 'trade_screen.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class NegotiationScreen extends StatefulWidget {
  final trade_models.Trade targetTrade;
  final List<trade_models.Trade> userTrades;
  final String? offerId;
  final String? parentOfferId;
  final String? initiatorUserId;
  final trade_models.Trade? initialSelectedTrade;
  final trade_models.Trade? initialCounterpartyOfferedTrade;
  final List<trade_models.TradeOffer>? offerHistory;

  const NegotiationScreen({
    super.key,
    required this.targetTrade,
    required this.userTrades,
    this.offerId,
    this.parentOfferId,
    this.initiatorUserId,
    this.initialSelectedTrade,
    this.initialCounterpartyOfferedTrade,
    this.offerHistory,
  });

  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _Trade3DEngine {
  static Widget buildContainer(
    BuildContext context, {
    required Widget child,
    Color? color,
    double radius = 24,
  }) {
    return Container(
      decoration: context.surfaceCardDecoration(
        radius: radius,
        color: color,
      ),
      child: child,
    );
  }

  static InputDecoration recessedInput(
    BuildContext context,
    String hint, {
    Widget? suffix,
    String? suffixText,
  }) {
    return context.recessedInputDecoration(
      hint: hint,
      suffixIcon: suffix,
      suffixText: suffixText,
    );
  }
}

class _NegotiationScreenState extends State<NegotiationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _amountController = TextEditingController();
  
  trade_models.Trade? _selectedTrade;
  List<trade_models.Trade> _userTrades = [];
  bool _userTradesLoading = true;
  bool _isItemOffer = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<trade_models.TradeOffer>? _offerTimeline;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _selectedTrade = widget.initialSelectedTrade;
    if (widget.initialCounterpartyOfferedTrade != null) {
      _isItemOffer = true;
    } else if (_selectedTrade == null) {
      _isItemOffer = widget.userTrades.isNotEmpty;
    }
    
    if (widget.offerId != null) {
      _loadOfferHistory();
    } else if (widget.offerHistory != null) {
      _offerTimeline = widget.offerHistory;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadUserTrades());
  }

  Future<void> _loadOfferHistory() async {
    if (widget.offerId == null) return;
    setState(() => _isLoadingHistory = true);
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final history = await backend.getOfferHistory(widget.offerId!);
      if (history != null && mounted) {
        final timelineData = history['timeline'] as List?;
        if (timelineData != null) {
          setState(() {
            _offerTimeline = timelineData
                .map((e) => trade_models.TradeOffer.tryParseTimelineEntry(e))
                .whereType<trade_models.TradeOffer>()
                .toList();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _reloadUserTrades() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _userTrades = [];
          _userTradesLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _userTradesLoading = true);

    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final res = await backend.listMyTrades(
        ownerId: userId,
        page: 1,
        size: 50,
        forceRefresh: true,
      );
      final items = (res['items'] as List?) ?? [];
      unawaited(
        SearchItemViewData.warmPreviewMedia(
          items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          limit: 24,
        ),
      );
      final trades = items
          .whereType<Map>()
          .map(
            (e) => trade_models.Trade.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .where(
            (t) =>
                (t.status == trade_models.TradeStatus.active ||
                    t.status == trade_models.TradeStatus.inOffer) &&
                t.id != widget.targetTrade.id,
          )
          .toList();
      final preselected = widget.initialSelectedTrade;
      if (preselected != null && !trades.any((t) => t.id == preselected.id)) {
        trades.insert(0, preselected);
      }
      if (!mounted) return;
      setState(() {
        _userTrades = trades;
        _userTradesLoading = false;
        if (_selectedTrade == null && trades.isNotEmpty) {
          _isItemOffer = true;
        } else if (_selectedTrade == null && trades.isEmpty) {
          _isItemOffer = widget.initialCounterpartyOfferedTrade != null
              ? true
              : widget.userTrades.isNotEmpty;
        }
        if (_selectedTrade != null &&
            !_userTrades.any((t) => t.id == _selectedTrade!.id)) {
          _selectedTrade = null;
        }
      });
    } catch (e) {
      debugPrint('[NegotiationScreen] Failed to reload user trades: $e');
      if (!mounted) return;
      setState(() {
        _userTrades = List<trade_models.Trade>.from(widget.userTrades)
            .where((t) => t.id != widget.targetTrade.id)
            .toList();
        _userTradesLoading = false;
      });
    }
  }

  Future<void> _openCreateTrade() async {
    final created = await GuardedNavigator.pushNamed(context,
      AppConstants.createTradeRoute,
    );
    if (!mounted || created != true) return;

    await _reloadUserTrades();
    if (!mounted) return;

    if (_userTrades.isNotEmpty) {
      setState(() => _isItemOffer = true);
      AppToast.success(context, 'Trade listed! Select it below to include in your offer.');
    }
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isItemOffer && _selectedTrade == null) {
      setState(() => _errorMessage = 'Please select an item to offer');
      return;
    }
    if (!_isItemOffer) {
      final offerAmount = double.tryParse(_amountController.text) ?? 0.0;
      if (offerAmount <= 0) {
        setState(() => _errorMessage = 'Please enter a valid amount');
        return;
      }
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      debugPrint('[NegotiationScreen] Submitting offer: isItemOffer=$_isItemOffer');
      
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.createOffer(
        widget.targetTrade.id,
        amount: _isItemOffer ? null : _amountController.text,
        offeredTradeId: _isItemOffer ? _selectedTrade?.id : null,
        message: _messageController.text.isEmpty ? null : _messageController.text,
        parentOfferId: widget.parentOfferId,
      );

      if (!mounted) return;
      if (success) {
        debugPrint('[NegotiationScreen] Offer submitted successfully');
        AppToast.success(context, _isItemOffer
              ? 'Offer submitted!'
              : 'Offer submitted! Payment is between you and the other party — not held in the app.');
        Navigator.of(context).pop(true);
      } else if (backend.duplicateOfferId != null) {
        debugPrint('[NegotiationScreen] Duplicate offer detected, showing dialog');
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Existing Offer'),
            content: Text(
              backend.error ?? 'You already have a pending offer for this trade with the same item. View it in the Offers tab.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                  GuardedNavigator.push(context, 
                    MaterialPageRoute(
                      builder: (_) => const TradeScreen(initialTabIndex: 3),
                    ),
                  );
                },
                child: const Text('View Offer'),
              ),
            ],
          ),
        );
      } else {
        debugPrint('[NegotiationScreen] Offer submission failed: ${backend.error}');
        setState(() => _errorMessage = backend.error ?? 'Failed to submit offer');
      }
    } catch (e) {
      debugPrint('[NegotiationScreen] Offer submission exception: $e');
      if (mounted) setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        title: Text(
          widget.parentOfferId != null ? 'Counter-Offer' : 'New Offer',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: context.primaryText,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded, color: primaryColor),
            onPressed: () => _openTradeChat(context, primaryColor),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTargetTradeHeader(primaryColor),
              if (widget.offerId != null) ...[
                const SizedBox(height: 16),
                EvenTradePanel(
                  tradeId: widget.targetTrade.id,
                  offerId: widget.offerId,
                  tradeStatus: widget.targetTrade.status.backendValue,
                ),
              ],
              if (widget.parentOfferId != null) ...[
                const SizedBox(height: 16),
                _buildCounterContextBanner(primaryColor),
              ],
              const SizedBox(height: 24),
              _buildOfferTypeSwitcher(primaryColor),
              const SizedBox(height: 24),
              if (_isItemOffer)
                _userTradesLoading
                    ? const SizedBox(
                        height: 200,
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                    : ItemSelectionWidget(
                        availableTrades: _userTrades,
                        selectedTrade: _selectedTrade,
                        excludeTradeId: widget.targetTrade.id,
                        onCreateTrade: _openCreateTrade,
                        onTradeSelected: (trade) =>
                            setState(() => _selectedTrade = trade),
                      )
              else
                _buildAmountInputSection(primaryColor),
              const SizedBox(height: 24),
              _buildMessageSection(primaryColor),
              if (_errorMessage != null) _buildErrorDisplay(),
              const SizedBox(height: 32),
              _buildSubmitButton(primaryColor),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetTradeHeader(Color primaryColor) {
    final lastOffer = _offerTimeline != null && _offerTimeline!.isNotEmpty ? _offerTimeline!.last : null;
    return _Trade3DEngine.buildContainer(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (widget.targetTrade.listingMedia.hasMedia)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TradeListingPreview(
                  trade: widget.targetTrade,
                  width: 70,
                  height: 70,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRADING FOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: context.tertiaryText,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    widget.targetTrade.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.primaryText,
                    ),
                  ),
                  Row(
                    children: [
                      Text(widget.targetTrade.categoryName, style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (lastOffer != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: lastOffer.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: lastOffer.statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(lastOffer.statusText, style: TextStyle(color: lastOffer.statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterContextBanner(Color primaryColor) {
    final last = _offerTimeline != null && _offerTimeline!.isNotEmpty
        ? _offerTimeline!.last
        : null;
    if (last == null || !last.isOwnerCounter) {
      return _Trade3DEngine.buildContainer(
        context,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.swap_horiz, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Send your counter-offer with an item from your listings or a cash amount.',
                  style: TextStyle(fontSize: 13, color: context.secondaryText, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final parts = <String>[];
    if (last.requestedTrade != null) {
      parts.add('item: ${last.requestedTrade!.title}');
    }
    if (last.requestedAmount != null && last.requestedAmount!.trim().isNotEmpty) {
      parts.add('${last.requestedAmount} BYC');
    }
    final ask = parts.isEmpty ? 'different terms' : parts.join(' + ');

    return _Trade3DEngine.buildContainer(
      context,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Owner counter-offer',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'They asked for $ask. Respond with your item or cash offer below — you can keep negotiating until someone accepts or declines.',
              style: TextStyle(fontSize: 13, color: context.secondaryText, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferTypeSwitcher(Color primaryColor) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            alignment: Alignment(_isItemOffer ? -1.0 : 1.0, 0),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: context.surfaceCardDecoration(
                  radius: 18,
                  elevated: false,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: GestureDetector(
                onTap: () {
                  setState(() => _isItemOffer = true);
                  _amountController.clear();
                },
                child: Center(
                  child: Text(
                    'Item Swap',
                    style: TextStyle(
                      fontWeight: _isItemOffer ? FontWeight.w800 : FontWeight.w500,
                      color: context.primaryText,
                    ),
                  ),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () {
                  setState(() => _isItemOffer = false);
                },
                child: Center(
                  child: Text(
                    'Cash Offer',
                    style: TextStyle(
                      fontWeight: !_isItemOffer ? FontWeight.w800 : FontWeight.w500,
                      color: context.primaryText,
                    ),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInputSection(Color primaryColor) {
    return _Trade3DEngine.buildContainer(
      context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proposed amount',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This is what you propose to pay in BYC. You arrange payment directly with the other person — the app does not hold or move funds.',
              style: TextStyle(fontSize: 12, color: context.secondaryText, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.primaryText,
              ),
              decoration: _Trade3DEngine.recessedInput(context, '0.00', suffixText: 'BYC'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount required';
                final amount = double.tryParse(v);
                if (amount == null || amount <= 0) return 'Enter a positive amount';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'Propose your terms',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
        ),
        _Trade3DEngine.buildContainer(
          context,
          radius: 20,
          child: TextFormField(
            controller: _messageController,
            maxLines: 3,
            style: TextStyle(color: context.primaryText),
            decoration: InputDecoration(
              hintText: 'Add a friendly message...',
              hintStyle: TextStyle(color: context.tertiaryText),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDisplay() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
        child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 18), const SizedBox(width: 8), Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)))]),
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return _Trade3DEngine.buildContainer(
      context,
      color: _isSubmitting ? context.tertiaryText : primaryColor,
      radius: 18,
      child: InkWell(
        onTap: _isSubmitting ? null : _submitOffer,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Send Proposal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // --- LOGIC PRESERVATION: CHAT FLOW ---
  Future<void> _openTradeChat(BuildContext context, Color primaryColor) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      if (currentUser == null) return;

      // Determine the partner (recipient)
      String recipientId = widget.targetTrade.owner.id;
      String recipientName = widget.targetTrade.owner.name;

      if (mounted) {
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (context) => TradeChatScreen(
              trade: widget.targetTrade,
              partnerId: recipientId,
              partnerName: recipientName,
              offerId: widget.offerId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Chat error: $e');
      }
    }
  }
}