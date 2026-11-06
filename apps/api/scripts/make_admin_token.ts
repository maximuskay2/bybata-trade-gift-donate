import crypto from 'node:crypto';
import 'dotenv/config';

function base64url(input: Buffer | string) {
  return (typeof input === 'string' ? Buffer.from(input) : input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function signHS256(message: string, secret: string) {
  const h = crypto.createHmac('sha256', secret).update(message).digest();
  return base64url(h);
}

function makeJwt(payload: any, secret: string) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const encodedHeader = base64url(JSON.stringify(header));
  const encodedPayload = base64url(JSON.stringify(payload));
  const toSign = `${encodedHeader}.${encodedPayload}`;
  const signature = signHS256(toSign, secret);
  return `${toSign}.${signature}`;
}

const JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET;
if (!JWT_ACCESS_SECRET) {
  console.error('JWT_ACCESS_SECRET missing in environment');
  process.exit(2);
}

const [,, userId, email] = process.argv;
if (!userId || !email) {
  console.error('Usage: ts-node scripts/make_admin_token.ts <userId> <email>');
  process.exit(2);
}

const now = Math.floor(Date.now() / 1000);
const exp = now + 60 * 60 * 2; // 2 hours
const token = makeJwt({ sub: userId, email, role: 'ADMIN', iat: now, exp }, JWT_ACCESS_SECRET);
console.log(token);