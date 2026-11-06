import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme_extensions.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
import '../widgets/trade_listing_preview.dart';
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final status = (_status ?? 'pending').toString().toLowerCase().replaceAll('_', '');
    final canAcceptReject =
        widget.isReceived && status == 'pending' && _isLatestOfferFromBidder;
    final canCounterOffer = status == 'pending' && !_isLatestOfferAuthoredByMe;
    final canWithdraw = !widget.isReceived &&
        status == 'pending' &&
        (_offerTimeline == null || _offerTimeline!.length <= 1);

    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.escape): const _CloseNegotiationIntent(),
      if (canAcceptReject) ...{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): const _AcceptOfferIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true, shift: true): const _RejectOfferIntent(),
      },
    };
    final actions = <Type, Action<Intent>>{
      _CloseNegotiationIntent: CallbackAction<_CloseNegotiationIntent>(onInvoke: (_) {
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

    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ongoing Negotiation',
              style: TextStyle(fontWeight: FontWeight.w900, color: onSurface),
            ),
            if (_status != null && _status!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final (label, color) = trade_models.getOfferStatusDisplayFromRaw(
                    _status,
                    isReceived: widget.isReceived,
                    isCashOffer: _isCashOffer,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                  );
                },
              ),
            ],
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded, color: primaryColor),
            onPressed: _openChat,
            tooltip: 'Chat',
          ),
        ],
      ),
      body: _isLoading
          ? const BybataLoader()
          : RefreshIndicator(
              onRefresh: _loadOfferHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPartnerCard(primaryColor),
                    const SizedBox(height: 16),
                    _buildTradeContextCard(primaryColor),
                    const SizedBox(height: 16),
                    _buildStatusGuidanceCard(primaryColor, status),
                    if (_loadError != null) ...[
                      const SizedBox(height: 16),
                      _buildInlineNotice(_loadError!, isError: true),
                    ],
                    const SizedBox(height: 20),
                    if (_offerTimeline != null && _offerTimeline!.isNotEmpty) ...[
                      Text(
                        'Both you and ${widget.initiatorName} see the same offer history below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OfferTimelineWidget(
                        timeline: _offerTimeline!,
                        onCounterOfferTap: canCounterOffer ? (_) => _openCounterOffer() : null,
                      ),
                      const SizedBox(height: 24),
                    ] else if (_offerTimeline != null && _offerTimeline!.isEmpty) ...[
                      _buildTimelineEmptyState(primaryColor),
                      const SizedBox(height: 24),
                    ],
                    _buildActionSection(
                      primaryColor,
                      canAcceptReject: canAcceptReject,
                      canCounterOffer: canCounterOffer,
                      canWithdraw: canWithdraw,
                      status: status,
                    ),
                  ],
                ),
              ),
            ),
    );

    final hasKeyboard = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (hasKeyboard) {
      return Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: actions,
          child: scaffold,
        ),
      );
    }
    return scaffold;
  }

  Widget _buildInlineNotice(String message, {bool isError = false}) {
    final accent = isError ? Colors.orange : Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.info_outline : Icons.lightbulb_outline,
            size: 20,
            color: isError ? Colors.orange.shade800 : accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: context.secondaryText, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(Color primaryColor) {
    final partnerName = widget.isReceived
        ? widget.initiatorName
        : widget.targetTrade.owner.name;
    final role = widget.isReceived ? 'Offer from' : 'Negotiating with';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.surfaceCardDecoration(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: primaryColor.withValues(alpha: 0.12),
            child: Icon(Icons.person_outline, color: primaryColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.tertiaryText,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  partnerName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isReceived
                      ? 'Review their proposal and respond below.'
                      : 'Waiting for the listing owner to respond.',
                  style: TextStyle(fontSize: 12, color: context.secondaryText, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGuidanceCard(Color primaryColor, String status) {
    final (label, color) = trade_models.getOfferStatusDisplayFromRaw(
      _status,
      isReceived: widget.isReceived,
      isCashOffer: _isCashOffer,
    );
    String guidance;
    if (status == 'pending') {
      if (_isLatestOfferAuthoredByMe) {
        guidance = widget.isReceived
            ? 'Waiting for the other party to respond to your counter-offer. You can message them in chat.'
            : 'Your counter-offer was sent. You can send another counter if they reply, or wait for their response.';
      } else if (widget.isReceived) {
        guidance = _isLatestOfferFromBidder
            ? 'Accept their terms, decline, or counter with items or cash you want from them.'
            : 'Review their counter-offer and respond with accept, decline, or your own counter.';
      } else {
        guidance =
            'Send a counter-offer with your item or cash offer. Negotiation continues until someone accepts or declines.';
      }
    } else if (status.contains('accepted')) {
      guidance = 'Complete the trade in chat and finalize when you have both agreed on handoff.';
    } else {
      guidance = 'This negotiation is closed. Open chat if you need to coordinate.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.surfaceCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            guidance,
            style: TextStyle(fontSize: 13, color: context.secondaryText, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEmptyState(Color primaryColor, {bool failed = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.surfaceCardDecoration(radius: 16),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 40,
            color: failed ? Colors.orange : context.tertiaryText,
          ),
          const SizedBox(height: 12),
          Text(
            failed ? 'Could not load offer history' : 'No offer history yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.secondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            failed ? 'Pull down to retry' : 'New proposals will show here',
            style: TextStyle(color: context.tertiaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeContextCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.surfaceCardDecoration(radius: 16),
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
                Text(
                  'TRADING FOR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: context.tertiaryText,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.targetTrade.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
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

  Widget _buildActionSection(
    Color primaryColor, {
    required bool canAcceptReject,
    required bool canCounterOffer,
    required bool canWithdraw,
    required String status,
  }) {
    final hasPrimaryActions = canAcceptReject || canCounterOffer || canWithdraw;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.surfaceCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_outlined, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'What would you like to do?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.primaryText,
                ),
              ),
            ],
          ),
          if (!hasPrimaryActions) ...[
            const SizedBox(height: 12),
            Text(
              'No response needed — this offer is no longer pending.',
              style: TextStyle(fontSize: 13, color: context.secondaryText, height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          if (canAcceptReject) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _rejectOffer,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _acceptOffer,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept Offer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (canCounterOffer) const SizedBox(height: 12),
          ],
          if (canCounterOffer)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openCounterOffer,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Make Counter-Offer'),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (canWithdraw) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _withdrawOffer,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Withdraw Offer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Open Chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
