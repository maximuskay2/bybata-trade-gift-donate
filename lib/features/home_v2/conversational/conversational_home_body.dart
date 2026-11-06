// Conversational home. A greeting, then a thread: the user's words, a plain
// answer, and listings. A follow-up keeps the earlier turns.
//
// While typing: a short answer and live item matches.
// On submit: keyword results first, then the AI intent layout when it arrives.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/accessibility/accessibility_utils.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../widgets/home_v2_tokens.dart';
import 'ask_understanding.dart';
import 'assistant_guidance.dart';
import 'conversational_analytics.dart';
import 'conversational_card_actions.dart';
import 'conversational_feed_provider.dart';
import 'conversational_typeahead_service.dart';
import 'intent_module.dart';
import 'intent_navigation.dart';
import 'widgets/assistant_guidance_card.dart';
import 'widgets/assistant_thinking.dart';
import 'widgets/bento_results_grid.dart';
import 'widgets/command_input_pill.dart';
import 'widgets/conversational_greeting.dart';
import 'widgets/conversational_item_suggestion_list.dart';
import 'widgets/intent_summary_chip.dart';

/// Gemini-style intent surface — greeting + typeahead suggestions, no inline feed.
class ConversationalHomeBody extends StatefulWidget {
  final bool isAuthed;

  /// Extra space above the bottom edge (e.g. floating nav on authenticated home).
  final double bottomReserve;

  const ConversationalHomeBody({
    super.key,
    required this.isAuthed,
    this.bottomReserve = 16,
  });

  @override
  State<ConversationalHomeBody> createState() => _ConversationalHomeBodyState();
}

