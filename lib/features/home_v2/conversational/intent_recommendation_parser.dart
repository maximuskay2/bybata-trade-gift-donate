import 'intent_module.dart';

/// Keyword entry for a navigable app surface.
class _IntentKeyword {
  final IntentModule module;
  final String keyword;
  final int priority;

  const _IntentKeyword(
    this.module,
    this.keyword, {
    this.priority = 10,
  });
}

/// Real-time keyword parser for the conversational command bar.
class IntentRecommendationParser {
  IntentRecommendationParser._();

  static const int _maxSuggestions = 8;

  /// Ordered catalog — earlier / lower priority values win ties.
  static const List<_IntentKeyword> _catalog = [
    // Core modules
    _IntentKeyword(IntentModule.trade, 'trade', priority: 1),
    _IntentKeyword(IntentModule.trade, 'swap', priority: 2),
    _IntentKeyword(IntentModule.trade, 'exchange', priority: 2),
    _IntentKeyword(IntentModule.trade, 'barter', priority: 2),
    _IntentKeyword(IntentModule.trade, 'offer', priority: 3),
    _IntentKeyword(IntentModule.trade, 'listing', priority: 3),
    _IntentKeyword(IntentModule.trade, 'sell', priority: 4),

    _IntentKeyword(IntentModule.gift, 'gift', priority: 1),
    _IntentKeyword(IntentModule.gift, 'give', priority: 2),
    _IntentKeyword(IntentModule.gift, 'free', priority: 3),
    _IntentKeyword(IntentModule.gift, 'share', priority: 4),
    _IntentKeyword(IntentModule.gift, 'pass on', priority: 4),

    _IntentKeyword(IntentModule.donation, 'donate', priority: 1),
    _IntentKeyword(IntentModule.donation, 'donation', priority: 1),
    _IntentKeyword(IntentModule.donation, 'campaign', priority: 2),
    _IntentKeyword(IntentModule.donation, 'fund', priority: 3),
    _IntentKeyword(IntentModule.donation, 'charity', priority: 3),
    _IntentKeyword(IntentModule.donation, 'crowdfund', priority: 3),
    _IntentKeyword(IntentModule.donation, 'raise', priority: 4),
    _IntentKeyword(IntentModule.donation, 'help', priority: 5),

    _IntentKeyword(IntentModule.wallet, 'wallet', priority: 1),
    _IntentKeyword(IntentModule.wallet, 'balance', priority: 2),
    _IntentKeyword(IntentModule.wallet, 'byc', priority: 2),
    _IntentKeyword(IntentModule.wallet, 'coin', priority: 3),
    _IntentKeyword(IntentModule.wallet, 'money', priority: 4),
    _IntentKeyword(IntentModule.wallet, 'pay', priority: 4),
    _IntentKeyword(IntentModule.wallet, 'top up', priority: 3),
    _IntentKeyword(IntentModule.wallet, 'topup', priority: 3),
    _IntentKeyword(IntentModule.wallet, 'withdraw', priority: 3),
    _IntentKeyword(IntentModule.wallet, 'fund', priority: 5),

    _IntentKeyword(IntentModule.karma, 'karma', priority: 1),
    _IntentKeyword(IntentModule.karma, 'trust', priority: 2),
    _IntentKeyword(IntentModule.karma, 'reputation', priority: 3),
    _IntentKeyword(IntentModule.karma, 'leaderboard', priority: 2),
    _IntentKeyword(IntentModule.karma, 'achievement', priority: 3),
    _IntentKeyword(IntentModule.karma, 'achievements', priority: 3),
    _IntentKeyword(IntentModule.karma, 'points', priority: 4),
    _IntentKeyword(IntentModule.karma, 'level', priority: 5),
    _IntentKeyword(IntentModule.karma, 'earn', priority: 3),

    _IntentKeyword(IntentModule.settings, 'settings', priority: 1),
    _IntentKeyword(IntentModule.settings, 'setting', priority: 1),
    _IntentKeyword(IntentModule.settings, 'preferences', priority: 2),
    _IntentKeyword(IntentModule.settings, 'preference', priority: 2),
    _IntentKeyword(IntentModule.settings, 'config', priority: 3),
    _IntentKeyword(IntentModule.settings, 'privacy', priority: 3),
    _IntentKeyword(IntentModule.settings, 'security', priority: 3),
    _IntentKeyword(IntentModule.settings, 'account', priority: 4),

    _IntentKeyword(IntentModule.ads, 'ads', priority: 1),
    _IntentKeyword(IntentModule.ads, 'ad', priority: 1),
    _IntentKeyword(IntentModule.ads, 'advert', priority: 2),
    _IntentKeyword(IntentModule.ads, 'advertise', priority: 2),
    _IntentKeyword(IntentModule.ads, 'promotion', priority: 1),
    _IntentKeyword(IntentModule.ads, 'promotions', priority: 1),
    _IntentKeyword(IntentModule.ads, 'promote', priority: 2),
    _IntentKeyword(IntentModule.ads, 'boost', priority: 2),
    _IntentKeyword(IntentModule.ads, 'sponsored', priority: 3),
    _IntentKeyword(IntentModule.ads, 'promo', priority: 2),

    _IntentKeyword(IntentModule.profile, 'profile', priority: 1),
    _IntentKeyword(IntentModule.profile, 'my profile', priority: 1),
    _IntentKeyword(IntentModule.profile, 'avatar', priority: 3),
    _IntentKeyword(IntentModule.profile, 'bio', priority: 4),

    _IntentKeyword(IntentModule.community, 'community', priority: 1),
    _IntentKeyword(IntentModule.community, 'communities', priority: 1),
    _IntentKeyword(IntentModule.community, 'group', priority: 3),
    _IntentKeyword(IntentModule.community, 'forum', priority: 4),
    _IntentKeyword(IntentModule.community, 'hub', priority: 5),

    _IntentKeyword(IntentModule.messages, 'message', priority: 1),
    _IntentKeyword(IntentModule.messages, 'messages', priority: 1),
    _IntentKeyword(IntentModule.messages, 'chat', priority: 1),
    _IntentKeyword(IntentModule.messages, 'dm', priority: 2),
    _IntentKeyword(IntentModule.messages, 'inbox', priority: 3),
    _IntentKeyword(IntentModule.messages, 'talk', priority: 4),
    _IntentKeyword(IntentModule.messages, 'conversation', priority: 4),

    _IntentKeyword(IntentModule.notifications, 'notification', priority: 1),
    _IntentKeyword(IntentModule.notifications, 'notifications', priority: 1),
    _IntentKeyword(IntentModule.notifications, 'alert', priority: 3),
    _IntentKeyword(IntentModule.notifications, 'alerts', priority: 3),

    _IntentKeyword(IntentModule.discover, 'search', priority: 1),
    _IntentKeyword(IntentModule.discover, 'find', priority: 2),
    _IntentKeyword(IntentModule.discover, 'discover', priority: 1),
    _IntentKeyword(IntentModule.discover, 'explore', priority: 2),
    _IntentKeyword(IntentModule.discover, 'browse', priority: 3),

    _IntentKeyword(IntentModule.support, 'support', priority: 2),
    _IntentKeyword(IntentModule.support, 'help', priority: 3),
    _IntentKeyword(IntentModule.support, 'faq', priority: 4),
    _IntentKeyword(IntentModule.support, 'contact', priority: 4),
  ];

