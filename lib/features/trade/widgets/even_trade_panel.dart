import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../api/trade_api.dart';
import '../models/trade_topup.dart';
import '../services/trade_topup_events.dart';

/// PayPal top-up for an uneven trade offer.
/// Gift and donate flows do not mount this widget.
class EvenTradePanel extends StatefulWidget {
  final String tradeId;
  final String? offerId;
  final String tradeStatus;

  const EvenTradePanel({
    super.key,
    required this.tradeId,
    this.offerId,
    this.tradeStatus = 'OPEN',
  });

  @override
  State<EvenTradePanel> createState() => _EvenTradePanelState();
}

class _EvenTradePanelState extends State<EvenTradePanel> with WidgetsBindingObserver {
  TradeApi? _api;
  TradeTopUp? _topUp;
  bool _loading = true;
  bool _busy = false;
  bool _cancelledLocally = false;
  String? _error;
  StreamSubscription<TradeTopUpEvent>? _events;

  bool get _cancelled => widget.tradeStatus == 'CANCELLED' || _cancelledLocally;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = TradeTopUpEvents.instance.stream.listen(_onEvent);
    _load();
  }

  @override
  void didUpdateWidget(covariant EvenTradePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tradeId != widget.tradeId ||
        oldWidget.offerId != widget.offerId ||
        oldWidget.tradeStatus != widget.tradeStatus) {
      _load(silent: _topUp != null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _busy) return;
    if (_topUp?.status == 'ORDER_CREATED') _load(silent: true);
  }

  void _onEvent(TradeTopUpEvent event) {
    if (!mounted) return;
    final current = _topUp;
    final mine = (event.tradeId != null && event.tradeId == widget.tradeId) ||
        (event.offerId != null && event.offerId == widget.offerId) ||
        (event.topUpId != null && event.topUpId == current?.id);
    if (!mine) return;
    switch (event.kind) {
      case TradeTopUpEventKind.paypalReturned:
        if (current != null &&
            current.status == 'ORDER_CREATED' &&
            current.paypalOrderId != null &&
            event.status != 'CAPTURED') {
          _refreshPayment();
        } else {
          _load(silent: true);
        }
        break;
      case TradeTopUpEventKind.paypalCancelled:
        _load(silent: true);
        break;
      case TradeTopUpEventKind.tradeChanged:
        if (event.status == 'CANCELLED') {
          setState(() => _cancelledLocally = true);
        }
        _load(silent: true);
        break;
    }
  }

  Future<TradeApi> _client() async {
    if (_api != null) return _api!;
    final base = await EnvConfig.getBaseUrl();
    _api = TradeApi(ApiClient(base, const FlutterSecureStorage()));
    return _api!;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = await _client();
      final rows = await api.listTradeTopUps(widget.tradeId);
      final match = rows
          .map(TradeTopUp.fromJson)
          .where((row) => widget.offerId == null || row.offerId == widget.offerId)
          .toList();
      if (!mounted) return;
      setState(() {
        _topUp = match.isEmpty ? null : match.first;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      final denied = error is DioException &&
          (error.response?.statusCode == 401 || error.response?.statusCode == 403);
      setState(() {
        _loading = false;
        _topUp = null;
        _error = denied ? null : _message(error);
      });
    }
  }

  Future<void> _even() async {
    if (widget.offerId == null) return;
    if (AppRoutes.requireSignIn(context)) return;
    await _run(() async {
      final api = await _client();
      final json = await api.evenTrade(widget.tradeId, widget.offerId!);
      return TradeTopUp.fromJson(json);
    });
  }

  Future<void> _respond(String action, {double? amount}) async {
    final id = _topUp?.id;
    if (id == null) return;
    await _run(() async {
      final api = await _client();
      final json = await api.respondTradeTopUp(id, action: action, amount: amount);
      return TradeTopUp.fromJson(json);
    });
  }

  Future<void> _pay() async {
    final current = _topUp;
    if (current == null) return;
    await _run(() async {
      final api = await _client();
      final json = await api.createTradeTopUpOrder(current.id);
      final next = TradeTopUp.fromJson(json);
      final link = next.approveLink;
      if (link != null && link.isNotEmpty) {
        final uri = Uri.tryParse(link);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return next;
    });
    if (mounted) {
      AppToast.info(context, 'Finish in PayPal. This updates when you come back.');
    }
  }

  Future<void> _refreshPayment() async {
    final current = _topUp;
    if (current == null) return;
    await _run(() async {
      final api = await _client();
      if (current.paypalOrderId == null) {
        final rows = await api.listTradeTopUps(widget.tradeId);
        final match = rows.map(TradeTopUp.fromJson).where((row) => row.id == current.id);
        return match.isEmpty ? current : match.first;
      }
      final json = await api.captureTradeTopUp(current.id, orderId: current.paypalOrderId);
      return TradeTopUp.fromJson(json);
    });
  }

  Future<void> _run(Future<TradeTopUp> Function() action) async {
    setState(() => _busy = true);
    try {
      final next = await action();
      if (!mounted) return;
      setState(() {
        _topUp = next;
        _busy = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _dispute() async {
    setState(() => _busy = true);
    try {
      final api = await _client();
      await api.disputeTrade(widget.tradeId, reason: 'Trade top-up disputed in the app');
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _counter() async {
    final controller = TextEditingController(text: _topUp?.amount.toStringAsFixed(2) ?? '');
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Counter the top-up'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'USD amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;
    await _respond('counter', amount: amount);
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final topUp = _topUp;
    final cancelled = _cancelled;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (widget.offerId == null && topUp == null && _error == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.tradeColor.withValues(alpha: isDark ? 0.22 : 0.12),
            AppTheme.tradeColor.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
        ),
        border: Border.all(
          color: AppTheme.tradeColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.tradeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.balance_rounded,
                    color: AppTheme.tradeColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Even with PayPal',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (topUp != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.tradeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tradeTopUpStatusLabel(topUp),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.tradeColor,
                    ),
                  ),
                ),
            ],
          ),
          if (topUp == null && widget.offerId != null && !cancelled) ...[
            const SizedBox(height: 10),
            Text(
              'Items not worth the same? Get a fair USD top-up, both accept it, then pay in PayPal.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 12),
            _button('Even this trade', _busy ? null : _even),
          ],
          if (topUp != null) ...[
            const SizedBox(height: 12),
            Text(
              topUp.amount <= 0
                  ? 'Already even'
                  : '${topUp.currency} ${topUp.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            if (topUp.aiReason != null) ...[
              const SizedBox(height: 8),
              Text(
                topUp.aiReason!,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${topUp.isAi ? 'AI suggestion' : 'Price-band estimate'}'
              '${topUp.confidence != null ? ' · ${(topUp.confidence! * 100).round()}% confidence' : ''}'
              '${topUp.capped ? ' · capped' : ''}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            if (topUp.status == 'CAPTURED') ...[
              const SizedBox(height: 8),
              const Text('PayPal payment received. This trade is even.'),
              const SizedBox(height: 10),
              _button('Dispute and refund', _busy ? null : _dispute, filled: false),
            ],
            if (topUp.status == 'REFUNDED' || topUp.status == 'REFUND_PENDING' || cancelled) ...[
              const SizedBox(height: 8),
              Text(
                topUp.status == 'REFUNDED'
                    ? 'PayPal refunded this top-up.'
                    : cancelled
                        ? 'This trade is cancelled. ${topUp.status == 'CAPTURED' ? 'The PayPal top-up can be refunded from the dispute or cancel action.' : tradeTopUpStatusLabel(topUp)}'
                        : 'Refund is on the way.',
              ),
            ],
            if (_canRespond(topUp, userId)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _button(topUp.acceptedBy(userId!) ? 'Accepted' : 'Accept', _busy || topUp.acceptedBy(userId) ? null : () => _respond('accept')),
                  _button('Counter', _busy ? null : _counter, filled: false),
                  _button('Decline', _busy ? null : () => _respond('decline'), filled: false),
                ],
              ),
            ],
            if (userId == topUp.payerId &&
                topUp.amount > 0 &&
                (topUp.status == 'ACCEPTED' || topUp.status == 'ORDER_CREATED')) ...[
              const SizedBox(height: 10),
              _button(topUp.status == 'ORDER_CREATED' ? 'Continue PayPal' : 'Pay with PayPal', _busy ? null : _pay),
              const SizedBox(height: 8),
              _button('Refresh payment', _busy ? null : _refreshPayment, filled: false),
            ],
            if (topUp.status == 'DECLINED' && widget.offerId != null && !cancelled) ...[
              const SizedBox(height: 10),
              _button('Ask again', _busy ? null : _even, filled: false),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  bool _canRespond(TradeTopUp topUp, String? userId) {
    if (userId == null) return false;
    if (userId != topUp.payerId && userId != topUp.payeeId) return false;
    return topUp.status == 'SUGGESTED' || topUp.status == 'COUNTERED';
  }

  Widget _button(String label, VoidCallback? onPressed, {bool filled = true}) {
    if (!filled) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: AppTheme.tradeColor),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

String _message(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is List) return message.join(' ');
      return message.toString();
    }
    return error.message ?? 'Request failed';
  }
  return 'Something went wrong';
}
