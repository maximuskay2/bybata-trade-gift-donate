import 'package:bybata/features/home_v2/conversational/intent_module.dart';
import 'package:bybata/features/home_v2/conversational/intent_recommendation_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntentRecommendationParser', () {
    test('returns empty list for blank input', () {
      expect(IntentRecommendationParser.parse(''), isEmpty);
      expect(IntentRecommendationParser.parse('   '), isEmpty);
    });

    test('matches core modules by exact keyword', () {
      final karma = _modules(IntentRecommendationParser.parse('karma'));
      expect(karma, contains(IntentModule.karma));

      final settings = _modules(IntentRecommendationParser.parse('settings'));
      expect(settings, contains(IntentModule.settings));

      final ads = _modules(IntentRecommendationParser.parse('ads'));
      expect(ads, contains(IntentModule.ads));
    });

    test('matches partial typing with at least two characters', () {
      final partial = _modules(IntentRecommendationParser.parse('karm'));
      expect(partial, contains(IntentModule.karma));

      expect(_modules(IntentRecommendationParser.parse('a')), isEmpty);
    });

    test('includes browse and create pairs for actionable modules', () {
      final results = IntentRecommendationParser.parse('trade');
      expect(
        results.where((s) => s.module == IntentModule.trade).length,
        2,
      );
      expect(
        results.any((s) =>
            s.module == IntentModule.trade &&
            s.action == IntentAction.browse),
        isTrue,
      );
      expect(
        results.any((s) =>
            s.module == IntentModule.trade &&
            s.action == IntentAction.create),
        isTrue,
      );
    });

    test('settings, profile, and support are browse-only', () {
      for (final query in ['settings', 'profile', 'support']) {
        final results = IntentRecommendationParser.parse(query);
        expect(results.every((s) => s.action == IntentAction.browse), isTrue);
      }
    });

    test('aliases map to the expected module', () {
      expect(
        _modules(IntentRecommendationParser.parse('promotion')),
        contains(IntentModule.ads),
      );
      expect(
        _modules(IntentRecommendationParser.parse('privacy')),
        contains(IntentModule.settings),
      );
      expect(
        _modules(IntentRecommendationParser.parse('leaderboard')),
        contains(IntentModule.karma),
      );
      expect(
        _modules(IntentRecommendationParser.parse('chat')),
        contains(IntentModule.messages),
      );
    });

    test('falls back to discover and support for unknown queries', () {
      final results = IntentRecommendationParser.parse('xyzabc');
      expect(results.length, 2);
      expect(results[0].module, IntentModule.discover);
      expect(results[1].module, IntentModule.support);
    });

    test('does not fallback for single unknown character', () {
      expect(IntentRecommendationParser.parse('z'), isEmpty);
    });

    test('deduplicates modules and caps suggestions', () {
      final results = IntentRecommendationParser.parse('trade swap gift');
      final modules = _modules(results);
      expect(modules.length, modules.toSet().length);
      expect(results.length, lessThanOrEqualTo(8));
    });
  });
}

Set<IntentModule> _modules(List<IntentSuggestion> suggestions) {
  return suggestions.map((s) => s.module).toSet();
}
