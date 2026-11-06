import '../../feed/models/social_listing_card_data.dart';
import 'ask_understanding.dart';
import 'intent_module.dart';

/// Screens the assistant can send a user to. Wire names match the API's
/// `ASSISTANT_TARGETS`.
enum AssistantTarget {
  tradeBrowse('trade_browse', IntentModule.trade, IntentAction.browse),
  tradeCreate('trade_create', IntentModule.trade, IntentAction.create),
  giftBrowse('gift_browse', IntentModule.gift, IntentAction.browse),
  giftCreate('gift_create', IntentModule.gift, IntentAction.create),
  campaignBrowse('campaign_browse', IntentModule.donation, IntentAction.browse),
  campaignCreate('campaign_create', IntentModule.donation, IntentAction.create),
  wallet('wallet', IntentModule.wallet, IntentAction.browse),
  walletFund('wallet_fund', IntentModule.wallet, IntentAction.create),
  karma('karma', IntentModule.karma, IntentAction.browse),
  earnKarma('earn_karma', IntentModule.karma, IntentAction.create),
  community('community', IntentModule.community, IntentAction.browse),
  messages('messages', IntentModule.messages, IntentAction.browse),
  promotions('promotions', IntentModule.ads, IntentAction.browse),
  profile('profile', IntentModule.profile, IntentAction.browse),
  settings('settings', IntentModule.settings, IntentAction.browse),
  support('support', IntentModule.support, IntentAction.browse);

  final String wire;
  final IntentModule module;
  final IntentAction action;

  const AssistantTarget(this.wire, this.module, this.action);

  static AssistantTarget? fromWire(Object? value) {
    for (final target in values) {
      if (target.wire == value) return target;
    }
    return null;
  }

  IntentSuggestion get suggestion =>
      IntentSuggestion(module: module, action: action, matchedKeyword: wire);
}

class AssistantAction {
  final AssistantTarget target;
  final String label;

  const AssistantAction(this.target, this.label);
}

/// Advice shown above (or instead of) listings: what to do and where to go.
class AssistantGuidance {
  final String reply;
  final List<String> steps;
  final List<AssistantAction> actions;

  /// False when the query is a need or a how-to rather than a search for items.
  final bool showListings;

  /// True when the model wrote this; false for the on-device rules.
  final bool fromAi;

  /// Listings the reply points at, shown as tappable links under it.
  final List<SocialListingCardData> picks;

  /// True when a button opens a create screen (list, gift, or campaign).
  bool get encouragesCreate =>
      actions.any((action) => action.target.action == IntentAction.create);

  const AssistantGuidance({
    required this.reply,
    this.steps = const [],
    this.actions = const [],
    this.showListings = true,
    this.fromAi = false,
    this.picks = const [],
  });

  AssistantGuidance copyWith({
    String? reply,
    List<SocialListingCardData>? picks,
  }) {
    return AssistantGuidance(
      reply: reply ?? this.reply,
      steps: steps,
      actions: actions,
      showListings: showListings,
      fromAi: fromAi,
      picks: picks ?? this.picks,
    );
  }

  static AssistantGuidance? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final reply = raw['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) return null;
    final steps =
        (raw['steps'] as List?)
            ?.map((s) => s.toString().trim())
            .where((s) => s.isNotEmpty)
            .take(4)
            .toList() ??
        const <String>[];
    final actions = <AssistantAction>[];
    for (final item in (raw['actions'] as List?) ?? const []) {
      if (item is! Map) continue;
      final target = AssistantTarget.fromWire(item['target']);
      final label = item['label']?.toString().trim() ?? '';
      if (target == null || label.isEmpty) continue;
      if (actions.any((a) => a.target == target)) continue;
      actions.add(AssistantAction(target, label));
      if (actions.length >= 3) break;
    }
    return AssistantGuidance(
      reply: reply,
      steps: steps,
      actions: actions,
      showListings: raw['showListings'] != false,
      fromAi: true,
    );
  }
}

/// On-device guidance for common needs. Used while typing (the model never
/// runs per keystroke) and whenever the model is off, slow, or failed.
class AssistantRules {
  AssistantRules._();

