import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bybata/features/trade/models/trade_models.dart';

/// Minimal fixture for TradeOffer.fromJson - only status varies.
Map<String, dynamic> _minimalOfferJson({String status = 'PENDING'}) => {
      'id': 'offer-1',
      'status': status,
      'trade': <String, dynamic>{'id': 't1', 'owner': <String, dynamic>{}},
      'bidder': <String, dynamic>{},
    };

void main() {
  group('TradeOffer status parsing (_parseOfferStatus via fromJson)', () {
    test('parses PENDING', () {
      final offer = TradeOffer.fromJson(_minimalOfferJson(status: 'PENDING'));
      expect(offer.status, equals(OfferStatus.pending));
    });

    test('parses ACCEPTED', () {
      final offer = TradeOffer.fromJson(_minimalOfferJson(status: 'ACCEPTED'));
      expect(offer.status, equals(OfferStatus.accepted));
    });

    test('parses ACCEPTED_AWAITING_FINALIZATION (underscores)', () {
      final offer = TradeOffer.fromJson(
        _minimalOfferJson(status: 'ACCEPTED_AWAITING_FINALIZATION'),
      );
      expect(offer.status, equals(OfferStatus.acceptedAwaitingFinalization));
    });

    test('parses accepted_awaiting_finalization (lowercase)', () {
      final offer = TradeOffer.fromJson(
        _minimalOfferJson(status: 'accepted_awaiting_finalization'),
      );
      expect(offer.status, equals(OfferStatus.acceptedAwaitingFinalization));
    });

    test('parses REJECTED', () {
      final offer = TradeOffer.fromJson(_minimalOfferJson(status: 'REJECTED'));
      expect(offer.status, equals(OfferStatus.rejected));
    });

    test('parses DECLINED', () {
      final offer = TradeOffer.fromJson(_minimalOfferJson(status: 'DECLINED'));
      expect(offer.status, equals(OfferStatus.declined));
    });

    test('parses WITHDRAWN', () {
      final offer = TradeOffer.fromJson(_minimalOfferJson(status: 'WITHDRAWN'));
      expect(offer.status, equals(OfferStatus.withdrawn));
    });

    test('parses FINALIZED', () {
      final offer = TradeOffer.fromJson(_minimalOfferJson(status: 'FINALIZED'));
      expect(offer.status, equals(OfferStatus.finalized));
    });

    test('parses COUNTER_OFFER', () {
      final offer =
          TradeOffer.fromJson(_minimalOfferJson(status: 'COUNTER_OFFER'));
      expect(offer.status, equals(OfferStatus.counterOffer));
    });

    test('unknown status defaults to pending', () {
      final offer =
          TradeOffer.fromJson(_minimalOfferJson(status: 'UNKNOWN_STATUS'));
      expect(offer.status, equals(OfferStatus.pending));
    });

    test('null status defaults to pending', () {
      final json = _minimalOfferJson();
      json.remove('status');
      final offer = TradeOffer.fromJson(json);
      expect(offer.status, equals(OfferStatus.pending));
    });
  });

  group('getOfferStatusDisplayFromRaw', () {
    test('returns correct label for PENDING received', () {
      final (label, _) =
          getOfferStatusDisplayFromRaw('PENDING', isReceived: true);
      expect(label, equals('Awaiting your response'));
    });

    test('returns correct label for ACCEPTED_AWAITING_FINALIZATION cash', () {
      final (label, _) = getOfferStatusDisplayFromRaw(
        'ACCEPTED_AWAITING_FINALIZATION',
        isCashOffer: true,
      );
      expect(label, equals('Accepted – finalize'));
    });

    test('returns Pending for PENDING sent', () {
      final (label, _) =
          getOfferStatusDisplayFromRaw('PENDING', isReceived: false);
      expect(label, equals('Pending'));
    });
  });
}
