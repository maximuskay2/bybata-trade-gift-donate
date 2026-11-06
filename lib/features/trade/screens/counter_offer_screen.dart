import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
import '../widgets/item_selection_widget.dart';
import '../widgets/trade_listing_preview.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Dedicated screen for the listing owner to counter-offer.
/// Owner picks from the bidder's items and/or asks for additional cash (BYC).
/// Used for every owner turn in a multi-round negotiation chain.
class CounterOfferScreen extends StatefulWidget {
  final trade_models.Trade targetTrade;
  final String offerId;
  final String parentOfferId;
  final String counterpartyUserId;
  final String counterpartyName;
  final trade_models.Trade? counterpartyOfferedTrade;

  const CounterOfferScreen({
    super.key,
    required this.targetTrade,
    required this.offerId,
    required this.parentOfferId,
    required this.counterpartyUserId,
    required this.counterpartyName,
    this.counterpartyOfferedTrade,
  });

  @override
  State<CounterOfferScreen> createState() => _CounterOfferScreenState();
}

class _CounterOfferScreenState extends State<CounterOfferScreen> {
  List<trade_models.Trade> _counterpartyTrades = [];
  bool _isLoading = true;
  trade_models.Trade? _selectedTrade;
  final _amountController = TextEditingController();
  bool _askForCash = false;
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCounterpartyTrades();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCounterpartyTrades() async {
    setState(() => _isLoading = true);
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final res = await backend.listMyTrades(
        ownerId: widget.counterpartyUserId,
        page: 1,
        size: 50,
        forceRefresh: true,
      );
      final items = (res['items'] as List?) ?? [];
      if (mounted) {
        final trades = items
            .map((e) =>
                trade_models.Trade.fromJson(Map<String, dynamic>.from(e)))
            .where((t) =>
                (t.status == trade_models.TradeStatus.active ||
                    t.status == trade_models.TradeStatus.inOffer) &&
                t.id != widget.targetTrade.id)
            .toList();
        final offered = widget.counterpartyOfferedTrade;
        if (offered != null && !trades.any((t) => t.id == offered.id)) {
          trades.insert(0, offered);
        }
        setState(() {
          _counterpartyTrades = trades;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedTrade == null && !_askForCash) {
      setState(() => _errorMessage = 'Select an item you want or ask for cash');
      return;
    }
    if (_askForCash) {
      final amt = double.tryParse(_amountController.text.trim());
      if (amt == null || amt <= 0) {
        setState(() => _errorMessage = 'Enter a valid amount');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.createOffer(
        widget.targetTrade.id,
        parentOfferId: widget.parentOfferId,
        requestedTradeId: _selectedTrade?.id,
        requestedAmount: _askForCash ? _amountController.text.trim() : null,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        HapticFeedback.lightImpact();
        AppToast.success(context, 'Counter-offer sent!');
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = backend.error ?? 'Failed to send counter-offer';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          'Counter-Offer',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading
            ? const BybataLoader()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(primaryColor),
                  const SizedBox(height: 24),
                  Text(
                    'What would you like from ${widget.counterpartyName}?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_counterpartyTrades.isNotEmpty) ...[
                    Text(
                      'Pick an item you want',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ItemSelectionWidget(
                      availableTrades: _counterpartyTrades,
                      selectedTrade: _selectedTrade,
                      excludeTradeId: widget.targetTrade.id,
                      title: 'Select item you want',
                      onTradeSelected: (t) =>
                          setState(() => _selectedTrade = t),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildCashSection(primaryColor),
                  const SizedBox(height: 24),
                  _buildMessageSection(primaryColor),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 20),
                    label: Text(_isSubmitting ? 'Sending...' : 'Send Counter-Offer'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: primaryColor,
                    ),
                  ),
                ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.targetTrade.listingMedia.hasMedia)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TradeListingPreview(
                trade: widget.targetTrade,
                width: 60,
                height: 60,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          if (widget.targetTrade.listingMedia.hasMedia) const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR TRADE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.targetTrade.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  widget.targetTrade.categoryName,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Or ask for additional cash',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _askForCash,
            onChanged: (v) => setState(() => _askForCash = v ?? false),
            title: const Text('I want cash on top'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: primaryColor,
          ),
          if (_askForCash) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                suffixText: 'BYC',
                filled: true,
                fillColor: AppColors.primarySurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.message_outlined, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Message (optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a note to your counter-offer...',
              filled: true,
              fillColor: AppColors.primarySurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
