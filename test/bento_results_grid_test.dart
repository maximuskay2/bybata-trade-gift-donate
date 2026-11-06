import 'package:bybata/core/models/listing_media.dart';
import 'package:bybata/features/feed/models/social_listing_card_data.dart';
import 'package:bybata/features/home_v2/conversational/conversational_feed_provider.dart';
import 'package:bybata/features/home_v2/conversational/conversational_ranker.dart';
import 'package:bybata/features/home_v2/conversational/widgets/bento_results_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SocialListingCardData trade(String id) {
    return SocialListingCardData(
      id: id,
      module: SocialListingModule.trade,
      title: 'Trade $id',
      description: 'Swap item',
      ownerId: 'u1',
      ownerName: 'Trader',
      media: const ListingMediaFields(mediaKeys: []),
    );
  }

  RankedFeedItem ranked(SocialListingCardData data) {
    return RankedFeedItem(
      data: data,
      size: BentoTileSize.standard,
      score: 1,
    );
  }

  Widget wrap(ConversationalFeedProvider feed) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BentoResultsGrid(feed: feed),
        ),
      ),
    );
  }

  group('BentoResultsGrid', () {
    testWidgets('shows empty state with zero items', (tester) async {
      final feed = ConversationalFeedProvider(isAuthed: false);
      await tester.pumpWidget(wrap(feed));
      expect(find.text('Nothing nearby yet'), findsOneWidget);
    });

    testWidgets('renders many trade cards in masonry grid', (tester) async {
      final feed = ConversationalFeedProvider(isAuthed: false)
        ..items = List.generate(
          5,
          (i) => ranked(trade('t$i')),
        );
      await tester.pumpWidget(wrap(feed));
      expect(find.text('Trade t0'), findsOneWidget);
      expect(find.text('Trade t4'), findsOneWidget);
    });

    testWidgets('shows section header when donation heroes present', (tester) async {
      final feed = ConversationalFeedProvider(isAuthed: false)
        ..donationHeroes = [
          ranked(
            SocialListingCardData(
              id: 'c1',
              module: SocialListingModule.donation,
              title: 'Help local school',
              description: 'Fundraiser',
              ownerId: 'u2',
              ownerName: 'Organizer',
              media: const ListingMediaFields(mediaKeys: []),
              progress: 0.2,
              isVerified: true,
            ),
          ),
        ];
      await tester.pumpWidget(wrap(feed));
      expect(find.text('Community fundraisers near you'), findsOneWidget);
      expect(find.text('Help local school'), findsOneWidget);
    });
  });
}
