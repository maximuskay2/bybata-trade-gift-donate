import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/motion/stage_glass_field.dart';
import '../../../core/motion/stage_photo_well.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../models/trade_models.dart';
import '../providers/trade_backend_provider.dart';
/// Shown under the hero. Does not write the listing.
String tradeDifferenceLabel({required int theirValue, required int mineValue}) {
  final gap = mineValue - theirValue;
  if (gap == 0) return 'Even';
  if (gap > 0) return '+$gap BYC';
  return '$gap BYC';
}

class TradeOfferDraft extends ChangeNotifier {
  String? offeredTradeId;
  int? mineValue;
  bool isItemOffer = true;
  final TextEditingController message = TextEditingController();
  final TextEditingController amount = TextEditingController();
  String numberLabel = '';

  void select({
    required String id,
    required int mineValue,
    required int theirValue,
  }) {
    isItemOffer = true;
    offeredTradeId = id;
    this.mineValue = mineValue;
    amount.clear();
    numberLabel = tradeDifferenceLabel(
      theirValue: theirValue,
      mineValue: mineValue,
    );
    notifyListeners();
  }

  void setItemOffer(bool value) {
    if (isItemOffer == value) return;
    isItemOffer = value;
    if (value) {
      amount.clear();
      if (offeredTradeId == null) {
        mineValue = null;
        numberLabel = '';
      }
    } else {
      offeredTradeId = null;
      mineValue = null;
      _syncCashLabel();
    }
    notifyListeners();
  }

  void setCashAmount(String raw) {
    if (isItemOffer) return;
    _syncCashLabel(raw);
    notifyListeners();
  }

  void _syncCashLabel([String? raw]) {
    final text = (raw ?? amount.text).trim();
    numberLabel = text.isEmpty ? '' : '$text BYC';
  }

  void clear() {
    offeredTradeId = null;
    mineValue = null;
    isItemOffer = true;
    message.clear();
    amount.clear();
    numberLabel = '';
    notifyListeners();
  }

  @override
  void dispose() {
    message.dispose();
    amount.dispose();
    super.dispose();
  }
}

/// The member's listings, large enough to be the offer itself.
class TradeItemRail extends StatefulWidget {
  final String targetId;
  final int theirValue;
  final TradeOfferDraft draft;

  const TradeItemRail({
    super.key,
    required this.targetId,
    required this.theirValue,
    required this.draft,
  });

  @override
  State<TradeItemRail> createState() => _TradeItemRailState();
}