  static final _moneyNeed = RegExp(
    r'\b(need|want|get|raise|looking for|help me|support me|borrow|loan)\b.*\b(money|cash|funds?|loan|fees?|tuition|rent|bills?|hospital|medical|surgery|treatment|capital)\b',
  );
  static final _moneyWord = RegExp(
    r'\b(money|cash|broke|loan|tuition|school fees?)\b',
  );
  static final _receiveSupport = RegExp(
    r'\b(get|receive|ask for|apply for|need)\b.*\b(donations?|sponsor(ship)?|sponsors?|funding)\b',
  );
  static final _school = RegExp(
    r'\b(school|university|uni|college|tuition|admission|resume|semester)\b',
  );
  static final _giveMoney = RegExp(r'\b(donate|contribute|support|sponsor)\b');
  static final _selfNeed = RegExp(
    r'\b(need|help me|support me|sponsor me|borrow|loan)\b',
  );
  static final _swap = RegExp(r'\b(exchange|swap|trade|barter|switch)\b');
  static final _giveAway = RegExp(
    r'\b(give ?away|giving away|give out|gift out|dash|gift|donate (my|some|these|those|old))\b',
  );
  static final _unused = RegExp(
    r"\b(not using|no longer (use|using|need)|(don'?t|do not|dont) (use|need|want)|unused|declutter|clear out|spare|lying around|outgrown)\b|\bi'?m not using\b|\bim not using\b",
  );
  static final _free = RegExp(r'\bfree\b');
  static final _wallet = RegExp(
    r'\b(wallet|balance|withdraw|top ?up|byc|coins?)\b',
  );
  static final _karma = RegExp(
    r'\b(karma|trust score|reputation|leaderboard)\b',
  );
  static final _howTo = RegExp(
    r'\b(how (do|can) i|how to|help|support|problem|issue|not working|contact)\b',
  );
  static final _question = RegExp(
    r'(\?|\b(how|what|why|when|where|which)\b|\b(can|could|should|would) (i|we|you)\b|\b(explain|advice|advise|suggest|recommend|difference)\b)',
  );
  static final _giftTopic = RegExp(r'\b(gifts?|gifting|giveaways?|claim)\b');
  static final _tradeTopic = RegExp(
    r'\b(trades?|trading|swaps?|barter|offers?|exchange)\b',
  );
  static final _donateTopic = RegExp(r'\b(donat\w*|campaigns?|fundrais\w*)\b');
  static final _sell = RegExp(r'\b(sell|selling)\b');
  static final _cashWord = RegExp(r'\b(cash|naira)\b|₦');
  static final _overview = RegExp(
    r'\b(how (does|do) (bybata|this app|the app) work|what (else )?can (i|we|you) do|what is bybata|how do i use (bybata|this app|the app)|what are my options)\b',
  );
  static final _myItem = RegExp(
    r'\bmy ([a-z0-9][a-z0-9 ]{1,30}?)(?: for | to |$|[,.!?])',
  );

