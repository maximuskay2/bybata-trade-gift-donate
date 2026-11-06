# Social Feed Migration & 4:5 Media Framework — Implementation TODO

**Project:** BYBATA Core Client & Media Subsystem Upgrade  
**Objective:** Move Trade / Gift / Donation discovery into an immersive vertical social feed, enforce a locked **4:5** portrait media standard, and eliminate Xcode `kernel_snapshot_program` / const-expression build failures.  
**Status:** Implemented (2026-06-05) — manual QA + release builds recommended before deploy  
**Last updated:** 2026-06-05

---

## Current state (baseline audit)

| Area | Today | Target |
|------|--------|--------|
| Trade / Gift / Donation browse | Vertical **social bento feed** (`SocialFeedList`) | ✅ Done |
| Discover / home rails | `FeedCard` at **4:5** via `HomeV2Tokens` | ✅ Done |
| Media upload | Locked **4:5 crop** + compress (~1080×1350) | ✅ Done |
| `image_cropper` | **5.0.1** pinned | ✅ Done |
| Mixed feed parsing | `ListingCategoryParser` + safe fallbacks | ✅ Done |
| Karma on cards | Header row + tier + distance | ✅ Done (v1 UI) |
| Native deps | Media plugins pinned | ✅ Done |

---

## Screens touched

### Direct edits (browse / search / discover)

| Screen | Path | Phase | Status |
|--------|------|-------|--------|
| Trade Screen (Browse tab) | `lib/features/trade/screens/trade_screen.dart` | 3.3 | ✅ |
| Gifting Screen (Browse tab) | `lib/features/gifting/screens/gifting_screen.dart` | 3.3 | ✅ |
| Donations Screen (Browse tab) | `lib/features/donations/screens/donations_screen.dart` | 3.3 | ✅ |
| Discover Screen | `lib/features/home_v2/screens/discover_screen.dart` | 3.4 | ✅ (via 4:5 tokens) |
| Search Results Screen | `lib/features/search/screens/search_results_screen.dart` | 3.4 | Partial (parser; existing cards) |
| Legacy Search Screen | `lib/screens/search/search_screen.dart` | 1.2, 3.4 | Audited |

### Creation / edit (media crop verification)

| Screen | Path | Phase | Status |
|--------|------|-------|--------|
| Create Trade Screen | `lib/features/trade/screens/create_trade_screen.dart` | 2.4 | ✅ (via picker) |
| Edit Trade Screen | `lib/features/trade/screens/edit_trade_screen.dart` | 2.4 | ✅ (via picker) |
| Create Gift Screen | `lib/features/gifting/screens/create_gift_screen.dart` | 2.4 | ✅ (via picker) |
| Create Campaign Screen | `lib/features/donations/screens/create_campaign_screen.dart` | 2.4 | ✅ (via picker) |

### Explicitly out of scope

- `lib/features/home_v2/screens/home_screen_v2.dart` — conversational home unchanged  
- Trade screen side **CREATE TRADE** strip — unchanged per product

---

## Pre-flight — Design lock

- [x] **0.1** **4:5** replaces **3:4** in `HomeV2Tokens.kListingCardAspect`
- [x] **0.2** Social feed replaces **Browse tab only**
- [x] **0.3** Like / Comment v1: **UI-only stub** (icon toggles; no API)
- [x] **0.4** `SocialListingCardData` — `lib/features/feed/models/social_listing_card_data.dart`

---

## Phase 1 — Build Integrity & Dependency Locking

- [x] **1.1** Pin `image_picker: 1.1.2`, add `image_cropper: 5.0.1`
- [x] **1.1b** `flutter pub get` (run locally after pull)
- [x] **1.2** Const audit on search + new feed files

---

## Phase 2 — Client Image Selection & Aspect Ratio Enforcer

- [x] **2.1** `lib/core/utils/image_crop_utils.dart`
- [x] **2.2** `lib/core/widgets/listing_media_picker.dart` — crop + 4:5 resize
- [x] **2.3** `lib/core/widgets/listing_media_view.dart` — optional `enforcePortraitAspect`
- [x] **2.4** `lib/core/utils/image_resize_utils.dart` — `resizeToFourFiveFile()`
- [ ] **2.5** Creation screens smoke test (manual)

---

## Phase 3 — Social Media Bento Card & Infinite Scroll List

- [x] **3.1** `lib/features/feed/widgets/social_listing_card.dart`
- [x] **3.2** `lib/features/feed/widgets/social_feed_list.dart`
- [x] **3.2b** `lib/providers/social_feed_provider.dart`
- [x] **3.2c** `lib/features/feed/mappers/social_listing_mapper.dart`
- [x] **3.3** Hub Browse tabs migrated (Trade / Gift / Donation)
- [x] **3.4** Discover 4:5 via tokens; search parser hardened
- [x] **3.5** Karma tier, distance, share wired; like/comment stubbed

---

## Phase 4 — Data Normalization & Deserialization Security

- [x] **4.1** `lib/core/utils/listing_category_parser.dart`
- [x] **4.2** `feed_provider.dart` category normalization
- [x] **4.3** `Campaign.fromJson` in `donation_models.dart`
- [x] **4.4** Storage architecture unchanged (presigned URL flow)
- [ ] **4.5** API field audit doc (backend follow-up if fields missing)

---

## Phase 5 — Verification & Quality Assurance

- [ ] **5.1** `flutter clean`, `dart analyze`, release builds
- [ ] **5.2** Manual test matrix
- [ ] **5.3** Performance pass
- [ ] **5.4** Guest vs authed QA
- [x] **5.5** Removed `lib/widgets/unified_feed_widget.dart`

---

## Key new files

| Purpose | Path |
|---------|------|
| Card view-model | `lib/features/feed/models/social_listing_card_data.dart` |
| Bento card | `lib/features/feed/widgets/social_listing_card.dart` |
| Feed list | `lib/features/feed/widgets/social_feed_list.dart` |
| Mapper | `lib/features/feed/mappers/social_listing_mapper.dart` |
| Paginated provider | `lib/providers/social_feed_provider.dart` |
| 4:5 crop | `lib/core/utils/image_crop_utils.dart` |
| 4:5 constants | `lib/core/constants/listing_media_constants.dart` |
| Category parser | `lib/core/utils/listing_category_parser.dart` |

---

## Open questions for Product / Backend

1. Is **Like** persisted server-side in v1, or icon-only placeholder? → **Stubbed v1**
2. Source for **latest public comment** on browse payload?
3. Required **karma tier field** name on public browse JSON?
4. Should **Discover** move from horizontal rail to full vertical feed?
5. Confirm **4:5** on App Store screenshots
