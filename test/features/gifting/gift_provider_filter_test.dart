import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bybata/core/api/api_client.dart' as core;
import 'package:bybata/features/gifting/providers/gift_provider.dart';
import 'package:bybata/features/gifting/api/gift_api.dart';

class _FakeGiftApi extends GiftApi {
  final List<Map<String, dynamic>> items;
  _FakeGiftApi(core.ApiClient client, this.items) : super(client);
  @override
  Future<Map<String, dynamic>> listGifts({
    String? query,
    String? category,
    String? type,
    String? status,
    String? giverId,
    String? location,
    int page = 1,
    int size = 20,
  }) async {
    return {'items': items};
  }
}

void main() {
  group('GiftProvider filtering', () {
    core.ApiClient _makeClient() => core.ApiClient('http://localhost', const FlutterSecureStorage());

    Map<String, dynamic> _gift({required String id, required String giverId}) => {
      'id': id,
      'title': 'Test Gift $id',
      'description': 'Desc $id',
      'giver': {
        'id': giverId,
        'email': 'user$id@example.com',
        'createdAt': '2024-01-01T00:00:00Z',
        'profile': {
          'displayName': 'User $id',
          'avatarKey': null,
          'kycStatus': 'VERIFIED',
        },
      },
      'type': 'random',
      'category': 'others',
      'status': 'active',
      'createdAt': '2024-02-01T00:00:00Z',
      'mediaKeys': [],
      'tags': [],
    };

    test('excludes gifts created by current user from available list', () async {
      final stubItems = [
        _gift(id: 'g1', giverId: 'user123'),
        _gift(id: 'g2', giverId: 'other999'),
        _gift(id: 'g3', giverId: 'user123'),
      ];
      final client = _makeClient();
      final provider = GiftProvider(client, giftApi: _FakeGiftApi(client, stubItems));
      provider.setExcludedUserId('user123');
      await provider.loadGifts();

      expect(provider.gifts.length, 1);
      expect(provider.gifts.first.giver.id, isNot('user123'));
    });

    test('does not filter when excluded user id is null', () async {
      final stubItems = [
        _gift(id: 'g1', giverId: 'user123'),
        _gift(id: 'g2', giverId: 'other999'),
      ];
      final client = _makeClient();
      final provider = GiftProvider(client, giftApi: _FakeGiftApi(client, stubItems));
      provider.setExcludedUserId(null);
      await provider.loadGifts();

      expect(provider.gifts.length, 2);
    });

    test('filtering preserves non-user gifts and sets no error', () async {
      final stubItems = [
        _gift(id: 'g1', giverId: 'user123'),
        _gift(id: 'g2', giverId: 'other999'),
        _gift(id: 'g3', giverId: 'other888'),
      ];
      final client = _makeClient();
      final provider = GiftProvider(client, giftApi: _FakeGiftApi(client, stubItems));
      provider.setExcludedUserId('user123');
      await provider.loadGifts();

      expect(provider.gifts.map((g) => g.giver.id).toSet(), {'other999', 'other888'});
      expect(provider.giftsError, isNull);
    });
  });
}