import 'package:bybata/core/models/listing_media.dart';
import 'package:bybata/features/feed/models/social_listing_card_data.dart';
import 'package:bybata/features/home_v2/conversational/bento_layout_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SocialListingCardData card(String id, SocialListingModule module) {
    return SocialListingCardData(
      id: id,
      module: module,
      title: id,
      description: id,
      ownerId: 'u',
      ownerName: 'Owner',
      media: const ListingMediaFields(mediaKeys: ['a.jpg']),
      previewImageUrl: 'https://example.com/a.jpg',
    );
  }

  Map<String, dynamic> interpret({
    required String primary,
    required String secondary,
    required String banner,
  }) {
    return {
      'query': 'dorm',
      'layout': {
        'primary': primary,
        'secondary': secondary,
        'banner': banner,
      },
      'hubs': {
        'gift': {'priority': primary == 'gift' ? 'high' : 'low'},
        'trade': {'priority': primary == 'trade' ? 'high' : 'medium'},
        'campaign': {'priority': primary == 'campaign' ? 'high' : 'low'},
      },
    };
  }

  test('free dorm setup leads with a gift hero', () {
    final ranked = BentoLayoutAdapter.adapt(
      interpret: interpret(primary: 'gift', secondary: 'trade', banner: 'campaign'),
      grouped: {
        'gift': [card('g1', SocialListingModule.gift), card('g2', SocialListingModule.gift)],
        'trade': [card('t1', SocialListingModule.trade)],
        'campaign': [card('c1', SocialListingModule.donation)],
      },
    );

    expect(ranked.first.data.id, 'g1');
    expect(ranked.first.size, BentoTileSize.hero);
    expect(ranked[1].data.module, SocialListingModule.gift);
    expect(ranked[1].size, BentoTileSize.standard);
    expect(ranked[2].data.module, SocialListingModule.trade);
    expect(ranked.last.data.module, SocialListingModule.donation);
    expect(ranked.last.size, BentoTileSize.hero);
  });

  test('swap leads with a trade hero', () {
    final ranked = BentoLayoutAdapter.adapt(
      interpret: interpret(primary: 'trade', secondary: 'gift', banner: 'campaign'),
      grouped: {
        'gift': [card('g1', SocialListingModule.gift)],
        'trade': [card('t1', SocialListingModule.trade)],
        'campaign': [card('c1', SocialListingModule.donation)],
      },
    );

    expect(ranked.first.data.module, SocialListingModule.trade);
    expect(ranked.first.size, BentoTileSize.hero);
  });

  test('school fees lead with a campaign hero', () {
    final ranked = BentoLayoutAdapter.adapt(
      interpret: interpret(primary: 'campaign', secondary: 'gift', banner: 'trade'),
      grouped: {
        'gift': [card('g1', SocialListingModule.gift)],
        'trade': [card('t1', SocialListingModule.trade)],
        'campaign': [card('c1', SocialListingModule.donation)],
      },
    );

    expect(ranked.first.data.module, SocialListingModule.donation);
    expect(ranked.first.size, BentoTileSize.hero);
  });
}
