import 'intent_module.dart';

enum AskKind {
  /// Looking for a thing: "i need a car" searches for `car`.
  item,

  /// Named a hub but no item: "i want to swap", "i want to donate".
  hub,

  /// Asked what Bybata can do: "what else can i do".
  overview,

  /// A question or need with nothing to search for.
  other,
}

/// Splits a home-screen sentence into what to search for and which hub it is
/// about, so conversational filler is never sent as a product name.
class AskUnderstanding {
  final AskKind kind;

  /// Keyword to search with. Null unless [kind] is [AskKind.item].
  final String? item;

  /// gift, trade or donation when the sentence names one.
  final IntentModule? hub;

  /// They want to give (donate money, give an item away) rather than receive.
  final bool giving;

  const AskUnderstanding({
    required this.kind,
    this.item,
    this.hub,
    this.giving = false,
  });

  /// Hub questions where the newest listings answer the question.
  bool get wantsLatestPicks {
    if (kind == AskKind.overview) return true;
    if (kind != AskKind.hub) return false;
    switch (hub) {
      case IntentModule.trade:
        return true;
      case IntentModule.gift:
        return !giving;
      case IntentModule.donation:
        return giving;
      default:
        return false;
    }
  }

  static final _overview = RegExp(
    r"\b(what (else )?can (i|we|you) do|what (else )?(do|does) (you|bybata|this app|the app) do|what (else )?is (there|bybata)|how (does|do) (bybata|this app|the app) work|how do i use (bybata|this app|the app)|what (else )?(can|could) i (try|use)|what are my options)\b",
  );

  static final _leadingFiller = <RegExp>[
    RegExp(
      r"^(please|pls|abeg|biko|hi|hello|hey|ok|okay|so|um|well|yes|and)\b[ ,]*",
    ),
    RegExp(
      r"^(i|we) (really |just |also |still )?(need|want|wanna|would like|'d like|d like|dey find|wan|am looking for|'m looking for|m looking for|am searching for)( to)?( (get|buy|have|find|see|browse|check out|look at))?\b ?",
    ),
    RegExp(r"^(i'?m|im) (looking|searching) for\b ?"),
    RegExp(r"^(looking|searching) for\b ?"),
    RegExp(
      r"^(can|could|may) (i|we|you) (please )?(get|find|have|see|show me|help me find|help me get)\b ?",
    ),
    RegExp(
      r"^(do|does) (you|anyone|anybody|someone|somebody) (have|has|get|got)\b ?",
    ),
    RegExp(r"^(is|are) there\b ?"),
    RegExp(
      r"^(anyone|anybody|someone|somebody|who) (have|has|get|got|with)\b ?",
    ),
    RegExp(r"^(where|how) (can|do|could) (i|we) (get|find|buy)\b ?"),
    RegExp(
      r"^(help me|show me|find me|get me|give me|send me)( (find|get|see))?\b ?",
    ),
  ];

  static final _fillerWords = RegExp(
    r"\b(a|an|the|some|any|one|me|please|pls|abeg|for me|near me|nearby|around me|around campus|on bybata|here|today|now|asap|urgently)\b",
  );

  static final _vague = {
    'something',
    'anything',
    'stuff',
    'things',
    'thing',
    'items',
    'item',
    'listings',
    'listing',
    'help',
    'it',
    'this',
    'that',
    'them',
    'more',
    'else',
    'something else',
    'other things',
    'new things',
  };

  static final _giveAway = RegExp(
    r"\b(give ?away|giving away|give out|gift out|gift my|donate my|donate (some|these|those|old)|dash)\b",
  );
  static final _giveMoney = RegExp(
    r"\b(donate|donating|contribute|support|sponsor|give to)\b",
  );
  static final _receiveMoney = RegExp(
    r"\b(need|get|receive|raise|start|create|ask for|apply for|open)\b.*\b(donations?|campaigns?|fundraisers?|funding|sponsors?)\b",
  );

  static final _selfNeed = RegExp(
    r"\b(need|help me|support me|sponsor me|for me|for my)\b",
  );

  static final _tradeWords = RegExp(
    r"\b(to )?(swap|swapping|swaps|trade|trading|trades|exchange|exchanging|barter|bartering|sell|selling)\b",
  );
  static final _giftWords = RegExp(
    r"\b(to )?(give ?away|giving away|give out|gift out|gifts?|gifting|giveaways?|free|for free|dash)\b",
  );
  static final _donationWords = RegExp(
    r"\b(to )?(donate|donating|donations?|campaigns?|fundraisers?|fundraising|charity|crowdfund\w*|contribute|support|sponsor)\b",
  );

  static final _question = RegExp(
    r"\b(how|what|why|when|which|explain|difference|work|works)\b",
  );

  static final _swapFor = RegExp(
    r"\b(?:swap|trade|exchange|barter)\b.*?\bmy ([a-z0-9 ]{2,30}?) for (?:a |an |some )?([a-z0-9 ]{2,30})$",
  );

  static AskUnderstanding parse(String raw) {
    var q = raw
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r"[?!.,;:]+"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty) return const AskUnderstanding(kind: AskKind.other);

    if (_overview.hasMatch(q)) {
      return const AskUnderstanding(kind: AskKind.overview);
    }

    final hub = _hubOf(q);
    final giving = hub == IntentModule.donation
        ? _giveMoney.hasMatch(q) &&
              !_receiveMoney.hasMatch(q) &&
              !_selfNeed.hasMatch(q)
        : _giveAway.hasMatch(q);

    final swapFor = _swapFor.firstMatch(q);
    if (swapFor != null) {
      final wanted = _clean(swapFor.group(2)!);
      if (wanted != null) {
        return AskUnderstanding(
          kind: AskKind.item,
          item: wanted,
          hub: IntentModule.trade,
        );
      }
    }

    var rest = q;
    var changed = true;
    while (changed) {
      changed = false;
      for (final filler in _leadingFiller) {
        final next = rest.replaceFirst(filler, '').trim();
        if (next != rest) {
          rest = next;
          changed = true;
        }
      }
    }

    if (_question.hasMatch(rest)) {
      return AskUnderstanding(kind: AskKind.other, hub: hub, giving: giving);
    }

    rest = rest
        .replaceAll(_tradeWords, ' ')
        .replaceAll(_giftWords, ' ')
        .replaceAll(_donationWords, ' ')
        .replaceAll(RegExp(r'\b(my|to|for|of|with|and|or|in|on)\b'), ' ');
    final item = _clean(rest);

    if (item == null) {
      return AskUnderstanding(
        kind: hub == null ? AskKind.other : AskKind.hub,
        hub: hub,
        giving: giving,
      );
    }
    return AskUnderstanding(
      kind: AskKind.item,
      item: item,
      hub: hub,
      giving: giving,
    );
  }

  static IntentModule? _hubOf(String q) {
    if (_giveAway.hasMatch(q)) return IntentModule.gift;
    if (_donationWords.hasMatch(q)) return IntentModule.donation;
    if (_tradeWords.hasMatch(q)) return IntentModule.trade;
    if (_giftWords.hasMatch(q)) return IntentModule.gift;
    return null;
  }

  static String? _clean(String text) {
    final words = text
        .replaceAll(_fillerWords, ' ')
        .replaceAll(RegExp(r"[^a-z0-9' ]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    final phrase = words.take(4).join(' ');
    if (phrase.length < 2 || _vague.contains(phrase)) return null;
    if (words.every(_vague.contains)) return null;
    return phrase;
  }
}