  static AssistantGuidance? guide(String raw) {
    final q = raw.toLowerCase().trim();
    if (q.length < 3) return null;

    final asksForMoney = _moneyNeed.hasMatch(q) || _receiveSupport.hasMatch(q);
    final question = _question.hasMatch(q);

    if (_overview.hasMatch(q)) return _appOverview;

    if (question &&
        RegExp(r'\b(difference|vs|versus|between)\b').hasMatch(q) &&
        _giftTopic.hasMatch(q) &&
        _tradeTopic.hasMatch(q)) {
      return _giftVersusTrade;
    }

    // "Sell for cash" is a swap, not a campaign and not a loan.
    if (_sell.hasMatch(q)) {
      return _tradeGuidance(q, mentionsCash: true);
    }

    if (question &&
        _giftTopic.hasMatch(q) &&
        !_giveAway.hasMatch(q) &&
        !_swap.hasMatch(q) &&
        !asksForMoney) {
      return _giftHow;
    }

    if (question && _tradeTopic.hasMatch(q) && !asksForMoney) {
      if (_itemFrom(q) == null) return _tradeHow;
      return _tradeGuidance(q, mentionsCash: _cashWord.hasMatch(q));
    }

    if (question &&
        _donateTopic.hasMatch(q) &&
        !asksForMoney &&
        !_giveAway.hasMatch(q)) {
      return _donateHow;
    }

    final wantsToGive =
        _giveMoney.hasMatch(q) &&
        !_giveAway.hasMatch(q) &&
        !_receiveSupport.hasMatch(q) &&
        !_selfNeed.hasMatch(q);
    if (wantsToGive) {
      return const AssistantGuidance(
        reply:
            'Open a campaign and donate BYC from your wallet. You will see '
            'the story, the goal, and how close it is.',
        actions: [
          AssistantAction(AssistantTarget.campaignBrowse, 'Browse campaigns'),
        ],
      );
    }

    if (_school.hasMatch(q) &&
        (q.contains('back to school') ||
            _moneyNeed.hasMatch(q) ||
            RegExp(r'\b(need|want|go|help)\b').hasMatch(q))) {
      return const AssistantGuidance(
        reply:
            'You can raise your school fees with a campaign, and find free or '
            'swappable books, laptops and supplies.',
        steps: [
          'Tap Raise school fees',
          'Explain what the money is for and set a target',
          'Share your campaign so people can donate',
        ],
        actions: [
          AssistantAction(AssistantTarget.campaignCreate, 'Raise school fees'),
          AssistantAction(AssistantTarget.giftBrowse, 'Free school items'),
          AssistantAction(AssistantTarget.tradeBrowse, 'Swap for supplies'),
        ],
        showListings: false,
      );
    }

    if (asksForMoney || _moneyWord.hasMatch(q)) {
      return const AssistantGuidance(
        reply:
            'Bybata does not give loans or cash. Start a campaign, tell your '
            'story, and set a goal in BYC. People donate from their wallets.',
        steps: [
          'Tap Start a campaign',
          'Tell your story and add photos',
          'Set your target amount',
          'Share your campaign link',
        ],
        actions: [
          AssistantAction(AssistantTarget.campaignCreate, 'Start a campaign'),
          AssistantAction(AssistantTarget.campaignBrowse, 'See campaigns'),
        ],
        showListings: false,
      );
    }

    if (_swap.hasMatch(q)) {
      return _tradeGuidance(q, mentionsCash: _cashWord.hasMatch(q));
    }

    if (_giveAway.hasMatch(q)) {
      final item = _itemFrom(q);
      final label = item == null ? 'Give a gift' : 'Gift my $item';
      return AssistantGuidance(
        reply:
            'Post ${item == null ? 'it' : 'your $item'} as a gift. People '
            'nearby request it, and you approve one recipient.',
        steps: [
          'Tap $label',
          'Add photos and pickup details',
          'Pick someone from the requests',
        ],
        actions: [AssistantAction(AssistantTarget.giftCreate, label)],
        showListings: false,
      );
    }

    if (_unused.hasMatch(q)) {
      return const AssistantGuidance(
        reply:
            'Put things you no longer use to work. Give them away as gifts to '
            'people nearby, or swap them for something you need.',
        steps: [
          'Pick Give it away or Swap it',
          'Add photos and the condition',
          'Choose who gets it, or accept a swap offer',
        ],
        actions: [
          AssistantAction(AssistantTarget.giftCreate, 'Give it away'),
          AssistantAction(AssistantTarget.tradeCreate, 'Swap it'),
        ],
        showListings: false,
      );
    }

    if (_free.hasMatch(q)) {
      return const AssistantGuidance(
        reply: 'Here are free items near you. Tap one to request it.',
        actions: [
          AssistantAction(AssistantTarget.giftBrowse, 'More free items'),
        ],
      );
    }

    if (_wallet.hasMatch(q)) {
      return const AssistantGuidance(
        reply:
            'Your BYC balance, top-ups and withdrawals are all in your wallet.',
        actions: [
          AssistantAction(AssistantTarget.wallet, 'Open wallet'),
          AssistantAction(AssistantTarget.walletFund, 'Add BYC'),
        ],
        showListings: false,
      );
    }

    if (_karma.hasMatch(q)) {
      return const AssistantGuidance(
        reply:
            'KARMA is your trust score. Complete trades, gifts and donations '
            'to earn more.',
        actions: [
          AssistantAction(AssistantTarget.karma, 'View KARMA'),
          AssistantAction(AssistantTarget.earnKarma, 'Ways to earn'),
        ],
        showListings: false,
      );
    }

    if (_howTo.hasMatch(q)) {
      return const AssistantGuidance(
        reply:
            'Our help centre has answers to common questions, and you can '
            'contact support from there.',
        actions: [AssistantAction(AssistantTarget.support, 'Help & Support')],
        showListings: false,
      );
    }

    return null;
  }

