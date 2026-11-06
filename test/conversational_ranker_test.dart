import 'package:bybata/core/models/listing_media.dart';
import 'package:bybata/features/feed/models/social_listing_card_data.dart';
import 'package:bybata/features/home_v2/conversational/conversational_ranker.dart';
import 'package:bybata/features/home_v2/conversational/intent_module.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationalRanker', () {
    SocialListingCardData campaign({
      required String id,
      bool verified = false,
      double progress = 0.1,
      double? distanceKm,
    }) {
      return SocialListingCardData(
        id: id,
        module: SocialListingModule.donation,
        title: 'Local fundraiser $id',
        description: 'Help needed',
        ownerId: 'u1',
        ownerName: 'Neighbor',
        media: const ListingMediaFields(mediaKeys: []),
        progress: progress,
        isVerified: verified,
        raw: {if (distanceKm != null) 'distanceKm': distanceKm},
      );
    }

    SocialListingCardData trade(String id, {double? distanceKm}) {
      return SocialListingCardData(
        id: id,
        module: SocialListingModule.trade,
        title: 'Trade $id',
        description: 'Swap',
        ownerId: 'u2',
        ownerName: 'Trader',
        media: const ListingMediaFields(mediaKeys: ['img.jpg']),
        previewImageUrl: 'https://example.com/img.jpg',
        raw: {if (distanceKm != null) 'distanceKm': distanceKm},
      );
    }

    test('boosts verified urgent campaigns to hero slot', () {
      final ranked = ConversationalRanker.rankAndSize(
        items: [
          trade('t1', distanceKm: 1),
          campaign(id: 'c1', verified: true, progress: 0.1, distanceKm: 2),
        ],
        query: 'donate surgery',
        moduleBias: IntentModule.donation,
      );

      expect(ranked, isNotEmpty);
      final hero = ranked.firstWhere((e) => e.size == BentoTileSize.hero);
      expect(hero.data.module, SocialListingModule.donation);
      expect(hero.data.isVerified, isTrue);
    });

    test('hub weights pull the boosted hub ahead of a nearer listing', () {
      final ranked = ConversationalRanker.rankAndSize(
        items: [
          trade('near', distanceKm: 1),
          SocialListingCardData(
            id: 'gift',
            module: SocialListingModule.gift,
            title: 'Free desk',
            description: 'Hostel',
            ownerId: 'u3',
            ownerName: 'Giver',
            media: const ListingMediaFields(mediaKeys: ['desk.jpg']),
            previewImageUrl: 'https://example.com/desk.jpg',
            raw: const {'distanceKm': 30},
          ),
        ],
        query: 'dorm',
        hubWeights: const {
          IntentModule.gift: 200,
          IntentModule.trade: 10,
          IntentModule.donation: 10,
        },
      );

      expect(ranked.first.data.id, 'gift');
    });

    test('prefers nearer listings when scores tie', () {
      final ranked = ConversationalRanker.rankAndSize(
        items: [
          trade('far', distanceKm: 40),
          trade('near', distanceKm: 2),
        ],
        query: 'laptop',
        moduleBias: IntentModule.trade,
      );

      expect(ranked.first.data.id, 'near');
    });
  });
}