class _TradeItemRailState extends State<TradeItemRail>
    with SingleTickerProviderStateMixin {
  List<Trade> _trades = const [];
  bool _loading = true;
  bool _reduce = false;
  late final PageController _pages;
  late final AnimationController _rise;

  @override
  void initState() {
    super.initState();
    _pages = PageController(viewportFraction: 0.78);
    _rise = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) _rise.value = 1;
  }

  @override
  void dispose() {
    _pages.dispose();
    _rise.dispose();
    super.dispose();
  }

  void _play() {
    if (_reduce) {
      _rise.value = 1;
      return;
    }
    if (!_rise.isAnimating && _rise.value == 0) {
      _rise.forward();
    }
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final backend = context.read<TradeBackendProvider>();
      final res = await backend.listMyTrades(
        ownerId: userId,
        page: 1,
        size: 50,
        forceRefresh: true,
      );
      final items = (res['items'] as List?) ?? const [];
      final trades = items
          .whereType<Map>()
          .map((item) => Trade.fromJson(Map<String, dynamic>.from(item)))
          .where(
            (trade) =>
                (trade.status == TradeStatus.active ||
                    trade.status == TradeStatus.inOffer) &&
                trade.id != widget.targetId,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _trades = trades;
        _loading = false;
      });
      _play();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.draft,
      builder: (context, _) {
        final itemMode = widget.draft.isItemOffer;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Text(
                itemMode ? 'Your offer' : 'Cash bid',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Expanded(child: itemMode ? _itemBody() : _cashBody()),
          ],
        );
      },
    );
  }

  Widget _cashBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.draft.numberLabel.isEmpty
                  ? 'Enter BYC below'
                  : widget.draft.numberLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You arrange payment with the other person. The app does not hold funds. Use PayPal only to even an item swap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white,
          ),
        ),
      );
    }
    if (_trades.isEmpty) {
      return const Center(
        child: Text(
          'No items',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return PageView.builder(
      controller: _pages,
      itemCount: _trades.length,
      itemBuilder: (context, index) {
        final trade = _trades[index];
        final selected = widget.draft.offeredTradeId == trade.id;
        return _offerCard(trade, index, selected);
      },
    );
  }

  Widget _offerCard(Trade trade, int index, bool selected) {
    final key =
        trade.thumbnailKey ??
        (trade.images.isEmpty ? null : trade.images.first);
    return GestureDetector(
      onTap: () {
        HapticUtils.selection();
        widget.draft.select(
          id: trade.id,
          mineValue: trade.estimatedValue,
          theirValue: widget.theirValue,
        );
      },
      child: AnimatedBuilder(
        animation: _rise,
        builder: (context, child) {
          final start = (index * 0.08).clamp(0.0, 0.4);
          final span = (1 - start).clamp(0.2, 1.0);
          final raw = ((_rise.value - start) / span).clamp(0.0, 1.0);
          final t = Curves.easeOutCubic.transform(raw);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 64 * (1 - t)),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
          child: AnimatedScale(
            scale: selected ? 1.04 : 0.96,
            duration: Duration(milliseconds: _reduce ? 80 : 280),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: Duration(milliseconds: _reduce ? 80 : 280),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.28),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: StagePhotoWell(
                      imageKey: key,
                      color: AppTheme.tradeColor,
                      radius: 32,
                      inset: 16,
                      lit: selected,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    trade.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: _reduce ? 80 : 220),
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: selected ? 1 : 0.82,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                    child: Text(
                      selected ? 'In the offer' : '${trade.estimatedValue} BYC',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TradeOfferExtras extends StatelessWidget {
  final String tradeId;
  final TradeOfferDraft draft;

  const TradeOfferExtras({
    super.key,
    required this.tradeId,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final uneven = draft.isItemOffer &&
            draft.mineValue != null &&
            draft.numberLabel.isNotEmpty &&
            draft.numberLabel != 'Even';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StageStaggerIn(
              index: 0,
              child: _OfferModeSwitcher(draft: draft),
            ),
            const SizedBox(height: 10),
            if (!draft.isItemOffer) ...[
              StageStaggerIn(
                index: 1,
                child: StageGlassField(
                  controller: draft.amount,
                  hint: 'BYC amount',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  dense: true,
                  onChanged: draft.setCashAmount,
                ),
              ),
              const SizedBox(height: 10),
            ],
            StageStaggerIn(
              index: draft.isItemOffer ? 1 : 2,
              child: StageGlassField(
                controller: draft.message,
                hint: 'Add a note',
                minLines: 1,
                maxLines: 3,
                dense: true,
              ),
            ),
            if (uneven) ...[
              const SizedBox(height: 10),
              StageStaggerIn(
                index: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.tradeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.balance_rounded,
                          color: AppTheme.tradeColor, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Not an even swap. After you send, use Even this trade to settle the difference with PayPal.',
                          style: TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OfferModeSwitcher extends StatelessWidget {
  final TradeOfferDraft draft;

  const _OfferModeSwitcher({required this.draft});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);
    final thumb = isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white;
    final on = isDark ? Colors.white : Colors.black87;
    final off = on.withValues(alpha: 0.55);

    Widget mode(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticUtils.selection();
            onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? on : off,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment(draft.isItemOffer ? -1 : 1, 0),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: thumb,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: [
              mode('Item swap', draft.isItemOffer, () => draft.setItemOffer(true)),
              mode('Cash bid', !draft.isItemOffer, () => draft.setItemOffer(false)),
            ],
          ),
        ],
      ),
    );
  }
}
