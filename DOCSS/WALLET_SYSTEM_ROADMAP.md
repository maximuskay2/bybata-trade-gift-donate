# Wallet System Roadmap and Implementation Guide

This document outlines a pragmatic, end-to-end plan to implement the wallet system across the Flutter app and NestJS API, fulfilling funding, BYC transfers, admin management, security, testing, and monitoring requirements.

## Overview
- Goals: Enable funding, BYC peer transfers, real-time UI updates, admin rate management, audit trails, and robust security.
- Stack: Flutter client (`lib/features/wallet`), NestJS API (`apps/api`), Prisma ORM, Paystack (NGN), Stripe (USD), PayPal (USD).
- Core Principles: Idempotent operations, atomic balance updates, strong authentication/authorization, structured logging, sandbox-first integrations.

## Architecture
- Backend Modules:
  - `wallet`: balance, transactions, rates, transfers
  - `payments`: funding flows, callbacks, webhooks (Paystack/Stripe/PayPal)
  - `admin`: rate management, admin credits, audits, analytics
  - `notifications`: in-app/push/email alerts
  - `security`: rate limiting, fraud checks, correlation IDs, role guards
- Frontend (Flutter):
  - Providers/services for wallet operations and live updates
  - Screens: fund wallet, transfer BYC, transaction history, wallet overview
  - Real-time: optimistic UI on transfer; reconcile with server/webhook updates

## Backend APIs
- Funding
  - `POST /wallet/fund/paystack/create` → returns `authorizationUrl`, `reference`
  - `POST /wallet/fund/stripe/create` → returns `clientSecret`, `paymentIntentId`
  - `POST /wallet/fund/paypal/create` → returns `orderId`, `approveLink`
  - Webhooks: `POST /wallet/webhooks/paystack|stripe|paypal` → verifies, credits wallet, logs transaction
- Wallet & Transfers
  - `GET /wallet/balance` → BYC balance and fiat equivalents (latest rates)
  - `GET /wallet/transactions` → paginated history (funding|transfer|donation)
  - `POST /wallet/transfer` → P2P BYC transfer with PIN/2FA, idempotency key
  - `GET /wallet/rates` → current BYC↔NGN, BYC↔USD rates
- Admin
  - `POST /admin/wallet/rates` → set/update conversion rates (audited)
  - `POST /admin/wallet/credit` → credit BYC to user wallet (audited)
  - `GET /admin/wallet/audit` → audit trail listing and filters
  - `GET /admin/wallet/analytics` → volumes per gateway, failures, suspicious flags

## Data Models (Prisma)
- `Wallet { id, userId, balanceByc, updatedAt }`
- `Transaction { id, userId, type (FUNDING|TRANSFER|DONATION), amountByc, amountFiat, fiatCurrency, status, gateway, reference, metadata, createdAt }`
- `ConversionRate { id, bycToNgn, bycToUsd, source, validFrom, validTo, createdBy, createdAt }`
- `AdminActionAudit { id, adminId, action, targetUserId, details, createdAt }`
- `Transfer { id, senderId, recipientId, amountByc, status, confirmationCode, createdAt }`
- `WebhookEvent { id, gateway, rawPayload, verified, processed, reference, createdAt }`
- Indexes: `(userId, createdAt)`, `(reference)`, `(validTo)`; use DB transactions for atomic updates.

## Payment Integrations
- Paystack (NGN):
  - Initialize via `transaction/initialize` → authorization URL; handle callback and webhook
  - Verify with server-side secret; match `reference` and exact `amount`
  - BYC credit: `creditedByc = amountNgn / bycToNgn` (rounding rules)
- Stripe (USD):
  - Create PaymentIntent; client handles card UI
  - Webhook `payment_intent.succeeded` → `creditedByc = amountUsd / bycToUsd`
- PayPal (USD):
  - Create Order; approve + capture; process webhook
  - BYC credit via USD rate on capture
- Common:
  - Idempotency per funding request; avoid double-credit
  - Store gateway fees for analytics; do not subtract from credited BYC unless specified

## BYC Transfers
- Validation: balance check, minimum amount, daily limits, recipient eligibility
- Confirmation: PIN/2FA via `wallet_security_service`, optional memo
- Atomic debit/credit in a DB transaction; create two `Transaction` rows and one `Transfer` row
- Notifications: sender and recipient alerts; in-app + optional email

## Admin Dashboard (apps/admin)
- Conversion Rates: edit BYC→NGN and BYC→USD, source, validity window
- Wallet Credit: select user, amount, memo, confirmation prompts
- Audits: filtered list and export; actions include rate updates, credits
- Analytics: gateway breakdowns, fees, failure rates, suspicious transactions

## Security
- AuthN/Z: JWT with role-based guards; admin routes require `ADMIN`
- Rate Limiting: per-user limits on funding and transfers
- Fraud Detection:
  - Velocity checks (transactions per time window)
  - Large-amount thresholds with alerts
  - Recipient blacklists/whitelists
- Encryption & Logging:
  - Secure handling of webhook payloads; redact PII in logs
  - Structured logs (Winston) with correlation IDs

## Flutter UI
- Wallet Overview: BYC balance and fiat equivalents, real-time refresh
- Funding Screens: Paystack (NGN), Stripe/PayPal (USD), show live conversion and final BYC
- Transfer Screen: recipient lookup, amount entry, PIN/2FA confirmation, success state
- Transactions: filterable history with statuses (pending|succeeded|failed)
- Real-time Updates: optimistic UI for transfers and polling/websocket reconciliation after webhooks

