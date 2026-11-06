# Trade Flow Improvements – Implementation TODO

Implementation guide for enhancing the trade/offer/negotiation flow. Work through sections in order or pick items by priority.

**Already implemented:** Share trade (10.1), duplicate offer handling (9.1), pull-to-refresh (1.3), empty states with icons (1.2), offer status badges (1.1), NegotiationScreen status (1.1), backend trade + reject notifications (3.1), withdraw API + UI on all screens (5.2), offer status mapping (9.4), offer notification routing (3.1), copy offer details (10.2), offer status in chat (2.3), quick actions in chat (2.4), haptic on Accept/Reject/Send (8.3).

---

## 1. UX & Flow

### 1.1 Offer status badges
- [x] **Offer cards (trade_screen.dart)** – Status badges exist via `_buildStatusBadge`
- [x] **Improve labels** – User-friendly labels via `getOfferStatusDisplayFromRaw` (Pending, Awaiting your response, Accepted – finalize, etc.)
  - `Pending` – Offer awaiting response
  - `Awaiting your response` – Incoming offer for current user
  - `Accepted – finalize` – Cash offer accepted, bidder must finalize
  - `Accepted` – Item offer accepted
  - `Rejected` / `Declined` / `Withdrawn`
- [x] **ExistingOfferNegotiationScreen** – Status badge in header
- [x] **NegotiationScreen** – Show status badge in header when opened with existing offer (offerId)
- [x] Use consistent colors per status via `OfferStatusDisplay` (orange=pending, green=accepted, red=rejected)

### 1.2 Empty states
- [x] **Offers tab** – Empty state exists: "No Offers" with "New barter requests appear here"
- [x] **Chat in TradeChatScreen** – Empty state exists: "Start the trade discussion"
- [x] **Negotiation timeline** – Empty state via `_buildTimelineEmptyState` when history fails or is empty
- [x] Add illustrations or icons for each empty state (icons present: handshake, inbox, history, error)

### 1.3 Pull-to-refresh
- [x] **Offers tab** – `RefreshIndicator` wraps list, calls `_loadOngoingOffers`
- [x] **ExistingOfferNegotiationScreen** – `RefreshIndicator` for offer history
- [x] **TradeChatScreen** – `RefreshIndicator` on message list
- [x] **TradeOffersScreen** – Pull-to-refresh via `RefreshIndicator` on `_loadOffers`
- [ ] Use consistent refresh behavior across screens

### 1.4 Loading skeletons
- [ ] Create reusable `OfferCardSkeleton` widget
- [ ] Create `TradeCardSkeleton` for browse/mine tabs
- [ ] Create `MessageBubbleSkeleton` for chat
- [ ] Replace `CircularProgressIndicator` with skeletons on:
  - Offers tab list
  - Negotiation screen (offer timeline + form)
  - Chat message list
- [ ] Consider `shimmer` or `skeletonizer` package

---

## 2. Negotiation & Chat

### 2.1 Inline chat in negotiation
- [ ] Refactor `ExistingOfferNegotiationScreen` to embed chat
- [ ] Add collapsible/expandable chat section below offer timeline
- [ ] Or use a split view: timeline top, chat bottom (with adjustable height)
- [ ] Reuse `TradeChatScreen` logic or extract shared chat widget
- [ ] Ensure chat loads with `offerId` for correct conversation

### 2.2 Unread indicators
- [ ] **Backend** – Add unread count or flag for chat per offer/conversation
- [ ] **API** – Endpoint or field for "has unread messages" per offer
- [ ] **Offer cards** – Show badge/dot when offer has unread chat
- [ ] **Offers tab** – Show count of offers with unread messages
- [ ] Clear unread when user opens chat

### 2.3 Offer status in chat
- [x] **TradeChatScreen** – Offer status in header subtitle (e.g. "Offer pending", "Accepted")
- [x] Pass `offerStatus`, `isOwner` into `TradeChatScreen` when opened from negotiation/offers
- [x] Update via quick actions (Accept/Decline pop with result)
- [x] Use subtitle in app bar