  /// Answer for "i want to swap", "i want to donate", "what else can i do":
  /// say what they can do and link the newest listings. [picks] is null while
  /// they load and empty when there are none.
  static AssistantGuidance forHub(
    AskUnderstanding ask, {
    List<SocialListingCardData>? picks,
  }) {
    final none = picks != null && picks.isEmpty;
    if (ask.kind == AskKind.overview) {
      return AssistantGuidance(
        reply: none
            ? 'On Bybata you can pick up free gifts, swap things you have for '
                  'things you need, or donate to someone\'s campaign. Tell me '
                  'what you are after and I will point you to it.'
            : 'On Bybata you can pick up free gifts, swap things you have for '
                  'things you need, or donate to someone\'s campaign. Here is '
                  'something fresh from each. Or just tell me what you need.',
        actions: const [
          AssistantAction(AssistantTarget.giftBrowse, 'Browse gifts'),
          AssistantAction(AssistantTarget.tradeBrowse, 'Browse trades'),
          AssistantAction(AssistantTarget.campaignBrowse, 'Browse campaigns'),
        ],
        showListings: false,
        picks: picks ?? const [],
      );
    }
    switch (ask.hub) {
      case IntentModule.donation:
        return AssistantGuidance(
          reply: none
              ? 'That is kind of you. There are no open campaigns right now, '
                    'so check back soon. You donate BYC straight from your wallet.'
              : 'That is kind of you. You can donate BYC from your wallet to '
                    'any campaign. Here are the latest ones. Tap one to read the '
                    'story and give.',
          actions: const [
            AssistantAction(AssistantTarget.campaignBrowse, 'All campaigns'),
            AssistantAction(AssistantTarget.walletFund, 'Add BYC'),
          ],
          showListings: false,
          picks: picks ?? const [],
        );
      case IntentModule.gift:
        return AssistantGuidance(
          reply: none
              ? 'No free gifts are up right now. They come and go quickly, so '
                    'check back soon, or give something away yourself.'
              : 'Here are the newest free gifts. Tap one to request it, and '
                    'the giver picks who receives it.',
          actions: const [
            AssistantAction(AssistantTarget.giftBrowse, 'All gifts'),
            AssistantAction(AssistantTarget.giftCreate, 'Give a gift'),
          ],
          showListings: false,
          picks: picks ?? const [],
        );
      default:
        return AssistantGuidance(
          reply: none
              ? 'Happy to help you swap. Nothing is listed for trade right now, '
                    'so list something of yours and say what you want back.'
              : 'Happy to help you swap. Here are the newest trades. Tap one to '
                    'see what they want back, or list something of yours.',
          actions: const [
            AssistantAction(AssistantTarget.tradeCreate, 'List a trade'),
            AssistantAction(AssistantTarget.tradeBrowse, 'All trades'),
          ],
          showListings: false,
          picks: picks ?? const [],
        );
    }
  }

  /// "i need a car" found something: say where, so the listings below read
  /// as an answer.
  static AssistantGuidance forFound(
    String item,
    List<SocialListingCardData> found, {
    AssistantGuidance? base,
  }) {
    final trades = found
        .where((e) => e.module == SocialListingModule.trade)
        .length;
    final gifts = found
        .where((e) => e.module == SocialListingModule.gift)
        .length;
    final campaigns = found
        .where((e) => e.module == SocialListingModule.donation)
        .length;
    final parts = [
      if (trades > 0) '$trades in trades',
      if (gifts > 0) '$gifts free in gifts',
      if (campaigns > 0) '$campaigns in campaigns',
    ];
    final where = parts.length <= 1
        ? (parts.isEmpty ? '' : ', ${parts.first}')
        : ': ${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    final count = found.length;
    final noun = count == 1 ? 'match' : 'matches';
    final next = trades > 0 && gifts == 0
        ? 'Tap one to see what they want in return.'
        : gifts > 0
        ? 'Tap one to request it or make an offer.'
        : 'Tap one to take a look.';
    final reply = 'Yes, I found $count $noun for $item$where. $next';
    if (base != null) return base.copyWith(reply: reply);
    return AssistantGuidance(
      reply: reply,
      actions: [
        if (trades > 0)
          const AssistantAction(AssistantTarget.tradeBrowse, 'More trades'),
        if (gifts > 0)
          const AssistantAction(AssistantTarget.giftBrowse, 'More gifts'),
        if (campaigns > 0)
          const AssistantAction(
            AssistantTarget.campaignBrowse,
            'More campaigns',
          ),
      ],
    );
  }

