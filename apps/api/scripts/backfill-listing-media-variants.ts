/**
 * Backfill `_thumb.jpg` (400px) and `_medium.jpg` (800px) variants for existing
 * gift, trade, and campaign listing images. Updates `thumbnailKey` when it still
 * points at the full-size original.
 *
 * Usage:
 *   npm run media:backfill-variants -- --dry-run
 *   npm run media:backfill-variants -- --confirm BACKFILL_PRODUCTION
 *   npm run media:backfill-variants -- --confirm BACKFILL_PRODUCTION --verbose
 *   npm run media:backfill-variants -- --confirm BACKFILL_PRODUCTION --delay-ms 1200
 *
 * Requires DATABASE_URL and storage env vars (STORAGE_BUCKET, STORAGE_ENDPOINT, etc.).
 */
import 'dotenv/config';
import {
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import Jimp from 'jimp';
import { PrismaClient } from '@prisma/client';
import {
  isLikelyVideoKey,
  variantKeysFor,
} from '../src/common/listing-media-url.util';

const prisma = new PrismaClient();

const CONFIRM_TOKEN = 'BACKFILL_PRODUCTION';
const DOMAINS = ['gifts', 'trades', 'campaigns'] as const;
type Domain = (typeof DOMAINS)[number];

const bucket = process.env.STORAGE_BUCKET;
const endpoint = process.env.STORAGE_ENDPOINT;
const region = process.env.STORAGE_REGION || 'us-east-1';
const accessKeyId = process.env.STORAGE_ACCESS_KEY_ID;
const secretAccessKey = process.env.STORAGE_SECRET_ACCESS_KEY;

if (!bucket || !endpoint || !accessKeyId || !secretAccessKey) {
  // eslint-disable-next-line no-console
  console.error(
    'Missing storage env vars. Expected STORAGE_BUCKET, STORAGE_ENDPOINT, STORAGE_ACCESS_KEY_ID, STORAGE_SECRET_ACCESS_KEY.',
  );
  process.exit(1);
}

const s3 = new S3Client({
  region,
  endpoint,
  credentials: { accessKeyId, secretAccessKey },
  forcePathStyle: true,
});

type ListingRow = {
  id: string;
  mediaType: string | null;
  mediaKeys: string[];
  videoKey: string | null;
  thumbnailKey: string | null;
};

function parseArgs() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const verbose = args.includes('--verbose');
  const confirmIdx = args.indexOf('--confirm');
  const confirmed =
    confirmIdx >= 0 && args[confirmIdx + 1] === CONFIRM_TOKEN;
  const domainIdx = args.indexOf('--domain');
  const domainArg =
    domainIdx >= 0 ? (args[domainIdx + 1] as Domain | undefined) : undefined;
  const domain =
    domainArg && DOMAINS.includes(domainArg as Domain)
      ? (domainArg as Domain)
      : 'all';
  const limitIdx = args.indexOf('--limit');
  const limit =
    limitIdx >= 0 ? Math.max(1, Number(args[limitIdx + 1]) || 0) : undefined;
  const delayIdx = args.indexOf('--delay-ms');
  const delayMs =
    delayIdx >= 0 ? Math.max(0, Number(args[delayIdx + 1]) || 0) : undefined;
  return { dryRun, confirmed, domain, limit, verbose, delayMs };
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableStorageError(err: any): boolean {
  const status = err?.$metadata?.httpStatusCode;
  const code = String(err?.name || err?.Code || err?.code || '');
  if ([429, 500, 502, 503, 504].includes(status)) return true;
  if (
    code.includes('SlowDown') ||
    code === 'TimeoutError' ||
    code === 'RequestTimeout' ||
    code === 'ECONNRESET' ||
    code === 'EPIPE'
  ) {
    return true;
  }
  const message = String(err?.message || '');
  if (message.includes('SlowDown') || message.includes('503')) return true;
  return false;
}

function isMissingObjectError(err: any): boolean {
  const status = err?.$metadata?.httpStatusCode;
  const code = String(err?.name || err?.Code || err?.code || '');
  return status === 404 || code === 'NoSuchKey' || code === 'NotFound';
}

async function withStorageRetry<T>(
  label: string,
  fn: () => Promise<T>,
  verbose = false,
  maxAttempts = 6,
): Promise<T> {
  let delayMs = 600;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      if (isMissingObjectError(err)) throw err;
      if (!isRetryableStorageError(err) || attempt === maxAttempts) throw err;
      if (verbose) {
        // eslint-disable-next-line no-console
        console.warn(
          `[retry] ${label} attempt ${attempt}/${maxAttempts}: ${err?.message || err}`,
        );
      }
      await sleep(delayMs);
      delayMs = Math.min(delayMs * 2, 20000);
    }
  }
  throw new Error(`${label}: exhausted retries`);
}