  /// Returns matched modules with browse + create pairs where applicable.
  static List<IntentSuggestion> parse(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return const [];

    final hits = <_MatchHit>[];
    for (final entry in _catalog) {
      if (_matches(query, entry.keyword)) {
        hits.add(_MatchHit(
          module: entry.module,
          keyword: entry.keyword,
          priority: entry.priority,
        ));
      }
    }

    if (hits.isEmpty) {
      if (query.length < 2) return const [];
      return [
        IntentSuggestion(
          module: IntentModule.discover,
          action: IntentAction.searchFeed,
          matchedKeyword: query,
        ),
        IntentSuggestion(
          module: IntentModule.discover,
          action: IntentAction.browse,
          matchedKeyword: 'search',
        ),
        IntentSuggestion(
          module: IntentModule.support,
          action: IntentAction.browse,
          matchedKeyword: 'help',
        ),
      ];
    }

    hits.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) return byPriority;
      return b.keyword.length.compareTo(a.keyword.length);
    });

    final seenModules = <IntentModule>{};
    final orderedModules = <IntentModule>[];
    for (final hit in hits) {
      if (seenModules.add(hit.module)) {
        orderedModules.add(hit.module);
      }
    }

    final results = <IntentSuggestion>[];
    for (final module in orderedModules) {
      final keyword = _bestKeywordForModule(module, hits);
      if (module.hasBrowseAndCreate) {
        results.add(IntentSuggestion(
          module: module,
          action: IntentAction.searchFeed,
          matchedKeyword: keyword,
        ));
        results.add(IntentSuggestion(
          module: module,
          action: IntentAction.browse,
          matchedKeyword: keyword,
        ));
        results.add(IntentSuggestion(
          module: module,
          action: IntentAction.create,
          matchedKeyword: keyword,
        ));
      } else if (module == IntentModule.discover) {
        results.add(IntentSuggestion(
          module: module,
          action: IntentAction.searchFeed,
          matchedKeyword: keyword,
        ));
        results.add(IntentSuggestion(
          module: module,
          action: IntentAction.browse,
          matchedKeyword: keyword,
        ));
      } else {
        results.add(IntentSuggestion(
          module: module,
          action: IntentAction.browse,
          matchedKeyword: keyword,
        ));
      }
      if (results.length >= _maxSuggestions) break;
    }

    return results.take(_maxSuggestions).toList();
  }

  static String _bestKeywordForModule(IntentModule module, List<_MatchHit> hits) {
    for (final hit in hits) {
      if (hit.module == module) return hit.keyword;
    }
    return '';
  }

  /// Matches full words, substrings, and partial typing (prefix of keyword).
  static bool _matches(String query, String keyword) {
    final q = query.toLowerCase();
    final k = keyword.toLowerCase();
    if (q.isEmpty || k.isEmpty) return false;

    if (q.contains(k)) return true;

    if (k.startsWith(q) && q.length >= 2) return true;

    final escaped = RegExp.escape(k);
    if (RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(q)) return true;

    return false;
  }
}

class _MatchHit {
  final IntentModule module;
  final String keyword;
  final int priority;

  const _MatchHit({
    required this.module,
    required this.keyword,
    required this.priority,
  });
}
