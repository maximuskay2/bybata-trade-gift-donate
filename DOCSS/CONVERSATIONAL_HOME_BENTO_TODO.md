# Conversational Home + Bento Feed — Implementation TODO

Product goal: replace complex menus with a **bottom AI-style command bar** that searches trades, gifts, and **local verified fundraisers**, then renders results in a **3D Bento grid** on the home screen. All existing hubs and full search remain as **backup** entry points.

**Vision reference:** neighbors type what they need → proximity-ranked unified feed → tap card → negotiate / support / meet local.

**Already in codebase (reuse):**
- `ConversationalHomeBody`, `CommandInputPill`, `ConversationalGreeting` — `lib/features/home_v2/conversational/`
- `BentoQuickActionsPanel` — built but **not wired** into home idle state
- `IntentRecommendationParser` — keyword navigation to screens (not item search yet)
- `SearchApiService` + cascading liquidity geo search — `lib/features/search/services/search_api_service.dart`
- `SearchScreen` — full backup search with categories/filters
- `SocialListingCard` + `SocialListingCardData` — unified bento cards for trade/gift/donation
- Donations hub, campaign verification, chat, trade offers — existing flows

Work through phases in order. Each phase should be shippable independently.

---

## Phase 0 — Foundations & wiring

### 0.1 Home state machine
- [x] Define `ConversationalHomeMode` enum: `idle` | `typing` | `results` | `loading` | `error`
- [x] Refactor `ConversationalHomeBody` to switch body content by mode
- [x] Keep bottom `CommandInputPill` fixed; only scroll the content area above it
- [x] Preserve keyboard-safe padding (`resizeToAvoidBottomInset`, `MediaQuery.viewInsets`)

**Files:** `lib/features/home_v2/conversational/conversational_home_body.dart`

### 0.2 Wire idle Bento quick actions
- [x] Mount `BentoQuickActionsPanel` when mode is `idle` and query is empty
- [x] Show `ConversationalGreeting` above quick actions (reduce vertical centering when idle)
- [x] Verify tiles: Post Trade, Give Gift, Explore Marketplace, Wallet/Karma bar
- [x] Guest vs authed: hide/create-gated actions appropriately

**Files:** `conversational_home_body.dart`, `widgets/bento_quick_actions_panel.dart`

### 0.3 Backup navigation (do not remove hubs)
- [x] Add persistent **“Advanced search”** chip when typing → `SearchScreen`
- [x] Keep drawer routes: Trade Center, Gifting, Donations, Wallet, Messages
- [x] Keep `IntentNavigation.openExplore` → `DiscoverScreen` from Explore tile
- [x] Document escape hatches in code comment at top of `ConversationalHomeBody`

**Files:** `intent_navigation.dart`, `conversational_home_body.dart`, `app_side_drawer.dart`

---

## Phase 1 — Conversational search → Bento results feed

### 1.1 Feed provider (data layer)
- [x] Create `ConversationalFeedProvider` (or `ConversationalFeedController`)
- [x] Inject `SearchApiService` + user geo (reuse `SignupLocationService` / profile location cache — **no GPS on every keystroke**)
- [x] Method `search(String query)`:
  - [x] Call unified `search()` for mixed results (authed) or parallel public endpoints (guest)
  - [x] Pass `ListingGeoQuery` with cached lat/lng + default radius
- [x] Method `loadIdleFeed()` for empty query:
  - [x] Near-you trades/gifts via cascading liquidity
  - [x] Local verified campaigns via `listCampaignsWithCascadingLiquidity`
- [x] Map API payloads → `List<SocialListingCardData>` (reuse `social_listing_mapper.dart`)
- [x] Expose: `items`, `isLoading`, `error`, `radiusKmUsed`, `hasMore`, `loadMore()`

**Files (new):** `lib/features/home_v2/conversational/conversational_feed_provider.dart`  
**Reuse:** `lib/features/feed/mappers/social_listing_mapper.dart`, `lib/features/search/services/search_api_service.dart`

### 1.2 Submit flow from command bar
- [x] On submit (and debounced after 500ms when query length ≥ 2): call `feedProvider.search(query)`
- [x] Transition mode: `idle` → `loading` → `results` | `error`
- [x] Clear query → return to `idle` + `loadIdleFeed()`
- [x] Show result count line: e.g. “12 matches near you”

**Files:** `conversational_home_body.dart`, `widgets/command_input_pill.dart`

### 1.3 Bento results grid UI
- [x] Create `BentoResultsGrid` widget (staggered / masonry layout)
- [x] Add `BentoTileSize` to card model: `hero` | `standard` | `compact`
- [x] Layout rules:
  - [x] **Hero (2×2):** urgent or verified local campaign, or top trade match
  - [x] **Standard:** trade/gift with image
  - [x] **Compact:** text-only or secondary matches
- [x] Reuse `SocialListingCard` — add optional `size` prop for density/padding only
- [x] Pull-to-refresh on results
- [x] Infinite scroll / load more at grid bottom