  static const _appOverview = AssistantGuidance(
    reply:
        'Bybata does three things. Request or give free gifts, swap items in '
        'a trade, or support a campaign with BYC. Ask about any of them and '
        'I will walk you through it.',
    actions: [
      AssistantAction(AssistantTarget.giftBrowse, 'Browse gifts'),
      AssistantAction(AssistantTarget.tradeBrowse, 'Browse trades'),
      AssistantAction(AssistantTarget.campaignBrowse, 'Browse campaigns'),
    ],
    showListings: false,
  );

  static const _giftVersusTrade = AssistantGuidance(
    reply:
        'A gift is free, and the giver chooses who receives it. A trade is a '
        'swap: you offer one of your listings and negotiate until both sides '
        'accept. Neither one is a cash sale.',
    actions: [
      AssistantAction(AssistantTarget.giftBrowse, 'Browse gifts'),
      AssistantAction(AssistantTarget.tradeBrowse, 'Browse trades'),
    ],
    showListings: false,
  );

  static const _giftHow = AssistantGuidance(
    reply:
        'A gift is free. Request it with a short note and the giver approves '
        'one person, then you arrange pickup in chat. You can only have one '
        'request waiting, and you need to be signed in.',
    steps: [
      'Open a gift',
      'Request it and add a note',
      'Wait for the giver to approve',
      'Arrange pickup in chat',
    ],
    actions: [
      AssistantAction(AssistantTarget.giftBrowse, 'Browse gifts'),
      AssistantAction(AssistantTarget.giftCreate, 'Give a gift'),
    ],
    showListings: false,
  );

  static const _tradeHow = AssistantGuidance(
    reply:
        'A trade is a swap, not a cash sale. List what you have and what you '
        'want back. People offer one of their listings, you can counter in '
        'chat, and accepting closes the deal.',
    steps: [
      'Tap List a trade',
      'Add photos, condition, and what you want',
      'Review offers in the trade chat',
    ],
    actions: [
      AssistantAction(AssistantTarget.tradeCreate, 'List a trade'),
      AssistantAction(AssistantTarget.tradeBrowse, 'Browse trades'),
    ],
    showListings: false,
  );

  static const _donateHow = AssistantGuidance(
    reply:
        'Open a campaign and donate BYC from your wallet. Add BYC first if '
        'your balance is low. To raise money yourself, start a campaign with '
        'your story and a goal.',
    steps: [
      'Open a campaign',
      'Choose an amount in BYC',
      'Confirm the donation',
    ],
    actions: [
      AssistantAction(AssistantTarget.campaignBrowse, 'Browse campaigns'),
      AssistantAction(AssistantTarget.walletFund, 'Add BYC'),
      AssistantAction(AssistantTarget.campaignCreate, 'Start a campaign'),
    ],
    showListings: false,
  );

  static AssistantGuidance _tradeGuidance(
    String q, {
    required bool mentionsCash,
  }) {
    final item = _itemFrom(q);
    final name = item ?? 'item';
    final cash = mentionsCash ? 'Bybata does not buy items for cash. ' : '';
    return AssistantGuidance(
      reply:
          '${cash}List your $name as a trade and say what you want in return. '
          'People send swap offers, and you negotiate in the trade chat until '
          'you accept.',
      steps: [
        'Tap List my $name',
        'Add photos, condition, and what you want',
        'Review offers in the trade chat',
      ],
      actions: [
        AssistantAction(AssistantTarget.tradeCreate, 'List my $name'),
        const AssistantAction(AssistantTarget.tradeBrowse, 'Browse trades'),
      ],
      showListings: item != null,
    );
  }

