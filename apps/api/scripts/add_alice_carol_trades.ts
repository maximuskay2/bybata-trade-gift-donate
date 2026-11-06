import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function ensureTrade(ownerId: string, title: string, description: string, mediaKeys: string[]) {
  const existing = await prisma.trade.findFirst({ where: { ownerId, title } });
  if (existing) {
    console.log(`ℹ️ Trade already exists for owner ${ownerId}: ${title}`);
    return existing;
  }
  const created = await prisma.trade.create({
    data: {
      ownerId,
      title,
      description,
      mediaKeys,
      status: 'OPEN',
    },
  });
  console.log(`✅ Created trade for owner ${ownerId}: ${title}`);
  return created;
}

async function main() {
  console.log('🔧 Adding trades for alice@example.com and carol@example.com ...');

  const alice = await prisma.user.findUnique({ where: { email: 'alice@example.com' } });
  const carol = await prisma.user.findUnique({ where: { email: 'carol@example.com' } });

  if (!alice) {
    throw new Error('User alice@example.com not found. Seed users first.');
  }
  if (!carol) {
    throw new Error('User carol@example.com not found. Seed users first.');
  }

  // Alice trades
  await ensureTrade(
    alice.id,
    'Nintendo Switch OLED',
    'Nintendo Switch OLED with Joy-Cons and dock, lightly used.',
    ['switch-1.jpg', 'switch-2.jpg']
  );

  await ensureTrade(
    alice.id,
    'Canon EOS M50 Camera',
    'Canon EOS M50 mirrorless camera, great for vlogging and photography.',
    ['canon-m50-1.jpg']
  );

  // Carol trades
  await ensureTrade(
    carol.id,
    'Vintage Fashion Accessories Set',
    'Curated set of vintage fashion accessories in excellent condition.',
    ['vintage-accessories-1.jpg']
  );

  await ensureTrade(
    carol.id,
    'Classic Literature Book Collection',
    'Set of classic literature books, perfect for collectors and book lovers.',
    []
  );

  console.log('🎉 Finished adding trades.');
}

main()
  .catch((e) => {
    console.error('❌ Failed to add trades:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });