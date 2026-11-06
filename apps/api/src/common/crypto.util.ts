import * as crypto from 'crypto';

const ALG = 'aes-256-gcm';

export function encryptSecret(plain: string, key: string) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALG, Buffer.from(key, 'hex'), iv);
  const enc = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${enc.toString('hex')}:${tag.toString('hex')}`;
}

export function decryptSecret(enc: string, key: string) {
  const [ivHex, dataHex, tagHex] = enc.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const data = Buffer.from(dataHex, 'hex');
  const tag = Buffer.from(tagHex, 'hex');
  const decipher = crypto.createDecipheriv(ALG, Buffer.from(key, 'hex'), iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(data), decipher.final()]);
  return dec.toString('utf8');
}
