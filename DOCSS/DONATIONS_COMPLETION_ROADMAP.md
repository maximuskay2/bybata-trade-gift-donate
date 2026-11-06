# Donations Roadmap and Completion Estimate

## Completion Estimate
- Core Features: ~85% complete (CRUD, listing, basic donation flow)
- Wallet (BYC) Donations: 20% (wallet structure exists, no coin debit/ledger yet)
- Advanced Features: 30% (models exist, implementation missing)
- Chat Integration: 0% (can leverage existing system easily)
- Real-Time: 10% (infrastructure exists, needs wiring)

## Next Recommended Implementations
- Wallet-based BYC coin donations (highest priority - app-native, no external gateway at donation time)
- Wallet top-up integrations (Stripe, Paystack, PayPal, Flutterwave) to fund BYC balance
- Chat integration (easy win, reuse existing chat system)
- Campaign updates system (keep donors engaged)
- Reward tier backend (enable crowdfunding perks)
- Real-time donation notifications (enhance UX)
- Analytics dashboard (for campaign creators) — do not start yet (pending your confirmation)

---

## Phase 1: Make Donations Functional (Highest Priority)
### Wallet-Based Donation Flow (BYC Coin)
- Wallet balance check and authorization (PIN/biometric if available)
- Backend: create donation transaction, debit BYC from wallet, attach to campaign
- Ledger: record immutable entries (debit donor, credit campaign wallet/escrow)
- Frontend: wallet donation sheet; pass `campaignId`, amount; show balance and top-up CTA
- Events: emit donation.updated for real-time; award karma on success
- Insufficient balance: open top-up options (Stripe, Paystack, PayPal, Flutterwave) to add BYC
- Refunds: optional admin flow converts refunded donations back to BYC wallet

### Acceptance Criteria
- Users donate end-to-end using BYC balance with a donation record
- Wallet debit and ledger entries are consistent; campaign progress updates immediately
- Clear errors for insufficient balance; top-up path works; no external gateway during donation

---

## Phase 2: Chat Integration (Easy Win)
- Use existing floating chat screen at `/lib/features/chat/screens/chat_list_screen.dart`
- Chat list already has "Donation" filter tab alongside Trade, Gifting, Community
- UI: add chat button on campaign cards/details in donation screens
- Start contextual DM via `ChatProvider.startDirectMessage` with campaign title and ID
- Open `ChatScreen` using `ChatType.donation` (already defined)
- Conversations automatically appear in "Donation" tab of chat list

### Acceptance Criteria
- Donor and campaign owner can message from campaign view
- Chat carries campaign context consistently on both sides
- Donation conversations appear in the Donation filter tab of existing chat screen

---

## Phase 3: Campaign Updates System
- Backend: add `CampaignUpdate` model; endpoints to post and list updates
- Frontend: update composer for owners; updates feed on campaign details
- Notifications: alert donors on new updates

### Acceptance Criteria
- Owners publish updates; donors see a feed and get notified
- Updates are paginated and cached

---

## Phase 4: Reward Tiers Backend
- Models: `RewardTier` and `DonationReward` (fulfillment status)
- API: manage tiers, attach tier to donation, track fulfillment
- UI: show tiers in campaign; donor selects during payment; fulfillment tracking

### Acceptance Criteria
- Donors select tiers at checkout; campaign owner tracks fulfillment
- Physical reward workflow optional (shipping/delivery states)

---

## Phase 5: Real-Time Donation Notifications
- WebSocket events: `donation.created` / `donation.updated`
- Provider: subscribe; update progress/supporter count; show live toasts
- UI: live progress bar; recent donors list

### Acceptance Criteria
- Live updates visible without refresh on campaign pages
- Stable with multiple simultaneous donors

---

## Phase 6: Analytics Dashboard (Deferred — Awaiting Your Go-Ahead)
- Backend: campaign analytics endpoint (daily totals, conversion, sources)
- Frontend: dashboard for creators; charts and trends
- Export: CSV/PDF for founders

### Acceptance Criteria
- Owners view donation analytics over selectable ranges
- Export matches on-screen data reliably

---

## Dependencies and Sequencing
- Wallet-based BYC donations precede reward tiers and real-time (events depend on confirmed BYC debits); top-up providers are used only to fund wallets
- Chat integration is independent — can ship right after Phase 1 if preferred
- Campaign updates are independent — can ship in parallel with chat
- Analytics last, leveraging data from previous phases

---

## Effort Estimates (High-Level)
- Phase 1: 3–5 days (backend + frontend + webhook + QA)
- Phase 2: 0.5–1 day (UI wiring + provider calls + tests)
- Phase 3: 2–3 days (model, API, UI, notifications)
- Phase 4: 3–4 days (model, API, checkout changes, fulfillment UI)
- Phase 5: 1.5–2.5 days (events, provider wiring, UI polish)
- Phase 6: 2–4 days (aggregation, charts, exports)

