---
name: Week 2 — Wallet/BYC Core
about: Implement BYC accounts, transactions, funding/sending, conversion rates, promotions
title: "Week 2: Wallet/BYC Core"
labels: ["epic","week-2"]
assignees: []
---

Goals
- Usable wallet: view balance, fund, send/receive, history; admin controls for rates/promotions.

Tasks
- API
  - [ ] Models: Account, Transaction, ConversionRate, Promotion.
  - [ ] GET /v1/wallet, GET /v1/wallet/transactions.
  - [ ] POST /v1/wallet/fund, /send with idempotency and atomic debit/credit.
  - [ ] GET /v1/wallet/conversion-rates, /promotions; admin CRUD for both.
- Mobile
  - [ ] Wire BYCWalletScreen, FundWallet, Send/Receive (QR payload), TransactionHistory, PromotionCenter, Conversion.
- Admin
  - [ ] Wallet admin: list transactions; manage rates/promotions.
- Infra/CI
  - [ ] Add DB indexes on (accountId, createdAt); add idempotency key support.

Deliverables
- End-to-end wallet flows + admin management.

Acceptance criteria
- [ ] Send debits sender, credits receiver in a single transaction; ledger invariant holds.
- [ ] Transactions list paginates; balance reflects ops immediately.
- [ ] Conversion rates and promotions retrievable and editable by admin.
