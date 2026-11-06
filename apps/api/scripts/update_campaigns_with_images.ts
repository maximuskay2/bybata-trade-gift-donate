import { PrismaClient } from '@prisma/client';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';

const prisma = new PrismaClient();

const bucket = process.env.STORAGE_BUCKET;
const endpoint = process.env.STORAGE_ENDPOINT;
const region = process.env.STORAGE_REGION || 'us-east-1';
const accessKeyId = process.env.STORAGE_ACCESS_KEY_ID;
const secretAccessKey = process.env.STORAGE_SECRET_ACCESS_KEY;

if (!bucket || !endpoint || !accessKeyId || !secretAccessKey) {
  // eslint-disable-next-line no-console
  console.error('Missing storage env vars. Expected STORAGE_BUCKET, STORAGE_ENDPOINT, STORAGE_ACCESS_KEY_ID, STORAGE_SECRET_ACCESS_KEY.');
  process.exit(1);
}

const s3 = new S3Client({
  region,
  endpoint,
  credentials: { accessKeyId, secretAccessKey },
  forcePathStyle: true,
});

const palette = [
  ['#0F2027', '#2C5364'],
  ['#F12711', '#F5AF19'],
  ['#1D976C', '#93F9B9'],
  ['#396AFC', '#2948FF'],
  ['#30E8BF', '#FF8235'],
  ['#FC466B', '#3F5EFB'],
  ['#8E2DE2', '#4A00E0'],
  ['#FFB347', '#FFCC33'],
  ['#43C6AC', '#191654'],
  ['#DA4453', '#89216B'],
];

function escapeXml(input: string) {
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function svgForCampaign(title: string, index: number) {
  const [c1, c2] = palette[index % palette.length];
  const safeTitle = escapeXml(title || 'Campaign');
  return `
<svg width="1200" height="800" viewBox="0 0 1200 800" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${c1}"/>
      <stop offset="100%" stop-color="${c2}"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="12" stdDeviation="18" flood-color="#000000" flood-opacity="0.25"/>
    </filter>
  </defs>
  <rect width="1200" height="800" fill="url(#bg)"/>
  <rect x="90" y="140" width="1020" height="520" rx="40" fill="rgba(255,255,255,0.18)" stroke="rgba(255,255,255,0.25)" stroke-width="2" filter="url(#shadow)"/>
  <text x="600" y="420" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="52" fill="#FFFFFF" font-weight="700">${safeTitle}</text>
  <text x="600" y="480" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="24" fill="rgba(255,255,255,0.9)">BYBATA CAMPAIGN</text>
</svg>
  `.trim();
}

async function uploadCampaignImage(campaignId: string, title: string, index: number) {
  const svg = svgForCampaign(title, index);
  const key = `donations/${campaignId}/${randomUUID()}.svg`;
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: Buffer.from(svg, 'utf-8'),
      ContentType: 'image/svg+xml',
    }),
  );
  return key;
}

async function run() {
  const campaigns = await prisma.campaign.findMany({
    select: { id: true, title: true },
    orderBy: { createdAt: 'asc' },
  });

  let updated = 0;
  for (const campaign of campaigns) {
    const imageCount = 2 + (updated % 2); // 2-3 images per campaign
    const keys: string[] = [];
    for (let i = 0; i < imageCount; i += 1) {
      const key = await uploadCampaignImage(campaign.id, campaign.title, updated + i);
      keys.push(key);
    }
    await prisma.campaign.update({
      where: { id: campaign.id },
      data: { mediaKeys: keys, thumbnailKey: keys[0] },
    });
    updated += 1;
  }

  // eslint-disable-next-line no-console
  console.log(`Updated ${updated} campaigns with ${bucket} images.`);
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
