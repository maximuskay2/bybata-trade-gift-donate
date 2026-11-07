import 'package:bybata/features/trade/models/trade_topup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a PayPal top-up and labels a refund', () {
    final topUp = TradeTopUp.fromJson({
      'id': 'tu_1',
      'tradeId': 'tr_1',
      'offerId': 'of_1',
      'payerId': 'bidder',
      'payeeId': 'owner',
      'amount': '42.50',
      'currency': 'USD',
      'status': 'REFUNDED',
      'source': 'fallback',
      'aiReason': 'The book is worth less.',
      'confidence': 0.62,
      'payerAccepted': true,
      'payeeAccepted': true,
      'capped': false,
    });

    expect(topUp.amount, 42.5);
    expect(topUp.isAi, isFalse);
    expect(topUp.acceptedBy('bidder'), isTrue);
    expect(tradeTopUpStatusLabel(topUp), 'Refunded');
  });
}