class _ConversationalHomeBodyState extends State<ConversationalHomeBody> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _threadScroll = ScrollController();
  final ConversationalTypeaheadService _typeahead =
      ConversationalTypeaheadService();

  List<SocialListingCardData> _itemSuggestions = const [];
  bool _itemSuggestionsLoading = false;
  AssistantGuidance? _typingGuidance;

  /// Hides the typeahead once its query has been turned into results.
  String? _submittedQuery;
  Timer? _typeaheadDebounce;
  late final ConversationalFeedProvider _feed;
  String? _announcedIntent;
  String? _announcedReply;

  double get _focusProgress {
    if (_focusNode.hasFocus) return 1.0;
    if (_controller.text.trim().isNotEmpty) return 0.5;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _feed = ConversationalFeedProvider(isAuthed: widget.isAuthed);
    _feed.addListener(_announceIntent);
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() => setState(() {}));
  }

  void _announceIntent() {
    final reply = _feed.assistant?.reply;
    if (reply != null && reply != _announcedReply) {
      _announcedReply = reply;
      AccessibilityUtils.announce(reply);
    }
    final line = _feed.aiSummaryLine;
    if (line == null || line == _announcedIntent) return;
    _announcedIntent = line;
    AccessibilityUtils.announce('$line. ${_feed.totalCount} results');
  }

  @override
  void dispose() {
    _typeaheadDebounce?.cancel();
    _typeahead.cancel();
    _threadScroll.dispose();
    _feed.removeListener(_announceIntent);
    _feed.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text;
    _typeaheadDebounce?.cancel();
    final trimmed = query.trim();
    final ask = AskUnderstanding.parse(trimmed);
    _typingGuidance = AssistantRules.guide(trimmed);
    final searchable = ask.kind == AskKind.item || ask.kind == AskKind.other;
    if (trimmed.length < 2 || !searchable) {
      _typeahead.cancel();
      setState(() {
        _itemSuggestions = const [];
        _itemSuggestionsLoading = false;
      });
      return;
    }

    setState(() => _itemSuggestionsLoading = true);
    _typeaheadDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadItemSuggestions(trimmed, ask.item);
    });
  }

  Future<void> _loadItemSuggestions(String typed, String? item) async {
    final items = await _typeahead.fetchRelatedItems(
      query: item ?? typed,
      isAuthed: widget.isAuthed,
      minimum: 3,
      limit: 5,
    );
    if (!mounted || _controller.text.trim() != typed) return;
    setState(() {
      _itemSuggestions = items;
      _itemSuggestionsLoading = false;
      final current = _typingGuidance;
      final keepAnswer =
          current != null &&
          (current.encouragesCreate || !current.showListings);
      if (items.isEmpty && !keepAnswer) {
        _typingGuidance = AssistantRules.forEmptyResults(typed, item: item);
      }
    });
  }

  void _openSearchForQuery(String query, {IntentModule? module}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _focusNode.unfocus();
    ConversationalAnalytics.searchSubmitted(trimmed);
    IntentNavigation.openSearchWithQuery(
      context,
      query: trimmed,
      module: module,
    );
  }

  void _submitIntent() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    _focusNode.unfocus();
    ConversationalAnalytics.searchSubmitted(query);
    _controller.clear();
    setState(() => _submittedQuery = null);
    _feed.ask(query);
    _scrollThreadToEnd();
  }

  void _fillPrompt(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  void _scrollThreadToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_threadScroll.hasClients) return;
      _threadScroll.animateTo(
        _threadScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onItemSuggestionTap(SocialListingCardData item) {
    _focusNode.unfocus();
    ConversationalAnalytics.resultTap(
      module: item.module.name,
      listingId: item.id,
    );
    ConversationalCardActions.openDetail(context, item);
  }

  void _onAssistantAction(AssistantTarget target) {
    _focusNode.unfocus();
    IntentNavigation.go(context, target.suggestion);
  }

  void _clearSearch() {
    _announcedIntent = null;
    _announcedReply = null;
    _controller.clear();
    _feed.clearIntent();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final query = _controller.text.trim();
    final hasInput = query.isNotEmpty;
    final guidance = hasInput ? _typingGuidance : null;
    final showItemSection =
        hasInput &&
        (guidance?.showListings ?? true) &&
        (_itemSuggestionsLoading || _itemSuggestions.isNotEmpty);
    final showSuggestionsPanel =
        (showItemSection || guidance != null) && query != _submittedQuery;
    final pillBottom = keyboard > 0
        ? keyboard + 12
        : widget.bottomReserve + safeBottom;

    return GestureDetector(
      onTap: () {
        if (_focusNode.hasFocus) _focusNode.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _GeminiBackground(isDark: isDark),
          Column(
            children: [
              Expanded(child: _buildWelcome(context)),
              if (showSuggestionsPanel)
                Padding(
                  padding: const EdgeInsets.only(
                    left: HomeV2Tokens.kHorizontalPad,
                    right: HomeV2Tokens.kHorizontalPad,
                    bottom: 8,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (guidance != null) ...[
                            AssistantGuidanceCard(
                              guidance: guidance,
                              onAction: _onAssistantAction,
                              compact: true,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showItemSection) ...[
                            ConversationalItemSuggestionList(
                              items: _itemSuggestions,
                              isLoading: _itemSuggestionsLoading,
                              query: query,
                              onItemTap: _onItemSuggestionTap,
                              onSeeAllTap: _itemSuggestions.length >= 3
                                  ? () => _openSearchForQuery(query)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: pillBottom),
                child: CommandInputPill(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _submitIntent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return ListenableBuilder(
      listenable: _feed,
      builder: (context, _) {
        final query = _feed.activeQuery;
        final inThread =
            _feed.history.isNotEmpty || (query != null && query.isNotEmpty);
        if (inThread) return _buildResults(context);
        return _buildGreeting(context);
      },
    );
  }

  Widget _buildResults(BuildContext context) {
    final query = _feed.activeQuery ?? '';
    final thinking =
        query.isNotEmpty &&
        ((_feed.items.isEmpty && _feed.isLoading) ||
            _feed.intentPending ||
            _feed.loadingPicks);
    final guidance = _feed.assistant;
    final showListings = _feed.showListings;
    final showSummaryChip = showListings && _feed.aiSummaryLine != null;
    return ListView(
      controller: _threadScroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        HomeV2Tokens.kHorizontalPad,
        12,
        HomeV2Tokens.kHorizontalPad,
        24,
      ),
      children: [
        for (final turn in _feed.history) ...[
          _UserBubble(text: turn.query),
          const SizedBox(height: 12),
          if (turn.assistant != null) ...[
            AssistantGuidanceCard(
              guidance: turn.assistant!,
              onAction: _onAssistantAction,
              onOpenListing: _onItemSuggestionTap,
            ),
            const SizedBox(height: 8),
          ],
          if (turn.showListings && turn.listings.isNotEmpty)
            _PastListings(
              items: turn.listings,
              onOpen: (item) =>
                  ConversationalCardActions.openDetail(context, item),
            ),
          const SizedBox(height: 28),
        ],
        if (query.isNotEmpty) ...[
          _UserBubble(text: query, onClear: _clearSearch),
          const SizedBox(height: 12),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: thinking
              ? const Padding(
                  key: ValueKey('thinking'),
                  padding: EdgeInsets.only(top: 4, bottom: 12),
                  child: AssistantThinking(),
                )
              : Column(
                  key: ValueKey('answer_$query'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (guidance != null) ...[
                      AssistantGuidanceCard(
                        guidance: guidance,
                        onAction: _onAssistantAction,
                        onOpenListing: _onItemSuggestionTap,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!showListings) ...[
                      if (_feed.canShowListingsAnyway)
                        Center(
                          child: TextButton.icon(
                            onPressed: _feed.showListingsAnyway,
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: Text('Show listings for “$query”'),
                          ),
                        ),
                    ] else
                      ..._buildListings(query, showSummaryChip),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _buildListings(String query, bool showSummaryChip) {
    return [
      if (showSummaryChip) ...[
        IntentSummaryChip(
          label: _feed.aiSummaryLine!,
          resultCount: _feed.totalCount,
          onClear: _clearSearch,
        ),
        const SizedBox(height: 12),
      ],
      if (_feed.intentCategories.isNotEmpty) ...[
        IntentRefinementChips(
          categories: _feed.intentCategories,
          selected: _feed.selectedCategory,
          onSelected: _feed.refineCategory,
        ),
        const SizedBox(height: 12),
      ],
      if (_feed.showModuleHints) ...[
        IntentModuleHints(
          onTrades: () =>
              _feed.search(query, moduleBias: IntentModule.trade, skipAi: true),
          onGifts: () =>
              _feed.search(query, moduleBias: IntentModule.gift, skipAi: true),
          onFundraisers: () => _feed.search(
            query,
            moduleBias: IntentModule.donation,
            skipAi: true,
          ),
        ),
        const SizedBox(height: 12),
      ],
      BentoResultsGrid(feed: _feed, onLoadMore: _feed.loadMore),
    ];
  }

  Widget _buildGreeting(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HomeV2Tokens.kHorizontalPad,
                16,
                HomeV2Tokens.kHorizontalPad,
                24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: constraints.maxHeight * 0.08),
                  ConversationalGreeting(
                    isAuthed: widget.isAuthed,
                    focusProgress: _focusProgress,
                    hidden: _controller.text.trim().isNotEmpty,
                    onFill: _fillPrompt,
                  ),
                  SizedBox(height: constraints.maxHeight * 0.06),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  final VoidCallback? onClear;

  const _UserBubble({required this.text, this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Clear conversation',
              onPressed: onClear,
              icon: Icon(
                Icons.close,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _PastListings extends StatelessWidget {
  final List<SocialListingCardData> items;
  final ValueChanged<SocialListingCardData> onOpen;

  const _PastListings({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final shown = items.take(4).toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final item in shown)
          InkWell(
            onTap: () => onOpen(item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _moduleIcon(item.module),
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _moduleLabel(item.module),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  IconData _moduleIcon(SocialListingModule module) {
    switch (module) {
      case SocialListingModule.trade:
        return Icons.swap_horiz_rounded;
      case SocialListingModule.gift:
        return Icons.card_giftcard_rounded;
      case SocialListingModule.donation:
        return Icons.volunteer_activism_rounded;
    }
  }

  String _moduleLabel(SocialListingModule module) {
    switch (module) {
      case SocialListingModule.trade:
        return 'Trade';
      case SocialListingModule.gift:
        return 'Gift';
      case SocialListingModule.donation:
        return 'Donation';
    }
  }
}

class _GeminiBackground extends StatelessWidget {
  final bool isDark;

  const _GeminiBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0E0E10), Color(0xFF121216), Color(0xFF17161C)]
              : const [Color(0xFFFCFBFD), Color(0xFFF7F6F8), Color(0xFFF3F1F6)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