### 2.4 Quick actions in chat
- [x] Add Accept / Decline / Counter-offer buttons in `TradeChatScreen` when offer pending
- [x] Owner: Accept, Decline, Counter; Bidder: Counter
- [x] Wire to `TradeBackendProvider.acceptOffer`, `rejectOffer`
- [x] Counter navigates to `NegotiationScreen` with `parentOfferId`
- [x] Compact action bar above message input

---

## 3. Notifications & Reminders

### 3.1 Push notifications
- [x] **Backend** – Trade notifications exist: `notifyTradeOffer`, `notifyTradeAccepted`, `notifyCounterOffer`
- [x] **Backend** – `notifyTradeRejected` added; called from `rejectOffer` in trades.service
- [x] **Push payload** – `data` includes `tradeId`, `offerId`; `actionUrl` is `/trades/{tradeId}`
- [x] **Flutter** – Route offer notification taps to `OfferNegotiationLoader` → `ExistingOfferNegotiationScreen` when `offerId` present
- [x] **Chat notifications** – Chat taps route to specific conversation via `NotificationNavigation.openChatScreen`

### 3.2 Reminders
- [ ] **Backend** – Optional: scheduled job for "pending offers awaiting response"
- [ ] **In-app reminder** – Banner or snackbar: "You have X offers awaiting response"
- [ ] **Settings** – Toggle for reminders (on/off)
- [ ] Show on app open or when entering Trade/Offers tab

### 3.3 Badge counts
- [ ] **Backend** – Endpoint for unread offer count (or derive from notifications)
- [ ] **Trade tab** – Badge on "Offers" tab with count of pending incoming offers
- [ ] **Bottom nav** – Optional badge on Trade icon for pending offers
- [ ] Update count when offers are viewed/accepted/rejected

---

## 4. Trust & Safety

### 4.1 Trade partner profile
- [ ] Add "View profile" on `ExistingOfferNegotiationScreen` (partner avatar/name)
- [ ] Navigate to `UserProfileScreen` with partner ID
- [ ] Show rating, completed trades, join date in a compact card or bottom sheet
- [ ] Reuse existing profile API and screen

### 4.2 Report/block
- [ ] **Backend** – Report and block endpoints if not present
- [ ] Add "Report" / "Block" in negotiation screen overflow menu
- [ ] Confirmation dialog before block
- [ ] After block: hide offers from blocked user, prevent new offers

### 4.3 Meeting location
- [ ] **Schema** – Add `meetingLocation` to `TradeOffer` in Prisma if needed (Flutter model has it; API schema does not)
- [ ] **NegotiationScreen** – Optional field for meeting place
- [ ] **ExistingOfferNegotiationScreen** – Display meeting location when set
- [ ] Consider map picker for location

### 4.4 Trade completion confirmation
- [ ] **Backend** – Both parties confirm completion before finalizing
- [ ] **Flow** – Owner confirms receipt → Bidder confirms handover → Trade finalized
- [ ] **UI** – "I've received the item" / "I've handed over the item" buttons
- [ ] Update `finalizeOffer` flow to support dual confirmation

---

## 5. Technical & Data

### 5.1 Offer expiry
- [ ] **Schema** – Add `expiresAt` to `TradeOffer` if not present
- [ ] **Backend** – Set expiry on create (e.g. 7 days), reject expired offers
- [ ] **UI** – Show "Expires in X days" or "Expired" on offer cards
- [ ] **Cron** – Job to auto-reject/close expired offers
- [ ] **Settings** – Optional configurable expiry (e.g. 3, 7, 14 days)

### 5.2 Offer withdrawal
- [x] **Backend** – `withdrawOffer` endpoint exists (`POST /v1/offers/:offerId/withdraw`)
- [x] **UI** – Withdraw on trade_screen, ExistingOfferNegotiationScreen, TradeOffersScreen
- [x] **ExistingOfferNegotiationScreen** – Withdraw button for sent offers
- [x] **trade_screen** – Withdraw button on sent pending offer cards
- [x] Confirmation dialog before withdraw

