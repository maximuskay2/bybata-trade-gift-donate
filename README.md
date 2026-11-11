# Bybata

Trade, gift, and donate. This README covers the PayPal fair-trade top-up.

When two items in a trade are not worth the same, Bybata suggests a cash top-up, both people accept or counter it, and the difference is paid and refunded with PayPal. Gift and donate stay free.

## Run the API

```bash
cd apps/api
cp .env.example .env
```

Set `DATABASE_URL`. For a real sandbox payment set `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`, `PAYPAL_ENV=sandbox`, and `PAYPAL_WEBHOOK_ID`. Leave `OPENAI_API_KEY` empty to use the built-in category price bands. Set it on the server only when you want the model to write the reason.

To walk through checkout without PayPal keys, set `PAYPAL_DEMO_MODE=1`. That mode is ignored once PayPal keys are present.

```bash
npx prisma migrate deploy
npx prisma generate
npm run seed:paypal-ai
npm run start:dev
```

The seed prints two logins. The password is `DemoTrade123!`.

- `paypal-demo-owner@bybata.test` lists a MacBook.
- `paypal-demo-bidder@bybata.test` offers a paperback set for it.

## Run the app

From the repo root, point the app at the API and run Flutter:

```bash
flutter run
```

Sign in as the bidder, open the offer, and tap **Even this trade**. Sign in as the owner on another session and accept the same amount. The bidder pays with PayPal. Cancel the trade, reject the offer, or send a dispute to refund a captured top-up. The trade screen shows **Refunded** after PayPal confirms it.

## Hosted demo

Deploy `apps/api` to Railway (or any host) and set these server variables. Do not put the values in git.

- `DATABASE_URL`
- `PAYPAL_CLIENT_ID`
- `PAYPAL_CLIENT_SECRET`
- `PAYPAL_ENV=sandbox`
- `PAYPAL_WEBHOOK_ID`
- `OPENAI_API_KEY` (optional)
- `API_PUBLIC_BASE_URL` as the public API origin, so PayPal can redirect back to `/v1/trade-topups/paypal/return` (`API_PUBLIC_URL` still works as an override; on Railway the service's public domain is used if neither is set)

Point the PayPal sandbox webhook at `https://<api-host>/v1/trade-topups/paypal/webhook` for `PAYMENT.CAPTURE.COMPLETED` and `PAYMENT.CAPTURE.REFUNDED`.

## Demo video

Record the under-3-minute walkthrough in [docs/DEMO-PAYPAL-AI.md](docs/DEMO-PAYPAL-AI.md). The shot list is the submission script. Upload that recording to YouTube when you submit.

## Before a push

```bash
bash scripts/secrets-scan.sh
```

The scan checks for pasted private-key blocks. The release keystore, database backup, and API env files stay in this private repo.
