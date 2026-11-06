import 'package:flutter_test/flutter_test.dart';
import 'package:bybata/features/trade/services/negotiation_service.dart';
import 'package:bybata/features/trade/models/trade_models.dart';
import 'package:bybata/core/api/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('NegotiationService - status and proposer logic', () {
    late NegotiationService service;

    setUp(() {
      // ApiClient is required by constructor but not used in these tests
      final apiClient = ApiClient('http://localhost', const FlutterSecureStorage());
      service = NegotiationService(apiClient);
    });

    TradeUser makeUser(String id) {
      return TradeUser(
        id: id,
        name: 'User $id',
        username: '@user$id',
        rating: 4.0,
        completedTrades: 0,
        joinedDate: DateTime.now().subtract(const Duration(days: 10)),
        isVerified: false,
      );
    }

    TradeMessage makeMsg({
      required String id,
      required String type,
      required String senderId,
    }) {
      return TradeMessage(
        id: id,
        tradeId: 'trade-1',
        offerId: 'offer-1',
        sender: makeUser(senderId),
        content: '$type message',
        createdAt: DateTime.now(),
        isRead: true,
        messageType: type,
      );
    }

    test('getNegotiationStatus returns initial for empty messages', () {
      expect(service.getNegotiationStatus([]), equals('initial'));
    });

    test('getNegotiationStatus returns pending for proposal and counterOffer', () {
      final msgs1 = [makeMsg(id: '1', type: 'proposal', senderId: 'u1')];
      final msgs2 = [makeMsg(id: '2', type: 'counterOffer', senderId: 'u2')];
      expect(service.getNegotiationStatus(msgs1), equals('pending'));
      expect(service.getNegotiationStatus(msgs2), equals('pending'));
    });

    test('getNegotiationStatus returns accepted and declined appropriately', () {
      final accepted = [makeMsg(id: '1', type: 'acceptance', senderId: 'u1')];
      final declined = [makeMsg(id: '2', type: 'decline', senderId: 'u2')];
      expect(service.getNegotiationStatus(accepted), equals('accepted'));
      expect(service.getNegotiationStatus(declined), equals('declined'));
    });

    test('getNegotiationStatus returns active for regular message', () {
      final msgs = [makeMsg(id: '1', type: 'regular', senderId: 'u1')];
      expect(service.getNegotiationStatus(msgs), equals('active'));
    });

    test('getLastProposer finds last proposal or counterOffer sender', () {
      final msgs = [
        makeMsg(id: '1', type: 'regular', senderId: 'u1'),
        makeMsg(id: '2', type: 'proposal', senderId: 'proposerA'),
        makeMsg(id: '3', type: 'regular', senderId: 'u2'),
        makeMsg(id: '4', type: 'counterOffer', senderId: 'proposerB'),
      ];
      expect(service.getLastProposer(msgs), equals('proposerB'));
    });

    test('getLastProposer returns null when no proposals exist', () {
      final msgs = [
        makeMsg(id: '1', type: 'regular', senderId: 'u1'),
        makeMsg(id: '2', type: 'regular', senderId: 'u2'),
      ];
      expect(service.getLastProposer(msgs), isNull);
    });
  });
}