### 5.3 Offer history
- [ ] **Backend** – Endpoint for full offer history (including rejected/withdrawn)
- [ ] **UI** – "Offer history" section or tab showing all offers for a trade
- [ ] **ExistingOfferNegotiationScreen** – Expand timeline to show rejected/withdrawn
- [ ] Filter or toggle: "All" vs "Active only"

### 5.4 Optimistic updates
- [ ] On Accept – Update offer card immediately, revert on API error
- [ ] On Reject – Same pattern
- [ ] On Withdraw – Remove from list optimistically
- [ ] Use local state + `setState` before API call, rollback on failure
- [ ] Show toast on error with retry option

### 5.5 Offline support
- [ ] **Queue** – Store accept/reject/counter actions when offline
- [ ] **Sync** – Retry queued actions when back online
- [ ] **UI** – Indicate "Pending sync" for queued actions
- [ ] Consider `connectivity_plus` + local queue (e.g. Hive, SQLite)

---

## 6. Cash Offers & Escrow

### 6.1 Escrow status
- [ ] **Backend** – Expose escrow state (locked, released, returned) in offer/trade response
- [ ] **UI** – Show status: "Funds locked", "Funds released", "Funds returned"
- [ ] **Offer card** – Badge for cash offers: "In escrow"
- [ ] **ExistingOfferNegotiationScreen** – Escrow status section for cash offers

### 6.2 Payment timeline
- [ ] Add visual timeline for cash offers: Lock → Accept → Finalize → Transfer
- [ ] Show current step and completed steps
- [ ] Use stepper or timeline widget
- [ ] Include in `ExistingOfferNegotiationScreen` and offer cards

### 6.3 Refund flow
- [ ] **Backend** – Ensure refund on reject/cancel for cash offers
- [ ] **UI** – Message: "Funds will be returned to your wallet"
- [ ] **Status** – Show "Refunded" when applicable
- [ ] Optional: "Refund history" in wallet or offer details

---

## 7. Analytics & Feedback

### 7.1 Post-trade feedback
- [ ] **Backend** – Rating/review model and endpoints
- [ ] **Flow** – After trade finalized, prompt both parties to rate
- [ ] **UI** – Star rating + optional text review
- [ ] **Profile** – Display average rating and reviews
- [ ] Optional: Karma integration for completed trades

### 7.2 Offer analytics
- [ ] **Backend** – Aggregate stats: response time, acceptance rate per user
- [ ] **Profile** – "Trade stats" section (optional)
- [ ] **UI** – Simple stats: "You respond in ~X hours on average"

### 7.3 Abandonment tracking
- [ ] **Events** – Log: viewed offer, opened negotiation, sent message, accepted, rejected
- [ ] **Backend** – Analytics endpoint or integrate with existing analytics
- [ ] **Use** – Identify drop-off points (e.g. after view, before accept)
- [ ] Optional: in-app surveys at abandonment points

---

## 8. Accessibility & Localization

### 8.1 Screen reader support
- [ ] Add `Semantics` labels to offer cards (title, status, actions)
- [ ] Add `Semantics` to Accept/Reject/Negotiate buttons
- [ ] Ensure `ExcludeSemantics` / `MergeSemantics` where needed
- [ ] Test with TalkBack (Android) and VoiceOver (iOS)

### 8.2 Localization
- [ ] Extract all trade/offer strings to ARB or equivalent
- [ ] Keys for: status labels, buttons, empty states, errors
- [ ] Support at least one alternate locale (e.g. French, Spanish)
- [ ] Use `flutter_localizations` and `intl`

### 8.3 Haptic feedback
- [x] Add `HapticFeedback.lightImpact()` on: Accept, Reject, Send message
- [ ] Add `HapticFeedback.selectionClick()` on tab/button taps
- [ ] Use `HapticUtils` if project has it
- [ ] Respect system haptic settings

---

## 9. Edge Cases