/** Railway bucket may reject HeadObject — probe with a small ranged GET instead. */
async function objectExists(key: string, verbose = false): Promise<boolean> {
  try {
    await withStorageRetry(
      `exists ${key}`,
      async () => {
        const resp = await s3.send(
          new GetObjectCommand({
            Bucket: bucket,
            Key: key,
            Range: 'bytes=0-4095',
          }),
        );
        if (
          resp.Body &&
          typeof (resp.Body as any).transformToByteArray === 'function'
        ) {
          await (resp.Body as any).transformToByteArray();
        }
      },
      verbose,
    );
    return true;
  } catch (err: any) {
    if (isMissingObjectError(err)) return false;
    try {
      await withStorageRetry(
        `head ${key}`,
        async () => {
          await s3.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
        },
        verbose,
      );
      return true;
    } catch (headErr: any) {
      if (isMissingObjectError(headErr)) return false;
      throw headErr;
    }
  }
}

async function readObjectBuffer(key: string, verbose = false): Promise<Buffer> {
  return withStorageRetry(
    `read ${key}`,
    async () => {
      const resp = await s3.send(
        new GetObjectCommand({ Bucket: bucket, Key: key }),
      );
      if (
        resp.Body &&
        typeof (resp.Body as any).transformToByteArray === 'function'
      ) {
        return Buffer.from(await (resp.Body as any).transformToByteArray());
      }
      const stream = resp.Body as NodeJS.ReadableStream;
      const chunks: Buffer[] = [];
      await new Promise<void>((resolve, reject) => {
        stream.on('data', (chunk: Buffer) => chunks.push(chunk));
        stream.on('end', () => resolve());
        stream.on('error', (err) => reject(err));
      });
      return Buffer.concat(chunks);
    },
    verbose,
  );
}

async function putObject(
  key: string,
  body: Buffer,
  contentType: string,
  verbose = false,
) {
  await withStorageRetry(
    `put ${key}`,
    async () => {
      await s3.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          Body: body,
          ContentType: contentType,
          CacheControl: 'public, max-age=31536000, immutable',
        }),
      );
    },
    verbose,
  );
}

async function ensureVariants(
  sourceKey: string,
  verbose = false,
): Promise<{
  thumbKey: string;
  mediumKey: string;
  created: boolean;
} | null> {
  const key = sourceKey?.trim();
  if (!key || isLikelyVideoKey(key)) return null;

  const { thumb, medium } = variantKeysFor(key);
  const thumbExists = await objectExists(thumb, verbose);
  const mediumExists = await objectExists(medium, verbose);

  if (thumbExists && mediumExists) {
    return { thumbKey: thumb, mediumKey: medium, created: false };
  }

  const buffer = await readObjectBuffer(key, verbose);
  const image = await Jimp.read(buffer);

  if (!thumbExists) {
    const thumbBuf = await image
      .clone()
      .resize(400, Jimp.AUTO)
      .quality(82)
      .getBufferAsync(Jimp.MIME_JPEG);
    await putObject(thumb, thumbBuf, 'image/jpeg', verbose);
    await sleep(300);
  }

  if (!mediumExists) {
    const mediumBuf = await image
      .clone()
      .resize(800, Jimp.AUTO)
      .quality(85)
      .getBufferAsync(Jimp.MIME_JPEG);
    await putObject(medium, mediumBuf, 'image/jpeg', verbose);
  }

  return { thumbKey: thumb, mediumKey: medium, created: true };
}

function resolveSourceKeyCandidates(row: ListingRow): string[] {
  const type = (row.mediaType || 'IMAGE').toUpperCase();
  const candidates: string[] = [];
  const seen = new Set<string>();

  const add = (raw?: string | null) => {
    const key = raw?.trim();
    if (!key || seen.has(key) || isLikelyVideoKey(key)) return;
    seen.add(key);
    candidates.push(key);
  };

  if (type === 'VIDEO') {
    add(row.thumbnailKey);
    return candidates;
  }

  // Prefer thumbnailKey when it is a full-size original (app uses it first in feeds).
  const thumb = row.thumbnailKey?.trim();
  if (thumb && !thumb.endsWith('_thumb.jpg') && !thumb.endsWith('_medium.jpg')) {
    add(thumb);
  }
  if (Array.isArray(row.mediaKeys)) {
    for (const mk of row.mediaKeys) add(mk);
  }
  return candidates;
}

async function resolveExistingSourceKey(
  row: ListingRow,
  verbose = false,
): Promise<string | null> {
  const candidates = resolveSourceKeyCandidates(row);
  for (const key of candidates) {
    if (await objectExists(key, verbose)) return key;
  }
  return null;
}

function shouldUpdateThumbnail(
  current: string | null | undefined,
  thumbKey: string,
): boolean {
  const cur = current?.trim();
  if (!cur) return true;
  if (cur === thumbKey) return false;
  return !cur.endsWith('_thumb.jpg');
}