  /// No gifts, trades, or campaigns matched. Suggest creating the one their
  /// words already point at, and offer the other two as well.
  static AssistantGuidance forEmptyResults(
    String raw, {
    IntentModule? prefer,
    String? item,
  }) {
    final q = raw.toLowerCase().trim();
    final name = item ?? _subject(q);
    switch (_emptyTopic(q, prefer)) {
      case IntentModule.donation:
        return AssistantGuidance(
          reply: name == null
              ? 'No fundraiser matches that yet. You can start one and set a '
                    'goal in BYC, or have a look at what is open right now.'
              : 'No fundraiser for $name yet. You can start one and set a '
                    'goal in BYC, or have a look at what is open right now.',
          actions: const [
            AssistantAction(AssistantTarget.campaignCreate, 'Start a campaign'),
            ..._browseAll,
          ],
        );
      case IntentModule.gift:
        final giving = _giveAway.hasMatch(q) && name != null;
        return AssistantGuidance(
          reply: name == null
              ? 'No gifts match that yet. Here is what people are sharing and '
                    'swapping right now, or post a gift yourself.'
              : giving
              ? 'Nothing is listed for your $name yet. Post it as a gift '
                    'and you choose who receives it.'
                  : 'No $name to claim as a gift yet. Have a look at what is '
                      'available right now, or list a trade and ask for one in '
                      'return.',
          actions: [
            AssistantAction(
              AssistantTarget.giftCreate,
              giving ? 'Gift my $name' : 'Give a gift',
            ),
            ..._browseAll,
          ],
        );
      case IntentModule.trade:
        return AssistantGuidance(
          reply: name == null
              ? 'No swaps match that yet. Have a look at what is up for trade '
                    'right now, or list what you have and say what you want back.'
              : 'No swaps for $name yet. Have a look at what is available, or '
                    'list yours and say what you want in return.',
          actions: [
            AssistantAction(
              AssistantTarget.tradeCreate,
              name == null ? 'List a trade' : 'List my $name',
            ),
            ..._browseAll,
          ],
        );
      default:
        final what = name == null ? _quoted(raw) : 'any $name';
        return AssistantGuidance(
          reply:
              'I could not find $what on Bybata right now. Here is what is '
              'available instead. You can also list a trade and ask for one '
              'in return.',
          actions: const [
            ..._browseAll,
            AssistantAction(AssistantTarget.tradeCreate, 'List a trade'),
          ],
        );
    }
  }

  static const _browseAll = [
    AssistantAction(AssistantTarget.tradeBrowse, 'Browse trades'),
    AssistantAction(AssistantTarget.giftBrowse, 'Browse gifts'),
    AssistantAction(AssistantTarget.campaignBrowse, 'See campaigns'),
  ];

  static IntentModule _emptyTopic(String q, IntentModule? prefer) {
    const hubs = {IntentModule.gift, IntentModule.trade, IntentModule.donation};
    if (prefer != null && hubs.contains(prefer)) return prefer;
    final givingItem = _giveAway.hasMatch(q);
    final wantsMoney =
        !givingItem &&
        (_moneyNeed.hasMatch(q) ||
            _receiveSupport.hasMatch(q) ||
            _donateTopic.hasMatch(q) ||
            _moneyWord.hasMatch(q) ||
            (_school.hasMatch(q) && _selfNeed.hasMatch(q)));
    if (wantsMoney) return IntentModule.donation;
    if (givingItem ||
        _free.hasMatch(q) ||
        (_giftTopic.hasMatch(q) &&
            !_tradeTopic.hasMatch(q) &&
            !_swap.hasMatch(q))) {
      return IntentModule.gift;
    }
    if (_swap.hasMatch(q) || _sell.hasMatch(q) || _tradeTopic.hasMatch(q)) {
      return IntentModule.trade;
    }
    return IntentModule.discover;
  }

  static String? _subject(String q) {
    final mine = _itemFrom(q);
    if (mine != null) return mine;
    const noise = {
      'the',
      'and',
      'for',
      'with',
      'this',
      'that',
      'your',
      'from',
      'near',
      'some',
      'need',
      'want',
      'help',
      'you',
      'are',
      'was',
      'get',
      'how',
      'what',
      'can',
      'not',
      'just',
      'please',
      'looking',
      'around',
      'campus',
      'nearby',
      'local',
      'free',
      'gift',
      'gifts',
      'gifting',
      'trade',
      'trades',
      'swap',
      'swaps',
      'barter',
      'exchange',
      'donate',
      'donation',
      'campaign',
      'fundraiser',
      'item',
      'items',
      'stuff',
      'things',
      'something',
      'someone',
    };
    final words = q
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 3 && !noise.contains(word))
        .take(3)
        .toList();
    if (words.isEmpty) return null;
    return words.join(' ');
  }

  static String _quoted(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final short = text.length <= 42 ? text : '${text.substring(0, 42).trim()}…';
    return '“$short”';
  }

  static String? _itemFrom(String q) {
    final match = _myItem.firstMatch(q);
    final item = match?.group(1)?.trim();
    if (item == null || item.isEmpty) return null;
    final words = item.split(RegExp(r'\s+'));
    return words.take(3).join(' ');
  }
}
