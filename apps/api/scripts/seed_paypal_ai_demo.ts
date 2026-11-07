/**
 * Sandbox demo for the PayPal fair-trade top-up.
 * Two users, one expensive listing, one cheap listing, and an item-for-item offer.
 *
 *   npm run seed:paypal-ai
 *
 * Sign in with either account. Password: DemoTrade123!
 */
import { PrismaClient, TradeCategory, TradeStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();
const password = 'DemoTrade123!';

async function main() {
  const owner = await upsertUser('paypal-demo-owner@bybata.test', 'paypal_demo_owner', 'Demo Owner');
  const bidder = await upsertUser('paypal-demo-bidder@bybata.test', 'paypal_demo_bidder', 'Demo Bidder');

  const laptop = await upsertTrade(owner.id, {
    title: 'Demo MacBook Pro 14-inch',
    description: 'Uneven trade demo. Condition: good. Worth much more than a paperback set.',
    category: TradeCategory.ELECTRONICS,
  });
  const books = await upsertTrade(bidder.id, {
    title: 'Demo paperback novel set',
    description: 'Uneven trade demo. Condition: good. A small stack of used novels.',
    category: TradeCategory.BOOKS,
  });

  await prisma.trade.update({
    where: { id: laptop.id },
    data: { status: TradeStatus.IN_OFFER },
  });
  await prisma.trade.update({
    where: { id: books.id },
    data: { status: TradeStatus.IN_OFFER },
  });

  const existing = await prisma.tradeOffer.findFirst({
    where: { tradeId: laptop.id, bidderId: bidder.id, offeredTradeId: books.id },
  });
  const offer = existing ?? await prisma.tradeOffer.create({
    data: {
      tradeId: laptop.id,
      bidderId: bidder.id,
      offeredTradeId: books.id,
      message: 'I can trade the novel set for the laptop. Let us even the difference.',
    },
  });

  console.log('PayPal AI demo is ready.');
  console.log(`Owner  ${owner.email}  /  ${password}`);
  console.log(`Bidder ${bidder.email}  /  ${password}`);
  console.log(`Trade  ${laptop.id}`);
  console.log(`Offer  ${offer.id}`);
  console.log('Open the offer, tap Even this trade, accept on both accounts, then pay in PayPal sandbox.');
}

async function upsertUser(email: string, username: string, displayName: string) {
  const passwordHash = await bcrypt.hash(password, 10);
  return prisma.user.upsert({
    where: { email },
    update: { passwordHash, emailVerifiedAt: new Date() },
    create: {
      email,
      passwordHash,
      emailVerifiedAt: new Date(),
      profile: { create: { username, displayName, bio: 'PayPal AI hackathon demo' } },
      account: { create: { balance: 0 } },
    },
  });
}

async function upsertTrade(
  ownerId: string,
  input: { title: string; description: string; category: TradeCategory },
) {
  const existing = await prisma.trade.findFirst({
    where: { ownerId, title: input.title },
  });
  if (existing) return existing;
  return prisma.trade.create({
    data: {
      ownerId,
      title: input.title,
      description: input.description,
      category: input.category,
      status: TradeStatus.OPEN,
      mediaKeys: [],
      metadata: { condition: 'good', demo: 'paypal-ai' },
    },
  });
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
