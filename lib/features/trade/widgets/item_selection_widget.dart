import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../widgets/trade_listing_preview.dart';
import '../models/trade_models.dart' as trade_models;

/// Widget for selecting a trade item to offer in exchange
class ItemSelectionWidget extends StatefulWidget {
  final List<trade_models.Trade> availableTrades;
  final trade_models.Trade? selectedTrade;
  final Function(trade_models.Trade?) onTradeSelected;
  final String? excludeTradeId; // Trade to exclude (e.g., the target trade)
  final String? title; // Optional custom title (e.g. "Select Item You Want" for owner counter-offer)
  /// When set, shown on the empty state so users can list an item to offer.
  final VoidCallback? onCreateTrade;

  const ItemSelectionWidget({
    super.key,
    required this.availableTrades,
    this.selectedTrade,
    required this.onTradeSelected,
    this.excludeTradeId,
    this.title,
    this.onCreateTrade,
  });

  @override
  State<ItemSelectionWidget> createState() => _ItemSelectionWidgetState();
}

class _ItemSelectionWidgetState extends State<ItemSelectionWidget> {
  trade_models.Trade? _selectedTrade;

  @override
  void initState() {
    super.initState();
    _selectedTrade = widget.selectedTrade;
  }

  @override
  void didUpdateWidget(ItemSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTrade != oldWidget.selectedTrade) {
      _selectedTrade = widget.selectedTrade;
    }
  }

  List<trade_models.Trade> get _filteredTrades {
    return widget.availableTrades
        .where((trade) => trade.id != widget.excludeTradeId)
        .where(
          (trade) =>
              trade.status == trade_models.TradeStatus.active ||
              trade.status == trade_models.TradeStatus.inOffer,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    if (_filteredTrades.isEmpty) {
      return ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: context.tertiaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'No Active Trades',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'List something to trade so you can make an item-for-item offer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.secondaryText,
                ),
              ),
              if (widget.onCreateTrade != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onCreateTrade,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create a trade'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Or switch to Cash Offer above',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tertiaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.swap_horiz,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              widget.title ?? 'Select Item to Offer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _filteredTrades.length,
            itemBuilder: (context, index) {
              final trade = _filteredTrades[index];
              final isSelected = _selectedTrade?.id == trade.id;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTrade = isSelected ? null : trade;
                  });
                  widget.onTradeSelected(_selectedTrade);
                },
                child: Container(
                  width: 160,
                  margin: EdgeInsets.only(
                    right: index < _filteredTrades.length - 1 ? 12 : 0,
                  ),
                  child: ShadowCard(
                    shadowIntensity: ShadowIntensity.light,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: SizedBox(
                              height: 100,
                              width: double.infinity,
                              child: TradeListingPreview(
                                trade: trade,
                                width: 160,
                                height: 100,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trade.title,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        trade.categoryIcon,
                                        size: 10,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          trade.categoryName,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'Selected',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

