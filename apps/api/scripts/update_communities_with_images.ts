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
  ['#FF6A00', '#EE0979'],
  ['#2193B0', '#6DD5ED'],
  ['#56AB2F', '#A8E063'],
  ['#614385', '#516395'],
  ['#1FA2FF', '#12D8FA'],
  ['#DA4453', '#89216B'],
  ['#00B4DB', '#0083B0'],
  ['#42275A', '#734B6D'],
  ['#38EF7D', '#11998E'],
  ['#FDC830', '#F37335'],
];

function escapeXml(input: string) {
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function svgForCommunity(name: string, index: number, label: string) {
  const [c1, c2] = palette[index % palette.length];
  const safeName = escapeXml(name || 'Community');
  const safeLabel = escapeXml(label);
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
  <text x="600" y="400" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="52" fill="#FFFFFF" font-weight="700">${safeName}</text>
  <text x="600" y="470" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="24" fill="rgba(255,255,255,0.9)">${safeLabel}</text>
</svg>
  `.trim();
}

async function uploadCommunityImage(communityId: string, name: string, index: number, label: string) {
  const svg = svgForCommunity(name, index, label);
  const key = `communities/${communityId}/${randomUUID()}.svg`;
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
  const communities = await prisma.community.findMany({
    select: { id: true, name: true },
    orderBy: { createdAt: 'asc' },
  });

  let updated = 0;
  for (const community of communities) {
    const avatarKey = await uploadCommunityImage(community.id, community.name, updated, 'Community Avatar');
    const bannerKey = await uploadCommunityImage(community.id, community.name, updated + 1, 'Community Banner');
    const mediaKeys = [
      await uploadCommunityImage(community.id, community.name, updated + 2, 'Community Media 1'),
      await uploadCommunityImage(community.id, community.name, updated + 3, 'Community Media 2'),
    ];

    await prisma.community.update({
      where: { id: community.id },
      data: { avatarKey, bannerKey, mediaKeys },
    });
    updated += 1;
  }

  // eslint-disable-next-line no-console
  console.log(`Updated ${updated} communities with ${bucket} images.`);
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
