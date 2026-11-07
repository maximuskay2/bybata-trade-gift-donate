import 'package:bybata/core/models/listing_media.dart';
import 'package:bybata/features/feed/models/social_listing_card_data.dart';
import 'package:bybata/features/feed/widgets/social_listing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SocialListingCardData tradeCard() {
    return SocialListingCardData(
      id: 't1',
      module: SocialListingModule.trade,
      title: 'Himalayan hood',
      description: 'Warm jacket',
      ownerId: 'owner-1',
      ownerName: 'Ada',
      media: const ListingMediaFields(mediaKeys: []),
      raw: {
        'interestedItems': ['canvas jacket', 'boots'],
        'estimatedValue': 850,
        'owner': {'rating': 4.6},
      },
    );
  }

  testWidgets('catalog card keeps like, message, share, and swap', (tester) async {
    var swapped = false;
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 340,
              child: SocialListingCard(
                data: tradeCard(),
                layout: SocialFeedLayout.catalog,
                onCardTap: () => opened = true,
                onPrimaryAction: () => swapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Himalayan hood'), findsOneWidget);
    expect(find.text('Wants canvas jacket +1'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.text('Swap'));
    await tester.pump();
    expect(swapped, isTrue);

    await tester.tap(find.byTooltip('Message'));
    await tester.pump();
    expect(opened, isTrue);

    expect(find.byTooltip('Share listing'), findsOneWidget);
  });

  testWidgets('catalog card fits a narrow phone cell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 139,
              height: 239,
              child: SocialListingCard(
                data: SocialListingCardData(
                  id: 't2',
                  module: SocialListingModule.trade,
                  title: 'A very long trade title that wraps onto two lines',
                  description: 'desc',
                  ownerId: 'owner-1',
                  ownerName: 'Ada',
                  media: const ListingMediaFields(mediaKeys: []),
                  raw: const {
                    'interestedItems': ['something people want back'],
                    'owner': {'rating': 4.8},
                  },
                ),
                layout: SocialFeedLayout.catalog,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog card uses category when a trade has no want or value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 340,
              child: SocialListingCard(
                data: SocialListingCardData(
                  id: 't3',
                  module: SocialListingModule.trade,
                  title: 'Denim jacket',
                  description: 'Light wash',
                  ownerId: 'owner-1',
                  ownerName: 'Ada',
                  distanceLabel: 'Uyo',
                  media: const ListingMediaFields(mediaKeys: []),
                  raw: const {'category': 'CLOTHING'},
                ),
                layout: SocialFeedLayout.catalog,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Clothing · Uyo'), findsOneWidget);
    expect(find.text('Open to swap'), findsNothing);
    expect(find.text('Swap'), findsOneWidget);
  });
}
