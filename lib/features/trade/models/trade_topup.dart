/// Cash that evens one trade offer. Gift and donate listings never use this.
class TradeTopUp {
  final String id;
  final String tradeId;
  final String offerId;
  final String payerId;
  final String payeeId;
  final double amount;
  final String currency;
  final String? paypalOrderId;
  final String? captureId;
  final String? refundId;
  final String status;
  final String? aiReason;
  final double? confidence;
  final String source;
  final bool payerAccepted;
  final bool payeeAccepted;
  final bool capped;
  final String? approveLink;

  const TradeTopUp({
    required this.id,
    required this.tradeId,
    required this.offerId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.source,
    required this.payerAccepted,
    required this.payeeAccepted,
    required this.capped,
    this.paypalOrderId,
    this.captureId,
    this.refundId,
    this.aiReason,
    this.confidence,
    this.approveLink,
  });

  bool get isAi => source == 'ai';

  bool acceptedBy(String userId) {
    if (userId == payerId) return payerAccepted;
    if (userId == payeeId) return payeeAccepted;
    return false;
  }

  factory TradeTopUp.fromJson(Map<String, dynamic> json) {
    return TradeTopUp(
      id: json['id']?.toString() ?? '',
      tradeId: json['tradeId']?.toString() ?? '',
      offerId: json['offerId']?.toString() ?? '',
      payerId: json['payerId']?.toString() ?? '',
      payeeId: json['payeeId']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'USD',
      paypalOrderId: json['paypalOrderId']?.toString(),
      captureId: json['captureId']?.toString(),
      refundId: json['refundId']?.toString(),
      status: json['status']?.toString() ?? 'SUGGESTED',
      aiReason: json['aiReason']?.toString(),
      confidence: json['confidence'] == null ? null : _asDouble(json['confidence']),
      source: json['source']?.toString() ?? 'fallback',
      payerAccepted: json['payerAccepted'] == true,
      payeeAccepted: json['payeeAccepted'] == true,
      capped: json['capped'] == true,
      approveLink: json['approveLink']?.toString(),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String tradeTopUpStatusLabel(TradeTopUp topUp) {
  switch (topUp.status) {
    case 'SUGGESTED':
      return 'Suggested';
    case 'COUNTERED':
      return 'Countered';
    case 'DECLINED':
      return 'Declined';
    case 'ACCEPTED':
      return topUp.amount <= 0 ? 'Already even' : 'Accepted';
    case 'ORDER_CREATED':
      return 'Waiting for PayPal';
    case 'CAPTURED':
      return 'Paid with PayPal';
    case 'REFUND_PENDING':
      return 'Refund in progress';
    case 'REFUNDED':
      return 'Refunded';
    case 'FAILED':
      return 'Payment failed';
    default:
      return topUp.status;
  }
}
