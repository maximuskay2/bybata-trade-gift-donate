import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/motion/soft_reveal.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
import '../widgets/trade_listing_preview.dart';
import '../widgets/even_trade_panel.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/offer_timeline_widget.dart';
import 'trade_chat_screen.dart';
import 'negotiation_screen.dart';
import 'counter_offer_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class _AcceptOfferIntent extends Intent {
  const _AcceptOfferIntent();
}

class _RejectOfferIntent extends Intent {
  const _RejectOfferIntent();
}

class _CloseNegotiationIntent extends Intent {
  const _CloseNegotiationIntent();
}

/// Dedicated screen for ongoing trade negotiations.
/// Shows offer timeline, chat, and actions. Accessible until trade ends/expires/finalizes/cancels.
class ExistingOfferNegotiationScreen extends StatefulWidget {
  final trade_models.Trade targetTrade;
  final String offerId;
  final String initiatorUserId; // Bidder who made the offer
  final String initiatorName;
  final trade_models.Trade? initialOfferedTrade;
  final bool isReceived; // True if current user is the trade owner (received the offer)

  const ExistingOfferNegotiationScreen({
    super.key,
    required this.targetTrade,
    required this.offerId,
    required this.initiatorUserId,
    required this.initiatorName,
    this.initialOfferedTrade,
    required this.isReceived,
  });

  @override
  State<ExistingOfferNegotiationScreen> createState() =>
      _ExistingOfferNegotiationScreenState();
}

