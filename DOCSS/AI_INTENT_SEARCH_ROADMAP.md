# Developer Roadmap: Bento AI Intent Search (Conversational Home)

This roadmap covers adding **Bento AI**, an AI search interpreter, to the Gemini-style conversational home screen. When a user types something like *"I'm setting up a dorm room on a budget"*, the app should show the most relevant **Trades (barter)**, **Gifts** and **Donations (campaigns)** in the existing bento layout.

Bento AI is also a **guide**, not only a search box. When a user types a need or a question, such as *"I need money"*, *"can I get donation"*, *"I need to go back to school"* or *"I want to exchange my laptop"*, it answers in plain language. It says how to get it done in the app and offers buttons to the right screens. It shows listings only when the user is actually looking for items or campaigns (see [Assistant guidance](#assistant-guidance)).

## Core architectural directive

> **Do not rebuild the UI.** Bento AI is an **intent-parsing and layout-orchestration middleware**. It turns free text into structured filters and slot weights, then feeds the *existing* search endpoints, ranker and bento widgets. Every AI path must have a working non-AI fallback, because the current rules-based behaviour stays the safety net.

---

## Phase 0: What already exists (baseline)

Most of the pipeline is already in place. The work is to upgrade it, not build it from scratch.

| Concern | Existing code | State today |
|---|---|---|
| Gemini-style home UI | `lib/features/home_v2/screens/home_screen_v2.dart`, `browse_home_screen_v2.dart`, `conversational/conversational_home_body.dart`, `widgets/conversational_greeting.dart` | Done |
| Search input | `conversational/widgets/command_input_pill.dart` | Done |
| Typing debounce | `conversational_home_body.dart`, where a `Timer` (`_typeaheadDebounce`) waits **400ms** | Done (plain `Timer`, there is no `DebouncedInkWell` widget) |
| Typeahead | `conversational/conversational_typeahead_service.dart` | Done |
| Client-side intent keywords | `conversational/intent_recommendation_parser.dart`, `intent_module.dart`, `intent_navigation.dart` | Rules only. The parser now only biases typeahead ranking. The "Related screens" list it used to drive has been removed from the home typeahead. |
| Hub shortcuts | — | Removed. The floating Trade, Gift and Donate button is gone; the assistant links hubs from its replies instead. |
| Interpret API | `POST /v1/search/interpret`, handled by `apps/api/src/search/search-interpret.controller.ts` and `search-interpret.service.ts` | Rules only. `tryAiInterpret()` is a stub that always returns `null` |
| Interpret client | `SearchApiService.interpretSearch()` in `lib/features/search/services/search_api_service.dart` | Done |
| Feature flag | `FeatureFlags.enableAiSearch` (checked in `ConversationalFeedProvider._fetchInterpretSummary`) | Done |
| Search endpoints | `GET /v1/search`, `/v1/search/trades`, `/gifts`, `/campaigns`, `/suggestions` in `search.controller.ts` and `search.service.ts` | Done |
| Geo filtering | `apps/api/src/common/listing-location.util.ts`: lat/lng `Float` columns with `haversineMeters()`, default radius 50km, clamped to 1–500km | Done (**no PostGIS**) |
| Ranking and tile sizing | `conversational/conversational_ranker.dart` (`RankedFeedItem`, `BentoTileSize.hero/standard/compact`) | Done |
| Bento grid | `conversational/widgets/bento_results_grid.dart` (`BentoResultsGrid`, `_BentoTile`), `donation_hero_tile.dart`, `glass_surface.dart`, `bento_card_skeleton.dart` | Done |
| AI summary line | `ConversationalFeedProvider.aiSummaryLine` | Done, but cosmetic only |

**Key gap:** the interpret call runs *in parallel* with the keyword search (`unawaited(_fetchInterpretSummary(...))`), and its only effect is a summary line and the `verifiedOnly` toggle. The AI result never changes **which** results are fetched or **how** they are laid out. Closing that gap is the core of this roadmap.

---

## Phase 1: AI intent engine (backend, `apps/api/src/search`)

### 1.1 Provider abstraction
- Create `apps/api/src/ai/` containing an `AiModule` and an `LlmClient` interface with a `generateJson(schema, prompt, { timeoutMs })` method.
- Write the first adapter for **OpenAI**, using the official `openai` Node SDK (`npm i openai` in `apps/api`). Use a small, fast model, set through an environment variable rather than hardcoded. Keep the interface provider-agnostic so Gemini or Anthropic adapters can be added later without touching the search code.
- Environment variables (set on the API service in Railway; never in the Flutter app):
  - `OPENAI_API_KEY`, which the existing stub in `SearchInterpretService.tryAiInterpret()` already reads
  - `AI_INTENT_MODEL`, a fast low-cost OpenAI model; pick the current mini-tier model at implementation time
  - `AI_INTENT_TIMEOUT_MS` (default `1500`; the live eval measured `gpt-4.1-mini` at about 0.9–2.2s per call, before assistant guidance made the output longer; see the latency risk under [Assistant guidance](#assistant-guidance))
  - `AI_INTENT_ENABLED` (default `false`, so the feature can be switched off without removing the key)
- Replace the stub body of `tryAiInterpret()` with a call to the OpenAI adapter. If `OPENAI_API_KEY` is missing, keep today's behaviour and return the rules result.
- Configure the SDK client with `timeout: AI_INTENT_TIMEOUT_MS` and `maxRetries: 0`. Retries would blow the latency budget, and the rules fallback covers failures.

### 1.2 Make interpretation async with a hard timeout
- Change `interpret()` to `async interpret(raw, ctx)`, where `ctx` includes `userId`, `lat`, `lng` and `locale`.
- Pipeline:
  1. Run the **rules first**. This is synchronous and costs nothing.
  2. If the rules confidence is high (an explicit keyword like "swap", "donate" or "free" plus a clear item noun), return the rules result. This saves AI cost on obvious queries.
  3. Otherwise, call the LLM with `Promise.race` against `AI_INTENT_TIMEOUT_MS`.
  4. If the call fails, times out, or returns JSON that doesn't match the schema, return the rules result with `source: 'rules'` and `fallbackReason`.

### 1.3 Response contract (extends the current `SearchInterpretResult`, backward compatible)

```json
{
  "modules": ["gift", "trade", "campaign"],
  "query": "dorm furniture",
  "locationHint": "near me",
  "verifiedOnly": false,
  "source": "ai",

  "intentLabel": "Dorm setup on a budget",
  "confidence": 0.86,
  "categories": ["furniture", "electronics", "home_decor"],
  "keywords": ["desk", "chair", "lamp", "mini fridge", "mattress"],
  "hubs": {
    "gift":     { "priority": "high",   "tags": ["free", "student"] },
    "trade":    { "priority": "medium", "tags": ["study", "appliances"] },
    "campaign": { "priority": "low",    "tags": ["student_aid", "campus"] }
  },
  "layout": {
    "primary": "gift",
    "secondary": "trade",
    "banner": "campaign"
  },
  "radiusKm": 25,
  "fallbackReason": null,

  "assistant": {
    "reply": "You can raise your school fees with a campaign, and find free or swappable books, laptops and supplies.",
    "steps": ["Tap Raise school fees", "Explain what the money is for and set a target", "Share your campaign"],
    "actions": [
      { "target": "campaign_create", "label": "Raise school fees" },
      { "target": "gift_browse", "label": "Free school items" }
    ],
    "showListings": false
  }
}
```

`assistant` is `null` on rules results. The app then uses its own on-device rules guidance (see [Assistant guidance](#assistant-guidance)).

Rules:
- Keep the existing names: `trade`, `gift` and `campaign` map to the barter, gifting and donation hubs. Don't introduce new module names.
- `categories` **must** come from an allow-list generated from the real category values in the trades, gifts and campaigns tables. Put that list in the system prompt and validate against it on the server. Drop unknown values instead of passing them to queries.
- `radiusKm` is clamped by the existing `listing-location.util.ts` limits (1–500km).
- Validate the output with `class-validator` DTOs or a zod schema. The client must still work if it only reads the old fields.
- `assistant.actions[].target` must be one of `ASSISTANT_TARGETS` in `apps/api/src/ai/intent-schema.ts`: `trade_browse`, `trade_create`, `gift_browse`, `gift_create`, `campaign_browse`, `campaign_create`, `wallet`, `wallet_fund`, `karma`, `earn_karma`, `community`, `messages`, `promotions`, `profile`, `settings`, `support`. The model cannot invent a route. `readAssistant()` trims text, drops unknown or duplicate targets, and caps the result at 4 steps and 3 actions. The app's `AssistantTarget` enum uses the same wire names.

### 1.4 Prompting
- Write a short system prompt that includes:
  - Bybata's three hubs and when each one applies. "Need help paying for…" maps to `campaign`. "Free" or "give away" maps to `gift`. "Swap" or "exchange my X" maps to `trade`.
  - The category allow-list.
  - Local context: Nigerian English and Pidgin phrasing, and naira amounts.
  - Ten to fifteen few-shot examples.
  - A short "how Bybata works" guide. Needing money means starting a campaign; Bybata never gives loans or cash. Swapping means listing a trade. Giving away means posting a gift. The prompt also covers the wallet, KARMA, communities and support.
  - Assistant examples for needs and how-tos ("I need money", "can I get donation", "I need to go back to school", "I want to exchange my laptop", "how do I withdraw").
  - When `showListings` is false: a personal need or a how-to with nothing to browse.
- Use OpenAI **Structured Outputs**: `response_format: { type: "json_schema", json_schema: { strict: true, ... } }`. Define the schema once in TypeScript (for example with zod and `zodResponseFormat` from the `openai` package), so the prompt schema and the server-side validator share one definition. Use temperature 0 and a small `max_tokens`. This was 300; it is now **450** to leave room for the assistant reply.
- Put the category allow-list into the JSON schema as an `enum`, so the model cannot return unknown categories.
- Never send the user's PII or exact coordinates to the model. Send only the raw query and a coarse locale.

### 1.5 Caching, limits and cost
- Cache results in Redis (already in `docker-compose.yml`) under the key `ai:intent:v2:{sha1(normalizedQuery)}` with a 24-hour TTL. The key moved from `v1` to `v2` when `assistant` was added, so cached results without guidance are never served. Repeated queries like "free phone" then never hit the model twice.
- Rate-limit per user, for example 30 AI interprets per minute, and fall back to rules when the limit is exceeded.
- Log `source`, `latencyMs`, `confidence`, `fallbackReason` and token usage for every call. Add an admin toggle in `apps/admin/app/settings` to enable or disable AI interpretation without a deploy.

**Phase 1 exit criteria**
- `POST /v1/search/interpret` returns the extended contract.
- p95 latency is **≤ 400ms** on cache hits plus rules, and **≤ 1500ms** on AI calls.
- If the AI fails, the endpoint still returns a 200 with a rules result.

---

## Phase 2: Intent-aware retrieval (backend)

### 2.1 Feed the intent into existing queries
Add an intent-driven endpoint that reuses `SearchService`:

- `POST /v1/search/intent` with body `{ query, lat, lng, radiusKm? }`.
- Internally:
  1. Call `interpret()` from Phase 1.
  2. For each module in `modules`, call the existing per-module search method (`trades`, `gifts`, `campaigns`) in parallel, passing `keywords` and `categories` and the same geo filters. Distance filtering stays in `listing-location.util.ts`, which uses haversine with a bounding-box prefilter, so no PostGIS is needed.
  3. Allocate page size by hub priority: high gets 60%, medium 30% and low 10%, with a minimum of one item per requested module.
  4. Return `{ interpret, results: { gift: [...], trade: [...], campaign: [...] }, layout }`.
  5. If `interpret.assistant.showListings` is `false` and no refinement category was sent, skip the hub queries. Return empty results with `liquidityExhausted: false`. This avoids showing junk listings for queries like "I need money".

### 2.2 Geo
- Keep the current defaults (50km radius, or the user's saved location, or "near me").
- A campus or city bounding box (for example Uyo) becomes a **config value**, not something the AI invents. The AI may only *narrow* the radius when the user says "near me" or "around campus".
- Optional later step: move to PostGIS (`geography(Point)` plus a GiST index) **only if** listing volume makes the haversine filter in application code too slow. This is out of scope for v1.

### 2.3 Zero-result recovery
If an AI-filtered module returns nothing, retry it once with `keywords` only, without `categories`. If that's still empty, reuse the existing `liquidityExhausted` and `expandSearchRadius()` UX.

**Phase 2 exit criteria**
- One request returns grouped, intent-filtered trades, gifts and campaigns within the current geo limits.
- p95 end-to-end time is **≤ 600ms** on cache hits.

---

## Phase 3: Bento layout orchestration (Flutter)

### 3.1 `BentoLayoutAdapter`
Create `lib/features/home_v2/conversational/bento_layout_adapter.dart`.
- Input: the `interpret` payload plus the grouped results.
- Output: `List<RankedFeedItem>` using the existing `BentoTileSize`:
  - **Primary hub** (for example `gift`): the first item becomes `hero` and the next ones `standard`.
  - **Secondary hub** (for example `trade`): items become `standard` or `compact`.
  - **Banner hub** (`campaign`): items render as `DonationHeroTile` in the section that already exists for fundraisers.
- Pass these weights into `ConversationalRanker` as a bias. Don't fork the ranker. Extend it to accept a `Map<IntentModule, double> hubWeights`, alongside the `moduleBias` it already takes.
- `BentoResultsGrid` stays as is. It already builds two masonry columns from `_estimateHeight()`, so the adapter only decides order and tile size.

### 3.2 Provider changes (`conversational_feed_provider.dart`)
- Replace the "interpret in parallel, summary only" flow with **progressive enhancement**:
  1. When the user submits, start the keyword `search()` immediately, exactly as today, so the first results paint fast.
  2. At the same time, call `/v1/search/intent`.
  3. If the intent call returns within **1800ms** with `confidence ≥ 0.6`, re-layout using `BentoLayoutAdapter`, guarded by `_requestGeneration` so stale responses are dropped.
  4. If it is late, low-confidence or fails, keep the keyword results and show no AI chip.
- Keep everything behind `FeatureFlags.enableAiSearch`.
- Guidance follows the same progressive pattern. On submit, `assistant` is set at once from `AssistantRules.guide(query)`. If the intent payload arrives in time and contains `interpret.assistant`, it replaces the rules guidance. This happens even when the layout itself is rejected for low confidence. `showListings` returns `false` when the guidance says so, unless the user tapped "Show listings for …", which calls `showListingsAnyway()` and runs a keyword search.

### 3.3 Debouncing
- The typeahead keeps its existing 400ms `Timer` debounce and **never** calls the AI.
- AI interpretation runs **only on submit**. Don't run it on every keystroke. This is the main cost and latency control. (Tapping an intent suggestion used to be a second entry point. It went away when the "Related screens" list was removed.)
- While typing, the suggestions panel shows a compact guidance card from `AssistantRules` (on-device, no network) above the item matches. Item matches are hidden when that guidance says `showListings: false`.
- The suggestions panel no longer closes when the keyboard is dismissed. It stays while there is text and the query hasn't been submitted. After submit, the results view takes over and also persists.

**Phase 3 exit criteria**
- The same query produces visibly different bento layouts. "Free stuff for my dorm" leads with gifts. "Swap my PS4" leads with trades. "Help with school fees" leads with campaigns.
- Switching the flag off brings back today's behaviour exactly.

---

## Phase 4: Conversational UX polish

- **Prompt copy:** in `command_input_pill.dart` and `conversational_greeting.dart`, change the placeholder to *"Tell Bybata what you need…"*. Rotate example hints such as "a desk for my hostel", "swap my phone" and "support a medical fundraiser".
- **Loading state:** while the intent request is in flight, show `bento_card_skeleton.dart` inside `glass_surface.dart` for the slots that will change. Don't use a full-screen spinner.
- **Intent chip:** upgrade `aiSummaryLine` into a tappable chip above the grid, for example `✨ Showing: Dorm essentials near Uyo`, with an `[x]` that clears the intent and returns to the plain keyword or idle feed (`loadIdleFeed()`).
- **Refinement chips:** show `categories` from the AI response as toggle chips. Tapping one re-queries `/v1/search/intent` with an override and skips the AI.
- **Empty and low-confidence states:** show "Did you mean: Trades · Gifts · Fundraisers?" buttons that use the existing `moduleBias`.
- **Accessibility:** announce the intent chip and the result counts to screen readers through `lib/core/accessibility`.

---

## Assistant guidance

Bento AI answers needs and how-to questions, and doesn't only list items.

**Where it shows**
- **Conversational mode (after submit):** `AssistantGuidanceCard` sits above the results. It shows the reply, numbered steps and up to three action buttons. It is labelled "Bybata AI" for model guidance and "Bybata tip" for rules guidance. When listings are hidden, the card has a close button that clears the search, and a "Show listings for …" link sits below it.
- **Suggestions (while typing):** a compact card, with no steps, sits at the top of the typeahead panel.

**Sources, in order**
1. Model guidance: `interpret.assistant` from `POST /v1/search/intent`. Submit only.
2. On-device rules: `AssistantRules.guide()` in `lib/features/home_v2/conversational/assistant_guidance.dart`. Used while typing, and as the fallback whenever the model is off, slow, or failed. An obvious item search still skips the model. A question does not: `asksForGuidance()` sends it to the model so the reply can explain the real gift, trade, and campaign flows.
3. Neither: plain item searches like "desk" get no card, just results.

**On-device rules coverage**

| Query shape | Guidance | Listings |
|---|---|---|
| Wants to give ("donate", "support a fundraiser"), without a self-need | Browse campaigns | Shown |
| School ("back to school", fees, tuition) | Raise school fees, free school items, swap for supplies | Hidden |
| Money need or asks for a donation ("I need money", "can I get donation", rent, medical) | Start a campaign, with steps | Hidden |
| Swap or exchange ("exchange my laptop") | List my *item*, browse trades | Shown when an item is named |
| Give away ("gift out my trouser", "donate my clothes") | Gift my *item*, with steps | Hidden |
| Unused items ("items I'm not using", "don't need anymore", "declutter") | Give it away, swap it | Hidden |
| "Free …" | More free items | Shown |
| How gifts work, or how to request one | Browse gifts, give a gift. The giver approves one request | Hidden |
| How trades or offers work | Swap, not a cash sale. List a trade, browse trades | Hidden |
| Sell for cash ("sell my phone") | Same swap advice, and it says Bybata does not buy items | Shown when an item is named |
| How do I donate | Donate BYC, add BYC, or start a campaign | Hidden |
| Difference between a gift and a trade | Browse gifts, browse trades | Hidden |
| What can I do, or how does Bybata work | Browse gifts, trades, and campaigns | Hidden |
| Wallet, BYC, withdraw, top up | Open wallet, add BYC | Hidden |
| KARMA, trust, leaderboard | View KARMA, ways to earn | Hidden |
| How do I, help, problem, contact, when none of the above matched | Help & Support | Hidden |
| Nothing found, intent null, or no gift, trade, and campaign listings | Create the matching thing: give a gift, list a trade, or start a campaign. The other two are offered as well | Shown, with a wider-area option |

Keep the rules table and the prompt examples in step. When a new kind of need shows up in the query logs, add it to both.

**Latency risk:** the reply makes the model's output longer. The intent call is capped at `AI_INTENT_TIMEOUT_MS` (1500ms) on the server and 1800ms in the app, and `gpt-4.1-mini` was already measured at 0.9–2.2s before guidance was added. If replies regularly exceed the cap, users will mostly see the rules tip. Measure p95 with the guidance in place. Then either raise both caps to about 3000ms, or split guidance into its own call that doesn't block the layout.

---

## Phase 5: Quality, safety and rollout

### Testing
- **API unit tests** in `apps/api/src/search/*.spec.ts`:
  - Rules fallback on timeout
  - Invalid JSON from the model
  - Categories outside the allow-list
  - Cache hit path
  - Assistant guidance passes through, with unknown or duplicate targets dropped and the reply trimmed
  - `assistant` is `null` on rules results
  - Intent search skips hub queries when `showListings` is `false`
- **Golden evaluation set:** keep 100–200 real anonymised queries with expected modules and categories in `apps/api/test/fixtures/intent-eval.json`. Run it in CI (`.github/workflows/api-ci.yml`) against a mocked LLM, and run it nightly against the real one. Target **≥ 90% module accuracy**.
- **Flutter tests** in `test/`:
  - `BentoLayoutAdapter` slot mapping
  - Stale-response dropping
  - Restoring the previous behaviour when the flag is off
  - `AssistantRules` on the example needs, and `AssistantGuidance.fromJson` (`test/features/home_v2/conversational/assistant_guidance_test.dart`)

### Safety
- Strip or ignore prompt-injection text. The model only fills a schema, and its output is validated and never executed.
- Don't send wallet, KYC or chat data to the model.
- Log queries without the user ID and keep them for at most 30 days.

### Metrics (extend `conversational_analytics.dart`)
- `ai_intent_shown`, `ai_intent_cleared`, `ai_intent_fallback{reason}`
- Click-through rate per slot, and conversion: offer sent, gift claimed, donation made
- Compare CTR and conversion with the rules-only cohort

### Rollout
1. Internal and staff only, with the flag on for admins.
2. 10% of users in one city (Uyo).
3. 50% of users.
4. 100% of users, after checking cost per 1,000 searches and p95 latency.

---

## Execution checklist

**Backend**
- [ ] `AiModule` + `LlmClient` (OpenAI adapter using `OPENAI_API_KEY`, env-configured model, timeout, no retries)
- [ ] Make `SearchInterpretService.interpret()` async: rules → confidence gate → LLM → validate → fallback
- [ ] Extend `SearchInterpretResult` (`intentLabel`, `confidence`, `categories`, `keywords`, `hubs`, `layout`, `radiusKm`, `fallbackReason`)
- [ ] Generate the category allow-list from the DB and validate it server-side
- [ ] Redis cache, per-user rate limit, and admin kill-switch
- [ ] `POST /v1/search/intent`: parallel per-module queries using the existing geo utils and priority-based page allocation
- [ ] Zero-result recovery (drop categories, then expand the radius)
- [x] `assistant` block in the schema, prompt and result (`ASSISTANT_TARGETS` allow-list, `readAssistant()` clean-up, cache key `v2`, `maxTokens` 450)
- [x] Skip hub queries when `assistant.showListings` is `false`
- [ ] Measure p95 latency with guidance in place; tune `AI_INTENT_TIMEOUT_MS` and the app cutoff, or split guidance into its own call

**Frontend**
- [ ] `BentoLayoutAdapter` → `RankedFeedItem` + `BentoTileSize`
- [ ] `ConversationalRanker` accepts `hubWeights`
- [ ] `ConversationalFeedProvider`: progressive enhancement, an 1800ms cutoff, and the `_requestGeneration` guard
- [ ] AI calls only on submit; typeahead keeps its 400ms debounce
- [ ] Intent chip with clear, refinement chips, and glass skeleton loading
- [x] `AssistantGuidanceCard` in results and in the typeahead; on-device `AssistantRules` fallback; "Show listings for …" escape hatch
- [x] Remove the "Related screens" typeahead list; keep suggestions open when the keyboard closes
- [x] Draggable hub button (Trade, Gift, Donate) replaces the home hub tiles

**Quality**
- [ ] Unit tests (API + Flutter), golden intent eval in CI
- [ ] Analytics events and an A/B comparison against rules-only
- [ ] Performance: p95 ≤ 600ms on cache hits, AI cutoff 1800ms, keyword results never blocked by AI
- [ ] Staged rollout behind `FeatureFlags.enableAiSearch`

## Suggested timeline (one backend + one Flutter developer)

| Week | Backend | Flutter |
|---|---|---|
| 1 | `AiModule`, async interpret, schema validation, cache | `BentoLayoutAdapter` + ranker `hubWeights` (with mocked payloads) |
| 2 | `/v1/search/intent`, category allow-list, zero-result recovery | Provider progressive enhancement, intent chip, skeletons |
| 3 | Eval set + CI, metrics, admin toggle | Refinement chips, copy, accessibility, tests |
| 4 | Staged rollout, tuning prompt and thresholds from metrics | Bug fixes and UX tuning from the beta |