async function processListing(
  domain: Domain,
  row: ListingRow,
  dryRun: boolean,
  verbose = false,
): Promise<'skipped' | 'updated' | 'created' | 'failed'> {
  const candidates = resolveSourceKeyCandidates(row);
  if (candidates.length === 0) return 'skipped';

  try {
    const sourceKey = await resolveExistingSourceKey(row, verbose);
    if (!sourceKey) {
      // eslint-disable-next-line no-console
      console.warn(
        `[skip] ${domain}/${row.id}: no storage object for keys tried: ${candidates.join(', ')}`,
      );
      return 'skipped';
    }

    if (verbose && candidates[0] !== sourceKey) {
      // eslint-disable-next-line no-console
      console.log(
        `[resolve] ${domain}/${row.id}: using ${sourceKey} (tried ${candidates.length} keys)`,
      );
    }

    if (dryRun) {
      const { thumb } = variantKeysFor(sourceKey);
      const thumbExists = await objectExists(thumb, verbose);
      const needsThumbUpdate = shouldUpdateThumbnail(row.thumbnailKey, thumb);
      if (thumbExists && !needsThumbUpdate) return 'skipped';
      // eslint-disable-next-line no-console
      console.log(
        `[dry-run] ${domain}/${row.id}: would ensure variants for ${sourceKey}` +
          (needsThumbUpdate ? `; set thumbnailKey=${thumb}` : ''),
      );
      return thumbExists ? 'updated' : 'created';
    }

    const variants = await ensureVariants(sourceKey, verbose);
    if (!variants) return 'skipped';

    const needsThumbUpdate = shouldUpdateThumbnail(
      row.thumbnailKey,
      variants.thumbKey,
    );
    if (needsThumbUpdate) {
      if (domain === 'gifts') {
        await prisma.gift.update({
          where: { id: row.id },
          data: { thumbnailKey: variants.thumbKey },
        });
      } else if (domain === 'trades') {
        await prisma.trade.update({
          where: { id: row.id },
          data: { thumbnailKey: variants.thumbKey },
        });
      } else {
        await prisma.campaign.update({
          where: { id: row.id },
          data: { thumbnailKey: variants.thumbKey },
        });
      }
    }

    // eslint-disable-next-line no-console
    console.log(
      `[ok] ${domain}/${row.id}: ${variants.created ? 'created' : 'exists'} variants` +
        (needsThumbUpdate ? `; thumbnailKey=${variants.thumbKey}` : ''),
    );
    return variants.created ? 'created' : needsThumbUpdate ? 'updated' : 'skipped';
  } catch (err: any) {
    // eslint-disable-next-line no-console
    console.error(`[fail] ${domain}/${row.id}: ${err?.message || err}`);
    return 'failed';
  }
}

async function loadRows(domain: Domain, limit?: number): Promise<ListingRow[]> {
  const take = limit;
  if (domain === 'gifts') {
    return prisma.gift.findMany({
      select: {
        id: true,
        mediaType: true,
        mediaKeys: true,
        videoKey: true,
        thumbnailKey: true,
      },
      orderBy: { createdAt: 'asc' },
      ...(take ? { take } : {}),
    });
  }
  if (domain === 'trades') {
    return prisma.trade.findMany({
      select: {
        id: true,
        mediaType: true,
        mediaKeys: true,
        videoKey: true,
        thumbnailKey: true,
      },
      orderBy: { createdAt: 'asc' },
      ...(take ? { take } : {}),
    });
  }
  return prisma.campaign.findMany({
    select: {
      id: true,
      mediaType: true,
      mediaKeys: true,
      videoKey: true,
      thumbnailKey: true,
    },
    orderBy: { createdAt: 'asc' },
    ...(take ? { take } : {}),
  });
}

async function run() {
  const { dryRun, confirmed, domain, limit, verbose, delayMs } = parseArgs();
  const listingDelayMs = delayMs ?? (dryRun ? 0 : 900);

  if (!dryRun && !confirmed) {
    // eslint-disable-next-line no-console
    console.error(
      `Refusing to run without --dry-run or --confirm ${CONFIRM_TOKEN}`,
    );
    process.exit(1);
  }

  const targets: Domain[] =
    domain === 'all' ? [...DOMAINS] : [domain as Domain];

  const stats = {
    scanned: 0,
    created: 0,
    updated: 0,
    skipped: 0,
    failed: 0,
  };

  // eslint-disable-next-line no-console
  console.log(
    `Backfill listing media variants (${dryRun ? 'DRY RUN' : 'LIVE'}) domains=${targets.join(',')} limit=${limit ?? 'none'} delayMs=${listingDelayMs} bucket=${bucket} endpoint=${endpoint}`,
  );

  for (const d of targets) {
    const perDomainLimit =
      domain === 'all' && limit ? limit : domain !== 'all' ? limit : undefined;
    const rows = await loadRows(d, perDomainLimit);
    // eslint-disable-next-line no-console
    console.log(`\n--- ${d}: ${rows.length} listings ---`);

    for (const row of rows) {
      stats.scanned += 1;
      const result = await processListing(d, row, dryRun, verbose);
      if (result === 'created') stats.created += 1;
      else if (result === 'updated') stats.updated += 1;
      else if (result === 'failed') stats.failed += 1;
      else stats.skipped += 1;
      if (!dryRun && listingDelayMs > 0) {
        await sleep(listingDelayMs);
      }
    }
  }

  // eslint-disable-next-line no-console
  console.log('\nSummary:', stats);
}

run()
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