## Error Handling
- User-friendly messaging for declines, network issues, webhook delays
- Retry on transient failures; reconciliation job for missed webhooks
- Clear status indicators; actionable recovery steps

## Testing
- Unit: conversion utilities, validation rules, balance updates
- Integration: funding flows (mock gateways), webhook verification, atomic transfers
- Sandbox: Paystack test keys, Stripe test mode, PayPal sandbox
- Edge Cases: insufficient balance, duplicate webhooks, idempotency conflicts, extreme rates
- Security: rate-limit bypass attempts, injection, webhook signature forgery, replay attacks

## Monitoring & Alerts
- Dashboards: transaction volumes, gateway failures, processing latency
- Alerts: email/Slack on rate changes, high-value funding, repeated failures, anomalies
- Reports: scheduled audit exports for admins

## Documentation
- API Reference: endpoints, auth, payloads, examples, error codes, retry semantics
- Admin Guide: rate management, crediting wallets, reading audits and analytics
- Frontend Guide: providers/services usage, handling webhook-driven updates

## Implementation Phases
1) Foundations
   - Define Prisma models and migrations
   - Configure env: `PAYSTACK_SECRET`, `STRIPE_SECRET`, `PAYPAL_CLIENT_ID`, `PAYPAL_SECRET`, `APP_PUBLIC_URL`
   - Scaffold NestJS modules: `wallet`, `payments`, `admin`, `webhooks`
2) Conversion Rates & Balance
   - `GET/POST /wallet/rates`, cache current rates
   - `GET /wallet/balance` with fiat equivalents
3) Funding (Paystack)
   - Init, callback, webhook verification, credit wallet
   - Flutter NGN funding UI; sandbox verification
4) Funding (Stripe & PayPal)
   - PaymentIntent/order creation, webhook handlers
   - Flutter USD funding UI; sandbox verification
5) BYC Transfers
   - Transfer endpoint, atomic debit/credit, PIN/2FA
   - UI for transfers and notifications
6) Transactions & Notifications
   - History pagination and filters
   - Notification dispatch and UI badges
7) Admin Dashboard
   - Rate management, wallet credit, audits, analytics pages
8) Security & Monitoring
   - Rate limiting, fraud rules, structured logging, alerts
9) Testing & Docs
   - Unit and integration tests, performance checks, full documentation

## Key Payload Examples
- Create Paystack Funding
  - `POST /wallet/fund/paystack/create { amountNgn: 5000, returnUrl: "https://..." }`
  - Response: `{ authorizationUrl, reference }`
- Webhook Processing (normalized)
  - `{ gateway: "paystack", reference, paidAmount: 5000, currency: "NGN", status: "success" }`
- Transfer
  - `POST /wallet/transfer { toUserId, amountByc, memo, idempotencyKey }`

## Environment Variables
- `PAYSTACK_SECRET`, `STRIPE_SECRET`
- `PAYPAL_CLIENT_ID`, `PAYPAL_SECRET`
- `APP_PUBLIC_URL` (for redirects/webhooks), `JWT_SECRET`
- Optional: `LOG_LEVEL`, `ALERT_WEBHOOK_URL`

## Notes & Assumptions
- Conversion rates are dynamically configurable via admin dashboard and applied consistently across gateways.
- Accurate audit trails maintained for all admin actions and rate changes.
- Funding credits are idempotent and only processed after verified webhook events.

## Next Steps
- Approve data models and endpoints.
- Implement Phase 1 (`/wallet/rates`, `/wallet/balance`) and scaffold modules.
- Proceed with Paystack integration in sandbox, then Stripe/PayPal.





Implement a unified chat system architecture that applies the existing donation chat logic to trade, gift, and community modules with the following specifications:

1. Modular Chat Tabs Implementation:
   - use dedicated chat tabs for each module (Trade, Gift, Community) in the chat screen
   - Ensure each tab maintains isolated conversation threads specific to its module context

2. Trade Module Chat:
   - Design the Trade tab to handle all trade negotiations
   - Implement proposal and counter-proposal functionality with structured message formatting
   - Include trade-specific UI elements (price displays, item conditions, etc.) within the chat interface

3. Gift Module Chat:
   - Configure the Gift tab to manage all gift-related messaging
   - Link messaging initiated from the gifting screen directly to the Gift chat tab
   - Implement gift-specific features (wishlist integration, gift status tracking)

4. Community Module Chat:
   - Build the Community tab for individual-to-individual community interactions
   - Ensure seamless transition from community screens to the dedicated chat tab
   - Include community-specific context preservation

5. Technical Requirements:
   - Develop a shared backend architecture that supports module-specific conversation segregation
   - Implement proper message routing logic based on origin module
   - Ensure all chat tabs maintain consistent UI/UX patterns while displaying module-specific elements
   - Include proper state management to preserve chat context when switching between tabs

6. Testing Requirements:
   - Verify message isolation between different module tabs
   - Test module-specific features within each chat context
   - Validate proper tab switching behavior and state persistence
   - Conduct performance testing with multiple concurrent conversations across modules

7. Success Criteria:
   - Users can clearly distinguish between different conversation contexts
   - All module-specific chat features function as expected
   - The system maintains conversation history appropriately for each module
   - Performance remains consistent across all chat tabs

   Images are stored as local file paths and sent in mediaKeys as placeholders. When you add server upload, replace file paths with returned storage keys.