---

## Acceptance Test Checklist
- Wallet: BYC debit succeeds; ledger entries correct; donation appears in history; progress updates
- Chat: opens from campaign view; conversation persists; context correct
- Updates: owner posts; donors see; notifications delivered
- Rewards: tier selection at checkout; attached to donation; fulfillment states updated
- Real-time: live progress increments with multiple donations; event throttling stable
- Analytics: correct totals across date ranges; export matches on-screen data

---

## Wallet System Design & Finalization Roadmap

Scope and use cases
- BYC wallet powers: Trade promotions, P2P wallet funding (send/receive), Donations, Ad purchases, and future community boosts.
- BYC coin is the only medium for internal spends; external gateways (Stripe, Paystack, PayPal, Flutterwave) are used solely to top up BYC balances.
- Admin-controlled conversion rates: Admin can set 1 BYC ↔ USD/NGN via `AdminRatesController`; clients fetch latest active rates from `/v1/wallet/conversion-rates`.

Design pillars
- Ledger integrity: `walletTransaction` has immutable entries with `type` (FUND, SEND, RECEIVE, PROMOTION, DONATION, ADVERT, REFUND, BONUS, CASHBACK), `status`, `idempotencyKey`, `referenceType` (trade, campaign, advert), `referenceId`, and `metadata`.
- Accounts and escrow: Each user has an `account`. Optional escrow accounts for campaigns/ads to support delayed disbursements.
- Dynamic rates: `conversionRate` supports multiple quotes (USD, NGN). Exactly one active per base/quote. Clients select preferred currency and compute BYC estimates dynamically.
- Security: PIN/biometric confirmation for SEND and purchases, per-user limits, idempotent operations.

Phase 1: Backend completeness
- Prisma/schema: add `referenceType`, `referenceId`, `metadata`, `status` to `walletTransaction`; unique index on `idempotencyKey`.
- Services:
  - `WalletService.send` in donations (already planned) to debit BYC from donor → founder/escrow before creating `donation`.
  - Add endpoints/methods for trade promotion purchase (`PROMOTION`) and advert purchase (`ADVERT`) that debit BYC and create domain records.
  - Implement refunds flow (optional) writing `REFUND` transactions and reversing balances safely.
- Admin rates: when creating a new active rate, automatically deactivate any previously active rate for the same base/quote; provide toggle endpoint.
- Filtering and pagination: expand list endpoints to filter by `type`, `status`, `referenceType`, date ranges.

Phase 2: Frontend integration
- `WalletProvider`: replace mocks with `/v1/wallet` and `/v1/wallet/transactions`; fetch rates; expose BYC↔USD/NGN conversions dynamically.
- Funding flows: enable `PaymentManager.initialize` with real gateway configs; compute "You'll Receive" BYC from latest admin rate; call backend funding endpoints; on webhook success, refresh wallet.
- Trade promotions: add purchase UI on trade screens; call promotion API; reflect boosts/badges immediately after BYC debit.
- Donations: use BYC wallet (no gateway during donation); show insufficient balance CTA → open funding flow and retry.
- Adverts: purchase UI; debit BYC and create advert record; reflect ad placement and schedule.
- P2P transfer: send BYC by userId/email; success states and notifications.

Phase 3: Gateways + webhooks (top-ups only)
- Implement gateway endpoints (create/verify) and webhooks; verify payment and call `wallet.fund` with idempotency keys; persist gateway refs/metadata in transactions.

Phase 4: Real-time and notifications
- Emit `wallet.transaction.created|updated`, `promotion.purchased`, `donation.created`, `advert.purchased` events.
- Providers subscribe to sockets; update balances, progress bars, badges; toast notifications for success.

Phase 5: Security & compliance
- PIN/biometric prompts for SEND and purchases; configurable daily/monthly limits; anti-fraud checks (velocity, anomalies); robust idempotency.

Phase 6: Admin & analytics
- Admin views for wallet transactions with filters and CSV export; rate audit history and active toggles.
- Creator analytics: BYC spend summaries across promotions/ads; donors’ BYC contributions.

Acceptance criteria
- BYC donation debits wallet and records immutable ledger; campaign progress updates immediately.
- Trade promotion and advert purchases debit BYC, create domain records, and reflect boosts/placements in UI.
- P2P transfers succeed with PIN/biometric; recipients see `RECEIVE` transactions instantly.
- Funding shows dynamic BYC estimates based on admin rates; webhooks idempotently credit wallet.
- Real-time events update UI without refresh; admin can change rates and clients reflect instantly.

Effort estimates
- Phase 1 (backend): 3–5 days
- Phase 2 (frontend): 3–4 days
- Phase 3 (gateways/webhooks): 2–3 days
- Phase 4 (real-time): 1–2 days
- Phase 5 (security): 1–2 days
- Phase 6 (admin/analytics): 2–3 days