### 9.1 Duplicate offer handling
- [x] **Backend** – Returns `existingOfferId` on duplicate
- [x] **Flutter** – `TradeBackendProvider.duplicateOfferId` set on duplicate
- [x] **UI** – `NegotiationScreen` shows dialog: "You already have a pending offer... View it?" with "View Offer" / "Stay"
- [x] Navigate to Offers tab when user taps "View Offer"
- [x] Flow consistent: NegotiationScreen (from trade details or elsewhere) handles duplicate, navigates to Offers tab

### 9.2 Concurrent edits
- [x] **Backend** – Optimistic locking or version check on accept/reject
- [x] **Error** – Handle 409 or "Offer no longer pending"
- [x] **UI** – "This offer was just accepted by the other party" message
- [x] Refresh offer state and navigate back or show updated status

### 9.3 Trade status changes
- [x] **Backend** – Reject accept/reject if trade is closed/cancelled
- [x] **Flutter** – Handle API error, show "Trade no longer available"
- [x] **Offers tab** – Filter out offers for closed/cancelled trades
- [x] **Deep link** – Graceful handling when opening offer for closed trade

### 9.4 Offer status mapping
- [x] Fix `TradeOffer.fromJson` status parsing – `_parseOfferStatus` normalizes underscores before comparing
- [x] Normalize: replace underscores before comparing
- [x] Ensure all backend statuses map to `OfferStatus` enum
- [x] Add unit test for status parsing

---

## 10. Quick Wins

### 10.1 Share trade
- [x] Share button on trade details screen (`_GlassButton` with `ShareUtils.shareTrade`)
- [x] Uses `share_plus` via `ShareSheet` / `ShareUtils.shareTrade`
- [x] Format: "Check out [title] on bYbata" + link
- [x] Ensure deep link works for unauthenticated (redirect to login)

### 10.2 Copy offer details
- [x] Add "Copy details" on offer card (trade_screen) and negotiation screen (ExistingOfferNegotiationScreen)
- [x] Copy to clipboard: trade titles, amounts, status
- [x] Use `Clipboard.setData` from `flutter/services.dart`
- [x] Show snackbar: "Copied to clipboard"

### 10.3 Keyboard shortcuts
- [x] **Web** – Add shortcuts: Enter to send, Escape to close
- [x] **Chat** – Enter = send, Shift+Enter = new line
- [x] **Negotiation** – Shortcuts for Accept (Ctrl+Enter) / Reject (Ctrl+Shift+Enter) when pending
- [x] Use `Shortcuts` and `Actions` widgets
- [ ] Document shortcuts in help or settings

---

## Implementation Order (Suggested)

1. **Offer status mapping** (9.4) – Fixes existing bugs (ACCEPTED_AWAITING_FINALIZATION parsing)
2. **Offer status badges** (1.1) – Improve labels (badges exist)
3. **Offer withdrawal UI** (5.2) – API exists; add withdraw button
4. **TradeOffersScreen pull-to-refresh** (1.3) – Quick win
5. **Offer notification routing** (3.1) – Route to negotiation when offerId present
6. **Inline chat** (2.1) – Major UX improvement
7. **Quick actions in chat** (2.4) – Faster workflow
8. **Empty states** (1.2) – Timeline empty state, illustrations
9. **Copy offer details** (10.2) – Low effort
10. **Escrow status** (6.1) – Trust for cash offers  

---

## Files to Modify (Reference)

| Feature | Primary Files |
|---------|---------------|
| Offer cards, badges | `lib/features/trade/screens/trade_screen.dart` |
| Existing negotiation | `lib/features/trade/screens/existing_offer_negotiation_screen.dart` |
| Chat | `lib/features/trade/screens/trade_chat_screen.dart` |
| Negotiation form | `lib/features/trade/screens/negotiation_screen.dart` |
| Trade details | `lib/features/trade/screens/trade_details_screen.dart`, `trade_details_loader.dart` |
| Models | `lib/features/trade/models/trade_models.dart` |
| Backend offers | `apps/api/src/trades/trades.service.ts`, `trades.controller.ts` |
| Notifications | `apps/api/src/notifications/`, `lib/features/notifications/` |
| Schema | `apps/api/prisma/schema.prisma` |
