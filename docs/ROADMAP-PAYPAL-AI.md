# Bybata [Trade | Gift | Donate]: PayPal + AI Roadmap

Planned work for the PayPal AI Hackathon. Built by Maximusinfotech Services.

## Goal
Make uneven barter trades fair. When two items in a trade are not worth the same, an AI assistant suggests a fair cash top-up, explains why, and the difference is paid and refunded through PayPal.

## Phase 1: PayPal foundation (backend, NestJS + Prisma)
- Add a PayPal module with OAuth token caching (sandbox first, live later via `PAYPAL_ENV`).
- Orders v2: create order for a trade top-up, capture on buyer approval.
- Payments v2: refund a captured top-up when a trade is cancelled or disputed.
- Webhooks: verify signatures and handle `PAYMENT.CAPTURE.COMPLETED` and `PAYMENT.CAPTURE.REFUNDED`.
- Prisma: new `TradeTopUp` model (tradeId, payerId, amount, currency, paypalOrderId, captureId, status, aiReason).
- Env placeholders only in `.env.example`: `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`, `PAYPAL_ENV`, `PAYPAL_WEBHOOK_ID`.

## Phase 2: AI fair-value assistant
- Endpoint that takes both sides of a trade (titles, condition, photos, category) and returns a suggested top-up amount, payer, and a plain-language reason.
- Uses an LLM via `OPENAI_API_KEY` stored only on the server, never in the repo or app.
- Deterministic fallback (category price bands) when no AI key is set, so judges can run it.
- Guardrails: cap suggestions, show confidence, let both users accept, counter, or decline.

## Phase 3: App flow (Flutter)
- "Even this trade" button on a trade offer.
- AI suggestion card with amount and reason.
- PayPal checkout (approval link or PayPal SDK), then success state on the trade.
- Refund status on cancelled trades.
- Gift and Donate modes stay free; top-up only applies to Trade.

## Phase 4: Demo and submission
- Seeded demo trades in sandbox, USD.
- Hosted demo (Railway or similar) with sandbox keys set as server variables.
- Under 3 minute YouTube video: list item, make uneven offer, AI suggests top-up, PayPal pay, cancel and refund.
- README section with run steps.

## Security rules
- No keys, keystores, env files, or database dumps in this repo.
- Run a secrets scan before every push.