**Files (new):** `lib/features/home_v2/conversational/widgets/bento_results_grid.dart`  
**Extend:** `lib/features/feed/widgets/social_listing_card.dart`, `lib/features/feed/models/social_listing_card_data.dart`

### 1.4 Result ranking (rules-based v1)
- [x] Create `ConversationalRanker` with weights:
  - [x] Proximity (from API `distanceKm` or radius tier)
  - [x] Module bias from query keywords (trade/gift/donate)
  - [x] Verified campaign boost
  - [x] Urgency: ending soon OR &lt;20% funded → prefer hero slot
  - [x] Karma tier boost (optional)
- [x] Unit tests for ranker with fixture JSON

**Files (new):** `lib/features/home_v2/conversational/conversational_ranker.dart`

### 1.5 Extend intent parser for search (not only navigation)
- [x] Add `IntentAction.searchFeed` alongside `browse` / `create`
- [x] When user types item-like query (e.g. “laptop”, “baby stroller”), prefer search feed over routing to hub
- [x] When user types module keyword only (e.g. “donate”), show chips: **Search nearby** | **Open Donations hub**
- [x] Fallback: no keyword match → run `search(query)` anyway

**Files:** `intent_recommendation_parser.dart`, `intent_module.dart`, `intent_navigation.dart`

---

## Phase 2 — Donation Hub inside the unified feed

### 2.1 Local verified fundraisers section
- [x] Create `DonationHeroTile` — large bento card with:
  - [x] Campaign image
  - [x] **Real-time progress bar** (raised / goal)
  - [x] Verified badge
  - [x] Distance badge (“2.4 km away”)
  - [x] **SUPPORT** CTA (`CampaignSupportCompliance.feedCtaLabel()`)
- [x] Filter: `verified` campaigns only in hero section (config flag for soft launch)
- [x] Proximity lock: default max radius from profile; **“Show wider area”** expands cascading liquidity

**Files (new):** `lib/features/home_v2/conversational/widgets/donation_hero_tile.dart`  
**Reuse:** `lib/features/home_v2/widgets/active_campaigns_rail.dart`, `lib/features/donations/widgets/campaign_verification_dialog.dart`

### 2.2 Idle feed composition
- [x] When query empty, `loadIdleFeed()` returns:
  - [x] Top: 1–3 donation hero tiles (verified, nearest, urgent)
  - [x] Below: mixed near-you trades/gifts in bento grid
- [x] Section headers: “Community fundraisers near you” | “Trades & gifts near you”

**Files:** `conversational_feed_provider.dart`, `bento_results_grid.dart`

### 2.3 Donation query bias
- [x] Keywords: donate, fundraiser, campaign, help, surgery, rent, school fees → boost campaign module in ranker
- [x] Optional chip after search: **Verified only** | **Within 5 km** | **Ending soon**

**Files:** `conversational_ranker.dart`, `conversational_home_body.dart`

### 2.4 Progress bar live updates
- [x] After in-app or web donate success, refresh campaign card in feed (listener / pull-to-refresh)
- [x] Deep link `webDonate=success` already handled in app — ensure feed invalidates on return

**Files:** `conversational_feed_provider.dart`, `conversational_feed_refresh.dart`, `lib/main.dart` (deep link handler)

---

## Phase 3 — Match → negotiate loop (UX polish)

### 3.1 Card primary actions
- [x] Trade card → **Make offer** → `NegotiationScreen` / offer flow
- [x] Gift card → **Claim** → existing claim flow
- [x] Donation card → **SUPPORT** → in-app donate or iOS web support
- [x] Secondary: **Message** on all types where applicable

**Files:** `social_listing_card.dart`, `conversational_card_actions.dart`, `bento_results_grid.dart`

### 3.2 Post-action feedback
- [x] Snackbar + CTA: “View offer in Trade Center” after offer sent
- [x] Route to Trade Center Offers tab with highlight (reuse notification navigation pattern)
- [x] After gift claim: open chat if conversation created (`followUpGiftClaimResult` + `openGiftGiverChat`)

**Reuse:** `lib/features/notifications/utils/notification_navigation.dart`, `lib/features/trade/screens/trade_screen.dart`

### 3.3 Chat entry from feed
- [x] **Message owner** from trade/gift detail without leaving feed context
- [x] Show unread dot on cards when conversation has unread (client-side via `ConversationalUnreadEnricher`)

### 3.4 Backend (optional)
- [x] API field: `hasUnreadMessages` per listing conversation for card badges
- [x] Or batch unread counts in search/list response (`ListingUnreadService`)

**Files:** `apps/api/src/common/listing-unread.service.ts`, `apps/api/src/search/`, `apps/api/src/chat/`

---

## Phase 4 — AI interpret layer (optional v2)

> Ship Phase 1–3 with rules first. Add AI when feed search is stable.

### 4.1 Query interpretation API
- [x] `POST /v1/search/interpret` → structured JSON:
  ```json
  { "modules": ["trade","campaign"], "query": "laptop", "locationHint": "near me", "verifiedOnly": false }
  ```
