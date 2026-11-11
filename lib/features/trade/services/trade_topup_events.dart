import 'dart:async';

enum TradeTopUpEventKind { paypalReturned, paypalCancelled, tradeChanged }

class TradeTopUpEvent {
  final TradeTopUpEventKind kind;
  final String? tradeId;
  final String? offerId;
  final String? topUpId;
  final String? status;

  const TradeTopUpEvent(
    this.kind, {
    this.tradeId,
    this.offerId,
    this.topUpId,
    this.status,
  });
}

/// Lets PayPal deep links and trade/offer actions tell any open
/// [EvenTradePanel] to reload its top-up.
class TradeTopUpEvents {
  TradeTopUpEvents._();
  static final TradeTopUpEvents instance = TradeTopUpEvents._();

  final _controller = StreamController<TradeTopUpEvent>.broadcast();

  Stream<TradeTopUpEvent> get stream => _controller.stream;

  void emit(TradeTopUpEvent event) => _controller.add(event);
}
