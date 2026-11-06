/*
 Minimal PayPal webhook E2E test

 What it does:
 - Seeds a test user and FundingIntent (USD) in the DB
 - Ensures a BYC/USD conversion rate exists
 - Posts a PayPal PAYMENT.CAPTURE.COMPLETED webhook to the API
 - Verifies wallet credit and idempotency by re-posting the same webhook

 Requirements:
 - API server running locally (default http://localhost:3003)
 - Env: PAYPAL_WEBHOOK_ID, PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET, PAYPAL_ENV=sandbox
 - Env: DATABASE_URL set, or prisma/.env available

 Run: node apps/api/scripts/paypal_webhook_test.js
 Optional env: API_PORT=3003, TEST_RATE_USD=1.0, TEST_AMOUNT_USD=25.5
*/

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Load DATABASE_URL from prisma/.env if not set
if (!process.env.DATABASE_URL) {
  const envPath = path.resolve(__dirname, '../prisma/.env');
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, 'utf8');
    for (const line of content.split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+?)\s*$/);
      if (m) {
        const key = m[1];
        let val = m[2];
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.slice(1, -1);
        }
        if (!process.env[key]) process.env[key] = val;
      }
    }
  }
}

const REQ_ENV = ['PAYPAL_WEBHOOK_ID', 'PAYPAL_CLIENT_ID', 'PAYPAL_CLIENT_SECRET'];
for (const k of REQ_ENV) {
  if (!process.env[k]) {
    console.error(`ERROR: Set ${k} before running.`);
    process.exit(1);
  }
}
process.env.PAYPAL_ENV = process.env.PAYPAL_ENV || 'sandbox';

const API_PORT = Number(process.env.API_PORT || process.env.PORT || 3003);
const TEST_RATE_USD = Number(process.env.TEST_RATE_USD || 1.0);
const TEST_AMOUNT_USD = Number(process.env.TEST_AMOUNT_USD || 25.5);

