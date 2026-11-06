import 'package:bybata/core/models/listing_media.dart';
import 'package:bybata/features/feed/models/social_listing_card_data.dart';
import 'package:bybata/features/home_v2/conversational/ask_understanding.dart';
import 'package:bybata/features/home_v2/conversational/assistant_guidance.dart';
import 'package:bybata/features/home_v2/conversational/intent_module.dart';
import 'package:flutter_test/flutter_test.dart';

SocialListingCardData _card(String id, SocialListingModule module) {
  return SocialListingCardData(
    id: id,
    module: module,
    title: 'Listing $id',
    description: '',
    ownerId: 'o',
    ownerName: 'Owner',
    media: const ListingMediaFields(),
  );
}

void main() {
  group('AskUnderstanding', () {
    test('conversational filler is not part of the item', () {
      for (final entry in {
        'i need a car': 'car',
        'I need a car.': 'car',
        'i am looking for a laptop': 'laptop',
        "I'm looking for a fridge": 'fridge',
        'do you have a generator?': 'generator',
        'is there any bicycle': 'bicycle',
        'can i get a phone please': 'phone',
        'abeg i dey find shoes': 'shoes',
        'free desk near me': 'desk',
        'show me laptops': 'laptops',
      }.entries) {
        final ask = AskUnderstanding.parse(entry.key);
        expect(ask.kind, AskKind.item, reason: entry.key);
        expect(ask.item, entry.value, reason: entry.key);
      }
    });

    test('swap X for Y searches for what they want back', () {
      final ask = AskUnderstanding.parse(
        'i want to swap my phone for a laptop',
      );
      expect(ask.kind, AskKind.item);
      expect(ask.item, 'laptop');
      expect(ask.hub, IntentModule.trade);
    });

    test('a hub with no item is a hub question, not a product', () {
      final swap = AskUnderstanding.parse('i want to swap');
      expect(swap.kind, AskKind.hub);
      expect(swap.item, isNull);
      expect(swap.hub, IntentModule.trade);
      expect(swap.wantsLatestPicks, isTrue);

      final donate = AskUnderstanding.parse('I want to donate');
      expect(donate.kind, AskKind.hub);
      expect(donate.hub, IntentModule.donation);
      expect(donate.giving, isTrue);
      expect(donate.wantsLatestPicks, isTrue);

      final free = AskUnderstanding.parse('i want free stuff');
      expect(free.kind, AskKind.hub);
      expect(free.hub, IntentModule.gift);
      expect(free.wantsLatestPicks, isTrue);
    });

    test('asking for donations is not a request to donate', () {
      final ask = AskUnderstanding.parse('can i get donation');
      expect(ask.hub, IntentModule.donation);
      expect(ask.giving, isFalse);
      expect(ask.wantsLatestPicks, isFalse);
    });

    test('what else can i do is an overview', () {
      for (final q in [
        'what else can i do',
        'What can I do here?',
        'what are my options',
      ]) {
        final ask = AskUnderstanding.parse(q);
        expect(ask.kind, AskKind.overview, reason: q);
        expect(ask.item, isNull, reason: q);
        expect(ask.wantsLatestPicks, isTrue, reason: q);
      }
    });

    test('how-to questions are not item searches', () {
      for (final q in [
        'how do gifts work',
        'what is the difference between a gift and a trade',
      ]) {
        final ask = AskUnderstanding.parse(q);
        expect(ask.kind, AskKind.other, reason: q);
        expect(ask.item, isNull, reason: q);
      }
    });
  });

  group('AssistantRules conversational replies', () {
    test('donate answers with the latest campaigns as links', () {
      final picks = [
        _card('1', SocialListingModule.donation),
        _card('2', SocialListingModule.donation),
        _card('3', SocialListingModule.donation),
      ];
      final g = AssistantRules.forHub(
        AskUnderstanding.parse('i want to donate'),
        picks: picks,
      );
      expect(g.reply.toLowerCase(), contains('donate'));
      expect(g.picks, hasLength(3));
      expect(g.showListings, isFalse);
      expect(g.actions.first.target, AssistantTarget.campaignBrowse);
    });

    test('no open campaigns says so instead of pointing at nothing', () {
      final g = AssistantRules.forHub(
        AskUnderstanding.parse('i want to donate'),
        picks: const [],
      );
      expect(g.reply.toLowerCase(), contains('no open campaigns'));
    });

    test('found items say how many and where', () {
      final g = AssistantRules.forFound('car', [
        _card('1', SocialListingModule.trade),
        _card('2', SocialListingModule.trade),
        _card('3', SocialListingModule.gift),
      ]);
      expect(g.reply, contains('3 matches for car'));
      expect(g.reply, contains('2 in trades'));
      expect(g.reply, contains('1 free in gifts'));
    });

    test('no results names the item, not the whole sentence', () {
      final g = AssistantRules.forEmptyResults('i need a car', item: 'car');
      expect(g.reply, contains('any car'));
      expect(g.reply, isNot(contains('i need a car')));
    });

    test('what else can i do gets the overview', () {
      final g = AssistantRules.guide('what else can i do');
      expect(g, isNotNull);
      expect(g!.showListings, isFalse);
    });
  });
}
