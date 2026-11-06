import 'package:bybata/features/feed/mappers/social_listing_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromTradeMap reads hasUnreadMessages from API payload', () {
    final card = SocialListingMapper.fromTradeMap({
      'id': 'trade-1',
      'title': 'Laptop',
      'description': 'Swap',
      'hasUnreadMessages': true,
      'owner': {
        'id': 'u1',
        'profile': {'displayName': 'Alex'},
      },
    });

    expect(card.hasUnreadMessages, isTrue);
    expect(card.id, 'trade-1');
  });
}