- [x] Provider: Gemini or OpenAI (env-gated — rules fallback when `OPENAI_API_KEY` unset)
- [x] Rate limit + fallback to keyword parser on failure

**Files (new):** `apps/api/src/search/search-interpret.controller.ts`, `search-interpret.service.ts`

### 4.2 Flutter integration
- [x] Call interpret endpoint before `SearchApiService.search` when `ENABLE_AI_SEARCH=true`
- [x] Show one-line summary above grid: “Found 4 trades and 2 local fundraisers near Uyo”
- [x] Never block UI on AI — show results from rules immediately, refine when AI returns

**Files:** `conversational_feed_provider.dart`, `lib/core/config/feature_flags.dart`

### 4.3 Voice input (future)
- [x] `CommandInputPill` mic button — speech-to-text wired (`speech_to_text` package)
- [x] Speech-to-text → same `search(query)` path

---

## Phase 5 — Polish, performance, accessibility

### 5.1 Loading & empty states
- [x] `BentoCardSkeleton` shimmer grid while loading
- [x] Empty results: “Nothing nearby yet” + **Expand search area** + **Post a listing**
- [x] Error state: offline message + retry (reuse startup network copy)

### 5.2 Performance
- [x] Debounce search 500ms; cancel in-flight requests on new query
- [x] Image prefetch for visible bento cells (`CachedMediaImage` / existing media resolver)
- [x] Do not autoplay video in grid (posters only — already policy)

### 5.3 Accessibility
- [x] Semantic labels on bento cards (“Trade: {title}, 2 km away”)
- [x] Focus order: greeting → feed → command bar (Column layout)
- [x] Minimum tap targets 44×44 on CTAs

### 5.4 Analytics
- [x] Log: `conversational_search_submitted`, `conversational_result_tap`, `conversational_backup_search_opened`
- [x] Track radius expansion events

---

## Phase 6 — Testing & rollout

### 6.1 Unit / widget tests
- [x] `IntentRecommendationParser` — item vs navigation intents
- [x] `ConversationalRanker` — hero selection, verified boost
- [x] `BentoResultsGrid` — layout with 0, 1, 5, 20 items *(0 / idle / hero cases covered)*

### 6.2 Manual QA checklist
- [ ] Guest home: type query → see public results
- [ ] Authed home: type query → see full results with geo
- [ ] Empty query → verified campaigns + near-you trades
- [ ] Drawer still opens Trade / Gift / Donations hubs
- [ ] Advanced search opens `SearchScreen` with filters intact
- [ ] iOS keyboard does not cover command bar
- [ ] Deep link to trade/gift/campaign still works from cold start
- [ ] Donate on iOS web → return → progress bar updates

### 6.3 Feature flag rollout
- [x] `CONVERSATIONAL_FEED_ENABLED` — flag + `LegacyHomeBody` fallback via `ConversationalHomeGate`
- [x] Fallback: old home sections via flag (if needed during transition)

---

## File map (planned)

```
lib/features/home_v2/conversational/
  conversational_home_body.dart       ← state machine + layout
  conversational_home_gate.dart       ← feature flag selector
  conversational_feed_provider.dart
  conversational_feed_refresh.dart    ← donate success invalidation
  conversational_analytics.dart
  conversational_unread_enricher.dart
  conversational_ranker.dart
  conversational_card_actions.dart
  intent_recommendation_parser.dart   ← extend
  widgets/
    bento_results_grid.dart
    donation_hero_tile.dart
    bento_quick_actions_panel.dart    ← wire idle
    command_input_pill.dart           ← voice input
    conversational_greeting.dart
```

---

## Implementation order (recommended sprints)

| Sprint | Deliverable |
|--------|-------------|
| **Sprint 1** | Phase 0 + Phase 1.1–1.2 (idle bento + search provider + submit) |
| **Sprint 2** | Phase 1.3–1.5 (bento grid + ranker + intent search) |
| **Sprint 3** | Phase 2 (donation heroes + idle feed) |
| **Sprint 4** | Phase 3 (offer/claim/support from cards) |
| **Sprint 5** | Phase 5–6 (polish, tests, feature flag) |
| **Later** | Phase 4 (AI interpret API) |

---

## Out of scope (keep as backup — do not delete)

- `SearchScreen` — advanced filters, categories, pagination
- Trade Center / Gifting / Donations hub screens
- `DiscoverScreen`
- Side drawer navigation
- Community module (removed from drawer; no work here unless product revives it)

---

## Related docs

- `DOCSS/HOME_PAGE_NAVIGATION_IMPLEMENTATION.md`
- `DOCSS/SOCIAL_FEED_MIGRATION_TODO.md`
- `DOCSS/EMAIL_LINK_CONFIG.md` (deep links from shared cards)
- `lib/features/home_v2/conversational/` (current Gemini-style shell)

---

*Last updated: 2026-07-06 — code complete; manual QA (6.2) and optional API unread badges (3.4) remain.*