async function main() {
  const { PrismaClient } = require('@prisma/client');
  const prisma = new PrismaClient();
  try {
    // 1) Ensure user exists
    const email = 'paypal-webhook-test@bybata.local';
    let user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      user = await prisma.user.create({ data: { email, passwordHash: 'x' } });
      console.log(`Created test user ${user.id}`);
    } else {
      console.log(`Using existing test user ${user.id}`);
    }

    // 2) Ensure conversion rate BYC/USD exists and active
    await prisma.conversionRate.updateMany({ where: { base: 'BYC', quote: 'USD', active: true }, data: { active: false } });
    const rate = await prisma.conversionRate.create({ data: { base: 'BYC', quote: 'USD', rate: TEST_RATE_USD, active: true } });
    console.log(`Active rate set BYC/USD=${rate.rate}`);

    // 3) Seed FundingIntent (PENDING)
    const intentReference = 'fi_' + crypto.randomBytes(6).toString('hex');
    const amountMinor = Math.round(TEST_AMOUNT_USD * 100); // cents equivalent
    const intent = await prisma.fundingIntent.create({
      data: {
        userId: user.id,
        provider: 'paypal',
        currency: 'USD',
        amountMinor,
        status: 'PENDING',
        intentReference,
      },
    });
    console.log(`Seeded FundingIntent intentReference=${intent.intentReference}`);

    // 4) Read starting balance
    const accStart = await prisma.account.findUnique({ where: { userId: user.id } });
    const startBal = accStart ? Number(accStart.balance) : 0;
    console.log(`Starting balance=${startBal}`);

    // 5) Build webhook payload
    const providerReference = 'PP-' + crypto.randomBytes(6).toString('hex');
    const payload = {
      id: 'WH-' + crypto.randomBytes(6).toString('hex'),
      event_type: 'PAYMENT.CAPTURE.COMPLETED',
      resource: {
        id: providerReference,
        amount: { currency_code: 'USD', value: String(TEST_AMOUNT_USD) },
        status: 'COMPLETED',
        custom_id: intentReference,
      },
    };
    const raw = JSON.stringify(payload);

    // PayPal verification uses headers; these are placeholders read by server-side verify
    const headers = {
      'Content-Type': 'application/json',
      'paypal-transmission-id': 'test-transmission-id',
      'paypal-transmission-time': new Date().toISOString(),
      'paypal-cert-url': 'https://api-m.sandbox.paypal.com/certs/test',
      'paypal-auth-algo': 'SHA256withRSA',
      'paypal-transmission-sig': 'test-signature',
    };

    // 6) POST webhook
  const res1 = await postJson(`/v1/wallet/webhooks/paypal`, raw, headers);
  console.log('Webhook #1 response:', res1.statusCode, res1.body);
  if (res1.statusCode !== 200) {
    console.error('FAIL: Expected 200 for first webhook');
    process.exit(2);
  }

    // 7) Check balance after credit
    const accAfter1 = await prisma.account.findUnique({ where: { userId: user.id } });
    const after1Bal = accAfter1 ? Number(accAfter1.balance) : 0;
    console.log(`Balance after #1=${after1Bal}`);

    // 8) Re-post same webhook to verify idempotency
  const res2 = await postJson(`/v1/wallet/webhooks/paypal`, raw, headers);
  console.log('Webhook #2 response:', res2.statusCode, res2.body);
  if (res2.statusCode !== 200) {
    console.error('FAIL: Expected 200 for second webhook (idempotency)');
    process.exit(2);
  }

    const accAfter2 = await prisma.account.findUnique({ where: { userId: user.id } });
    const after2Bal = accAfter2 ? Number(accAfter2.balance) : 0;
    console.log(`Balance after #2=${after2Bal}`);

    const delta = after1Bal - startBal;
    const delta2 = after2Bal - after1Bal;
    const expectedByc = TEST_AMOUNT_USD / TEST_RATE_USD;

    console.log('Expected BYC credit:', expectedByc);
    console.log('Observed delta #1:', delta);
    console.log('Observed delta #2 (should be 0):', delta2);

  if (Math.abs(delta - expectedByc) < 1e-6 && Math.abs(delta2) < 1e-6) {
    console.log('SUCCESS: Credit matches expected and webhook is idempotent.');
  } else {
    console.error('FAIL: Unexpected balance deltas.');
    process.exit(2);
  }

  // 9) Send a failure event and assert no additional credit
  const failProviderReference = providerReference;
  const failPayload = {
    id: 'WH-' + crypto.randomBytes(6).toString('hex'),
    event_type: 'PAYMENT.CAPTURE.DENIED',
    resource: {
      id: failProviderReference,
      amount: { currency_code: 'USD', value: String(TEST_AMOUNT_USD) },
      status: 'DENIED',
      custom_id: intentReference,
    },
  };
  const failRaw = JSON.stringify(failPayload);
  const resFail = await postJson(`/v1/wallet/webhooks/paypal`, failRaw, headers);
  console.log('Failure webhook response:', resFail.statusCode, resFail.body);
  if (resFail.statusCode !== 200) {
    console.error('FAIL: Expected 200 for failure webhook');
    process.exit(2);
  }
  const accAfterFail = await prisma.account.findUnique({ where: { userId: user.id } });
  const afterFailBal = accAfterFail ? Number(accAfterFail.balance) : 0;
  const deltaFail = afterFailBal - after2Bal;
  console.log('Observed delta after failure event (should be 0):', deltaFail);
  if (Math.abs(deltaFail) < 1e-6) {
    console.log('SUCCESS: Failure event produced no credit.');
    process.exit(0);
  } else {
    console.error('FAIL: Failure event changed balance unexpectedly.');
    process.exit(2);
  }
    } else {
      console.error('FAIL: Unexpected balance deltas.');
      process.exit(2);
    }
  } catch (e) {
    console.error('ERROR:', e);
    process.exit(1);
  } finally {
    try { await prisma.$disconnect(); } catch {}
  }
}

function postJson(pathname, rawBody, headers) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: 'localhost',
      port: API_PORT,
      path: pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(rawBody),
        ...headers,
      },
    };
    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve({ statusCode: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.write(rawBody);
    req.end();
  });
}

main();