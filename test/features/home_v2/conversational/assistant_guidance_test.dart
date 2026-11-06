import 'package:bybata/features/home_v2/conversational/assistant_guidance.dart';
import 'package:bybata/features/home_v2/conversational/intent_module.dart';
import 'package:flutter_test/flutter_test.dart';

List<AssistantTarget> _targets(AssistantGuidance? g) =>
    g?.actions.map((a) => a.target).toList() ?? const [];

void main() {
  group('AssistantRules', () {
    test('a money need points to starting a campaign and hides listings', () {
      for (final query in [
        'I need money',
        'can i get donation',
        'I need help with rent',
      ]) {
        final g = AssistantRules.guide(query);
        expect(
          _targets(g).first,
          AssistantTarget.campaignCreate,
          reason: query,
        );
        expect(g!.showListings, isFalse, reason: query);
        expect(g.steps, isNotEmpty, reason: query);
      }
    });

    test('going back to school offers fees, free items and swaps', () {
      final g = AssistantRules.guide('I need to go back to school');
      expect(_targets(g), [
        AssistantTarget.campaignCreate,
        AssistantTarget.giftBrowse,
        AssistantTarget.tradeBrowse,
      ]);
      expect(g!.showListings, isFalse);
    });

    test('exchanging an item names it and keeps listings', () {
      final g = AssistantRules.guide('i want to exchange my laptop');
      expect(_targets(g), [
        AssistantTarget.tradeCreate,
        AssistantTarget.tradeBrowse,
      ]);
      expect(g!.actions.first.label, 'List my laptop');
      expect(g.showListings, isTrue);
    });

    test(
      'wanting to give money browses campaigns instead of raising money',
      () {
        for (final query in [
          'I want to donate money',
          'support a medical fundraiser',
        ]) {
          final g = AssistantRules.guide(query);
          expect(_targets(g), [AssistantTarget.campaignBrowse], reason: query);
          expect(g!.showListings, isTrue, reason: query);
        }
      },
    );

    test('giving an item away names it and opens the gift form', () {
      for (final query in [
        'i want to gift out my trouser',
        'give away my trouser',
        'donate my trouser',
      ]) {
        final g = AssistantRules.guide(query);
        expect(_targets(g), [AssistantTarget.giftCreate], reason: query);
        expect(g!.actions.first.label, 'Gift my trouser', reason: query);
        expect(g.showListings, isFalse, reason: query);
      }
    });

    test('unused items offer giving away or swapping', () {
      for (final query in [
        'i have items im not using',
        "I have clothes I don't need anymore",
        'I want to declutter my room',
      ]) {
        final g = AssistantRules.guide(query);
        expect(_targets(g), [
          AssistantTarget.giftCreate,
          AssistantTarget.tradeCreate,
        ], reason: query);
        expect(g!.showListings, isFalse, reason: query);
      }
    });

    test('a question about gifts explains the request and approval', () {
      final g = AssistantRules.guide('how do gifts work');
      expect(_targets(g), [
        AssistantTarget.giftBrowse,
        AssistantTarget.giftCreate,
      ]);
      expect(g!.showListings, isFalse);
      expect(g.reply, contains('approves'));
      expect(g.steps, isNotEmpty);
    });

    test('selling for cash is a swap, not a campaign', () {
      final g = AssistantRules.guide('can I sell my phone for cash');
      expect(_targets(g), [
        AssistantTarget.tradeCreate,
        AssistantTarget.tradeBrowse,
      ]);
      expect(g!.actions.first.label, 'List my phone');
      expect(g.showListings, isTrue);
      expect(g.reply.toLowerCase(), contains('cash'));
    });

    test('how to donate explains BYC and does not show listings', () {
      final g = AssistantRules.guide('how do I donate');
      expect(_targets(g).first, AssistantTarget.campaignBrowse);
      expect(_targets(g), contains(AssistantTarget.walletFund));
      expect(g!.showListings, isFalse);
      expect(g.reply, contains('BYC'));
    });

    test('the difference between a gift and a trade stays on those hubs', () {
      final g = AssistantRules.guide(
        'what is the difference between a gift and a trade',
      );
      expect(_targets(g), [
        AssistantTarget.giftBrowse,
        AssistantTarget.tradeBrowse,
      ]);
      expect(g!.showListings, isFalse);
    });

    test('asking what Bybata does offers the three hubs', () {
      final g = AssistantRules.guide('how does bybata work');
      expect(_targets(g), [
        AssistantTarget.giftBrowse,
        AssistantTarget.tradeBrowse,
        AssistantTarget.campaignBrowse,
      ]);
      expect(g!.showListings, isFalse);
    });

    test('an empty result suggests creating what the query asked for', () {
      final gift = AssistantRules.forEmptyResults('free phone');
      expect(_targets(gift).first, AssistantTarget.giftCreate);
      expect(gift.reply.toLowerCase(), contains('gift'));

      final trade = AssistantRules.forEmptyResults('swap my fridge');
      expect(_targets(trade).first, AssistantTarget.tradeCreate);
      expect(trade.actions.first.label, 'List my fridge');

      final campaign = AssistantRules.forEmptyResults('I need help with rent');
      expect(_targets(campaign).first, AssistantTarget.campaignCreate);
      expect(campaign.showListings, isTrue);

      final plain = AssistantRules.forEmptyResults('desk');
      expect(_targets(plain), [
        AssistantTarget.tradeBrowse,
        AssistantTarget.giftBrowse,
        AssistantTarget.campaignBrowse,
        AssistantTarget.tradeCreate,
      ]);
    });

    test('a known hub still leads when the search found nothing', () {
      final gift = AssistantRules.forEmptyResults(
        'desk',
        prefer: IntentModule.gift,
      );
      expect(_targets(gift).first, AssistantTarget.giftCreate);
    });

    test('a plain item search gets no guidance', () {
      expect(AssistantRules.guide('desk'), isNull);
      expect(AssistantRules.guide('ps4 controller'), isNull);
    });
  });

  group('AssistantGuidance.fromJson', () {
    test('keeps known targets once and marks the guidance as AI', () {
      final g = AssistantGuidance.fromJson({
        'reply': ' Start a campaign. ',
        'steps': ['Tap Start', ''],
        'actions': [
          {'target': 'campaign_create', 'label': 'Start a campaign'},
          {'target': 'unknown_screen', 'label': 'Nope'},
          {'target': 'campaign_create', 'label': 'Again'},
        ],
        'showListings': false,
      });
      expect(g!.reply, 'Start a campaign.');
      expect(g.steps, ['Tap Start']);
      expect(_targets(g), [AssistantTarget.campaignCreate]);
      expect(g.showListings, isFalse);
      expect(g.fromAi, isTrue);
    });

    test('returns null without a reply', () {
      expect(AssistantGuidance.fromJson(null), isNull);
      expect(AssistantGuidance.fromJson({'reply': '  '}), isNull);
    });
  });
}
