import 'package:bybata/features/home_v2/conversational/intent_module.dart';
import 'package:bybata/features/home_v2/conversational/intent_recommendation_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntentRecommendationParser', () {
    test('item-like query prefers search feed', () {
      final results = IntentRecommendationParser.parse('laptop');
      expect(results, isNotEmpty);
      expect(
        results.any((s) => s.action == IntentAction.searchFeed),
        isTrue,
      );
    });

    test('module keyword offers search and hub browse', () {
      final results = IntentRecommendationParser.parse('donate');
      expect(
        results.any((s) =>
            s.module == IntentModule.donation &&
            s.action == IntentAction.searchFeed),
        isTrue,
      );
      expect(
        results.any((s) =>
            s.module == IntentModule.donation &&
            s.action == IntentAction.browse),
        isTrue,
      );
    });

    test('navigation-only keyword routes to browse', () {
      final results = IntentRecommendationParser.parse('wallet');
      expect(
        results.any((s) =>
            s.module == IntentModule.wallet &&
            s.action == IntentAction.browse),
        isTrue,
      );
    });

    test('empty query returns no suggestions', () {
      expect(IntentRecommendationParser.parse(''), isEmpty);
      expect(IntentRecommendationParser.parse('   '), isEmpty);
    });
  });
}
