/*
  Verification script: ensures a user with a pending claim cannot claim
  another gift until the pending claim is resolved.

  Flow:
  - Register Carol (giver) and Alice (claimer)
  - Carol creates two gifts (G1 and G2)
  - Alice claims G1 -> PENDING
  - Alice attempts to claim G2 -> expect 400 error with blocking message
*/

import 'dotenv/config';

const BASE = `http://${process.env.HOST ?? 'localhost'}:${process.env.PORT ?? 3000}/v1`;

type TokenPair = { accessToken: string; refreshToken: string };

async function post(path: string, body: any, token?: string) {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body ?? {}),
  });
  const text = await res.text();
  let json: any;
  try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  return { status: res.status, ok: res.ok, json };
}

async function register(email: string, password: string, displayName: string) {
  const r = await post('/auth/register', { email, password, displayName });
  if (!r.ok) throw new Error(`Failed to register ${email}: ${r.status} ${JSON.stringify(r.json)}`);
  return r.json as { user: any } & TokenPair;
}

async function login(email: string, password: string) {
  const r = await post('/auth/login', { email, password });
  if (!r.ok) throw new Error(`Failed to login ${email}: ${r.status} ${JSON.stringify(r.json)}`);
  return r.json as { user: any } & TokenPair;
}

async function createGift(token: string, title: string) {
  const r = await post('/gifts', { title, description: 'Verification gift', maxClaims: 1, karmaReward: 10 }, token);
  if (!r.ok) throw new Error(`Failed to create gift: ${r.status} ${JSON.stringify(r.json)}`);
  return r.json as any; // gift object
}

async function claimGift(token: string, giftId: string) {
  const r = await post(`/gifts/${giftId}/claim`, {}, token);
  return r; // expect ok or 400 error
}

async function main() {
  const ts = Date.now();
  const carolEmail = `carol+${ts}@example.com`;
  const aliceEmail = `alice+${ts}@example.com`;
  const password = 'Passw0rd!'

  console.log('Registering Carol and Alice...');
  await register(carolEmail, password, 'Carol');
  await register(aliceEmail, password, 'Alice');

  const carol = await login(carolEmail, password);
  const alice = await login(aliceEmail, password);

  console.log('Creating two gifts under Carol...');
  const g1 = await createGift(carol.accessToken, 'G1: First Gift');
  const g2 = await createGift(carol.accessToken, 'G2: Second Gift');

  console.log('Alice claims G1 (should succeed, PENDING)...');
  const c1 = await claimGift(alice.accessToken, g1.id);
  if (!c1.ok) throw new Error(`Initial claim failed unexpectedly: ${c1.status} ${JSON.stringify(c1.json)}`);
  console.log('-> Claim 1 ok:', c1.json);

  console.log('Alice attempts to claim G2 (should be blocked)...');
  const c2 = await claimGift(alice.accessToken, g2.id);
  if (c2.ok) {
    console.error('ERROR: Second claim unexpectedly succeeded:', c2.json);
    process.exitCode = 1;
    return;
  }
  console.log('-> Claim 2 blocked as expected:', c2.status, c2.json);
  if (c2.status !== 400) {
    console.error('ERROR: Expected 400 Bad Request status when blocked.');
    process.exitCode = 1;
    return;
  }

  const msg = (c2.json?.message ?? '').toString().toLowerCase();
  if (!msg.includes('pending') || !msg.includes('approved') && !msg.includes('declined')) {
    console.warn('WARNING: Block message may not be user-friendly:', c2.json);
  }
  console.log('Verification complete: users with pending claims cannot claim other gifts.');
}

main().catch(err => {
  console.error(err);
  process.exitCode = 1;
});