class _ExistingOfferNegotiationScreenState
    extends State<ExistingOfferNegotiationScreen> {
  List<trade_models.TradeOffer>? _offerTimeline;
  bool _isLoading = true;
  String? _loadError;
  String? _status;
  bool _isCashOffer = false;
  List<trade_models.Trade> _userTrades = [];

  @override
  void initState() {
    super.initState();
    _loadOfferHistory();
    _loadUserTrades();
  }

  Future<void> _loadOfferHistory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final history = await backend.getOfferHistory(widget.offerId);
      if (!mounted) return;

      if (history == null) {
        setState(() {
          _offerTimeline = null;
          _loadError = backend.error ?? 'Could not load this negotiation.';
        });
        return;
      }

      final timelineData = history['timeline'] as List?;
      if (timelineData == null || timelineData.isEmpty) {
        setState(() {
          _offerTimeline = [];
          _status = 'pending';
        });
        return;
      }

      final parsed = <trade_models.TradeOffer>[];
      for (final entry in timelineData) {
        final offer = trade_models.TradeOffer.tryParseTimelineEntry(entry);
        if (offer != null) parsed.add(offer);
      }

      final lastMap = timelineData.last is Map
          ? Map<String, dynamic>.from(timelineData.last as Map)
          : null;

      setState(() {
        _offerTimeline = parsed;
        _status = lastMap?['status']?.toString().toLowerCase();
        _isCashOffer = lastMap != null &&
            ((lastMap['amount'] != null &&
                    lastMap['amount'].toString().isNotEmpty) ||
                (lastMap['requestedAmount'] != null &&
                    lastMap['requestedAmount'].toString().isNotEmpty));
        if (parsed.isEmpty) {
          _loadError = 'We could not display offer details. You can still use actions below.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _offerTimeline = null;
          _loadError = 'Something went wrong loading this offer. Pull down to retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserTrades() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final userId = auth.currentUser?.id;
      if (userId != null) {
        final res = await backend.listMyTrades(
          ownerId: userId,
          page: 1,
          size: 50,
          forceRefresh: true,
        );
        final items = (res['items'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _userTrades = items
                .map((e) =>
                    trade_models.Trade.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  /// Most recent proposal in the chain (original or counter).
  String get _latestOfferId {
    if (_offerTimeline != null && _offerTimeline!.isNotEmpty) {
      return _offerTimeline!.last.id;
    }
    return widget.offerId;
  }

  trade_models.TradeOffer? get _latestOffer {
    if (_offerTimeline == null || _offerTimeline!.isEmpty) return null;
    return _offerTimeline!.last;
  }

  /// True when the latest pending proposal was made by the current user.
  bool get _isLatestOfferAuthoredByMe {
    final last = _latestOffer;
    if (last == null) return false;
    if (last.isOwnerCounter) return widget.isReceived;
    return !widget.isReceived;
  }

  /// True when the listing owner can accept/decline the latest bidder terms.
  bool get _isLatestOfferFromBidder {
    final last = _latestOffer;
    if (last == null) return true;
    return !last.isOwnerCounter;
  }

  Future<void> _openChat() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    if (currentUserId == null) return;

    // Partner: if we received the offer, partner is initiator (bidder); else partner is owner
    final partnerId = widget.isReceived ? widget.initiatorUserId : widget.targetTrade.owner.id;
    final partnerName = widget.isReceived ? widget.initiatorName : widget.targetTrade.owner.name;

    if (!mounted) return;
    await GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => TradeChatScreen(
          trade: widget.targetTrade,
          partnerId: partnerId,
          partnerName: partnerName,
          offerId: widget.offerId,
          offerStatus: _status,
          isOwner: widget.isReceived,
        ),
      ),
    );
  }

  Future<void> _openCounterOffer() async {
    if (!mounted) return;
    if (widget.isReceived) {
      // Owner countering: use dedicated screen to pick from counterparty's items or ask for cash
      await GuardedNavigator.push(context,
        MaterialPageRoute(
          builder: (_) => CounterOfferScreen(
            targetTrade: widget.targetTrade,
            offerId: widget.offerId,
            parentOfferId: _latestOfferId,
            counterpartyUserId: widget.initiatorUserId,
            counterpartyName: widget.initiatorName,
            counterpartyOfferedTrade: widget.initialOfferedTrade,
          ),
        ),
      );
    } else {
      // Bidder countering: use NegotiationScreen to pick from own items
      await GuardedNavigator.push(context,
        MaterialPageRoute(
          builder: (_) => NegotiationScreen(
            targetTrade: widget.targetTrade,
            userTrades: _userTrades,
            offerId: widget.offerId,
            parentOfferId: _latestOfferId,
            initiatorUserId: widget.initiatorUserId,
            initialCounterpartyOfferedTrade: widget.initialOfferedTrade,
          ),
        ),
      );
    }
    _loadOfferHistory();
  }

  Future<void> _acceptOffer() async {
    HapticFeedback.lightImpact();
    final backend = Provider.of<TradeBackendProvider>(context, listen: false);
    final success = await backend.acceptOffer(_latestOfferId);
    if (!mounted) return;
    if (success) {
      AppToast.success(context, 'Offer accepted!');
      Navigator.pop(context, true);
    } else {
      AppToast.show(context, backend.error ?? 'Failed to accept');
    }
  }

  Future<void> _rejectOffer() async {
    HapticFeedback.lightImpact();
    final backend = Provider.of<TradeBackendProvider>(context, listen: false);
    final success = await backend.rejectOffer(_latestOfferId);
    if (!mounted) return;
    if (success) {
      AppToast.warning(context, 'Offer declined');
      Navigator.pop(context, true);
    } else {
      AppToast.show(context, backend.error ?? 'Failed to decline');
    }
  }

  Future<void> _withdrawOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Offer'),
        content: const Text(
          'Are you sure you want to withdraw this offer? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final backend = Provider.of<TradeBackendProvider>(context, listen: false);
    final success = await backend.withdrawOffer(widget.offerId);
    if (!mounted) return;
    if (success) {
      AppToast.warning(context, 'Offer withdrawn');
      Navigator.pop(context, true);
    } else {
      AppToast.show(context, backend.error ?? 'Failed to withdraw');
    }
  }

  trade_models.Trade? get _offeredTrade =>
      widget.initialOfferedTrade ?? _latestOffer?.offeredTrade;

  String get _partnerName => widget.isReceived
      ? widget.initiatorName
      : widget.targetTrade.owner.name;

  String _guidanceFor(String status) {
    if (status == 'pending') {
      if (_isLatestOfferAuthoredByMe) {
        return widget.isReceived
            ? 'Waiting on their reply to your counter. Chat if you need to clarify.'
            : 'Your offer is out. Hang tight, or counter again when they reply.';
      }
      if (widget.isReceived) {
        return _isLatestOfferFromBidder
            ? 'Accept, decline, or counter. For uneven item swaps, even it with PayPal first.'
            : 'Review their counter, then accept, decline, or send yours.';
      }
      return 'Counter with another item or cash, or wait for the owner.';
    }
    if (status.contains('accepted')) {
      return _isCashOffer
          ? 'Finalize the cash handoff when you are both ready.'
          : 'If PayPal settled the gap, finish the handoff in chat.';
    }
    return 'This negotiation is closed. Chat if you still need to coordinate.';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.tradeColor;
    final status =
        (_status ?? 'pending').toString().toLowerCase().replaceAll('_', '');
    final canAcceptReject =
        widget.isReceived && status == 'pending' && _isLatestOfferFromBidder;
    final canCounterOffer = status == 'pending' && !_isLatestOfferAuthoredByMe;
    final canWithdraw = !widget.isReceived &&
        status == 'pending' &&
        (_offerTimeline == null || _offerTimeline!.length <= 1);
    final (statusLabel, statusColor) =
        trade_models.getOfferStatusDisplayFromRaw(
      _status,
      isReceived: widget.isReceived,
      isCashOffer: _isCashOffer,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final sticky = canAcceptReject || canCounterOffer || canWithdraw;

    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.escape):
          const _CloseNegotiationIntent(),
      if (canAcceptReject) ...{
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            const _AcceptOfferIntent(),
        const SingleActivator(LogicalKeyboardKey.enter,
            control: true, shift: true): const _RejectOfferIntent(),
      },
    };
    final actions = <Type, Action<Intent>>{
      _CloseNegotiationIntent:
          CallbackAction<_CloseNegotiationIntent>(onInvoke: (_) {
        Navigator.pop(context);
        return null;
      }),
      if (canAcceptReject) ...{
        _AcceptOfferIntent: CallbackAction<_AcceptOfferIntent>(onInvoke: (_) {
          _acceptOffer();
          return null;
        }),
        _RejectOfferIntent: CallbackAction<_RejectOfferIntent>(onInvoke: (_) {
          _rejectOffer();
          return null;
        }),
      },
    };

    Widget scaffold = Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Negotiation',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded, color: accent),
            onPressed: _openChat,
            tooltip: 'Chat',
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null && focus.hasFocus) focus.unfocus();
        },
        child: _isLoading
          ? const BybataLoader()
          : Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                accent.withValues(alpha: 0.18),
                                Theme.of(context).scaffoldBackgroundColor,
                              ]
                            : [
                                accent.withValues(alpha: 0.10),
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -40,
                  right: -30,
                  child: IgnorePointer(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                      ),
                    ),
                  ),
                ),
                RefreshIndicator(
                  color: accent,
                  onRefresh: _loadOfferHistory,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(20, 4, 20, sticky ? 132 : 40),
                    children: [
                      SoftReveal(
                        index: 0,
                        child: _SwapHero(
                          target: widget.targetTrade,
                          offered: _offeredTrade,
                          isCash: _isCashOffer,
                          cashLabel: _latestOffer?.amount != null
                              ? '${_latestOffer!.amount} BYC'
                              : null,
                          accent: accent,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SoftReveal(
                        index: 1,
                        child: _PartnerStrip(
                          name: _partnerName,
                          subtitle: widget.isReceived
                              ? 'Offer from $_partnerName'
                              : 'Negotiating with $_partnerName',
                          statusLabel: statusLabel,
                          statusColor: statusColor,
                          accent: accent,
                          onChat: _openChat,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SoftReveal(
                        index: 2,
                        child: Text(
                          _guidanceFor(status),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: context.secondaryText,
                          ),
                        ),
                      ),
                      if (!_isCashOffer) ...[
                        const SizedBox(height: 18),
                        SoftReveal(
                          index: 3,
                          child: EvenTradePanel(
                            tradeId: widget.targetTrade.id,
                            offerId: widget.offerId,
                            tradeStatus:
                                widget.targetTrade.status.backendValue,
                          ),
                        ),
                      ],
                      if (_loadError != null) ...[
                        const SizedBox(height: 14),
                        SoftReveal(
                          index: 4,
                          child: _NoticeChip(
                            message: _loadError!,
                            isError: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SoftReveal(
                        index: 5,
                        child: Text(
                          'Offer history',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SoftReveal(
                        index: 6,
                        child: Text(
                          'You and $_partnerName see the same thread.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.tertiaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_offerTimeline != null &&
                          _offerTimeline!.isNotEmpty)
                        SoftReveal(
                          index: 7,
                          child: OfferTimelineWidget(
                            timeline: _offerTimeline!,
                            onCounterOfferTap: canCounterOffer
                                ? (_) => _openCounterOffer()
                                : null,
                          ),
                        )
                      else
                        SoftReveal(
                          index: 7,
                          child: _EmptyHistory(
                            failed: _offerTimeline == null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      ),
      bottomNavigationBar: sticky && !_isLoading
          ? _StickyActions(
              accent: accent,
              canAcceptReject: canAcceptReject,
              canCounterOffer: canCounterOffer,
              canWithdraw: canWithdraw,
              onAccept: _acceptOffer,
              onDecline: _rejectOffer,
              onCounter: _openCounterOffer,
              onWithdraw: _withdrawOffer,
              onChat: _openChat,
            )
          : null,
    );

    final hasKeyboard = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (hasKeyboard) {
      return Shortcuts(
        shortcuts: shortcuts,
        child: Actions(actions: actions, child: scaffold),
      );
    }
    return scaffold;
  }
}

class _SwapHero extends StatelessWidget {
  final trade_models.Trade target;
  final trade_models.Trade? offered;
  final bool isCash;
  final String? cashLabel;
  final Color accent;

  const _SwapHero({
    required this.target,
    required this.offered,
    required this.isCash,
    required this.cashLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCash ? 'Cash offer' : 'Item swap',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: context.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isCash
              ? 'BYC bid against ${target.title}'
              : 'Two listings in one deal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.secondaryText,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ItemTile(
                label: 'Their item',
                trade: target,
                accent: accent,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 54),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                ),
                child: Icon(
                  isCash ? Icons.payments_rounded : Icons.swap_horiz_rounded,
                  color: accent,
                ),
              ),
            ),
            Expanded(
              child: isCash
                  ? _CashTile(label: cashLabel ?? 'BYC', accent: accent)
                  : _ItemTile(
                      label: 'Your offer',
                      trade: offered,
                      accent: accent,
                      fallbackTitle: 'Item offer',
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String label;
  final trade_models.Trade? trade;
  final Color accent;
  final String fallbackTitle;

  const _ItemTile({
    required this.label,
    required this.trade,
    required this.accent,
    this.fallbackTitle = 'Listing',
  });

  @override
  Widget build(BuildContext context) {
    final title = trade?.title ?? fallbackTitle;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (trade == null) {
                    return ColoredBox(
                      color: accent.withValues(alpha: 0.12),
                      child: Icon(Icons.inventory_2_outlined,
                          color: accent, size: 36),
                    );
                  }
                  return TradeListingPreview(
                    trade: trade!,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    borderRadius: BorderRadius.circular(28),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: context.tertiaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: context.primaryText,
          ),
        ),
      ],
    );
  }
}

class _CashTile extends StatelessWidget {
  final String label;
  final Color accent;

  const _CashTile({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Cash bid',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: context.tertiaryText,
          ),
        ),
      ],
    );
  }
}

class _PartnerStrip extends StatelessWidget {
  final String name;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final Color accent;
  final VoidCallback onChat;

  const _PartnerStrip({
    required this.name,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.accent,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: accent.withValues(alpha: 0.14),
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onChat,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          style: IconButton.styleFrom(
            foregroundColor: accent,
            backgroundColor: accent.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _NoticeChip extends StatelessWidget {
  final String message;
  final bool isError;

  const _NoticeChip({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final accent = isError ? Colors.orange : AppTheme.tradeColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.info_outline_rounded : Icons.lightbulb_outline,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: context.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool failed;

  const _EmptyHistory({required this.failed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 36,
            color: failed ? Colors.orange : context.tertiaryText,
          ),
          const SizedBox(height: 10),
          Text(
            failed ? 'Could not load history' : 'No history yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            failed ? 'Pull down to retry' : 'New proposals show up here',
            style: TextStyle(fontSize: 12, color: context.tertiaryText),
          ),
        ],
      ),
    );
  }
}

class _StickyActions extends StatelessWidget {
  final Color accent;
  final bool canAcceptReject;
  final bool canCounterOffer;
  final bool canWithdraw;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCounter;
  final VoidCallback onWithdraw;
  final VoidCallback onChat;

  const _StickyActions({
    required this.accent,
    required this.canAcceptReject,
    required this.canCounterOffer,
    required this.canWithdraw,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
    required this.onWithdraw,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 12,
      color: isDark
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.96),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canAcceptReject)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              if (canAcceptReject && (canCounterOffer || canWithdraw))
                const SizedBox(height: 8),
              if (canCounterOffer || canWithdraw || !canAcceptReject)
                Row(
                  children: [
                    if (canCounterOffer)
                      Expanded(
                        child: FilledButton(
                          onPressed: onCounter,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Counter'),
                        ),
                      ),
                    if (canCounterOffer && canWithdraw) const SizedBox(width: 10),
                    if (canWithdraw)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onWithdraw,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: BorderSide(
                                color:
                                    AppColors.warning.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Withdraw'),
                        ),
                      ),
                    if (!canAcceptReject && !canCounterOffer && !canWithdraw)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onChat,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Open chat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
  }
}
