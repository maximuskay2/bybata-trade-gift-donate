import 'dotenv/config';
import { PrismaClient, TradeCategory, MessageType } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('⚠️ Resetting all trades and related negotiations...');

  // Wipe negotiation-related data in safe order
  await prisma.negotiationMessage.deleteMany({});
  await prisma.negotiation.deleteMany({});
  await prisma.tradeOffer.deleteMany({});
  const del = await prisma.trade.deleteMany({});
  console.log(`✅ Deleted ${del.count} trades (and dependent records).`);

  // Fetch users
  const alice = await prisma.user.findUnique({ where: { email: 'alice@example.com' } });
  const carol = await prisma.user.findUnique({ where: { email: 'carol@example.com' } });
  if (!alice || !carol) {
    throw new Error('Seeded users not found. Ensure prisma/seed.ts has run.');
  }
  console.log(`👥 Found users: Alice=${alice.id}, Carol=${carol.id}`);

  // Create trades with complete metadata
  const aliceTrade = await prisma.trade.create({
    data: {
      ownerId: alice.id,
      title: 'MacBook Pro 14-inch (M1 Pro), Excellent Condition',
      description: '2021 model, 16GB RAM, 512GB SSD. Includes charger and case.',
      category: TradeCategory.ELECTRONICS,
      isNegotiable: true,
      requiresPickup: true,
      allowDelivery: true,
      allowShipping: true,
      enableBYCPromotion: false,
      mediaKeys: ['electronics/alice/macbook_pro_14.jpg'],
    },
  });

  const carolTrade = await prisma.trade.create({
    data: {
      ownerId: carol.id,
      title: 'Canon EOS R Mirrorless Camera with RF 24-105mm Lens',
      description: 'Pristine condition. Shutter count ~5k. Includes original box and strap.',
      category: TradeCategory.ELECTRONICS,
      isNegotiable: true,
      requiresPickup: false,
      allowDelivery: true,
      allowShipping: true,
      enableBYCPromotion: false,
      mediaKeys: ['electronics/carol/canon_eos_r.jpg'],
    },
  });
  console.log(`🛒 Created trades: AliceTrade=${aliceTrade.id}, CarolTrade=${carolTrade.id}`);

  // Create offers: Carol -> Alice's trade; Alice -> Carol's trade
  const offerFromCarolToAlice = await prisma.tradeOffer.create({
    data: {
      tradeId: aliceTrade.id,
      bidderId: carol.id,
      amount: new (require('@prisma/client').Prisma.Decimal)('200.00'),
      message: 'Initial offer for your MacBook Pro.',
    },
  });

  const offerFromAliceToCarol = await prisma.tradeOffer.create({
    data: {
      tradeId: carolTrade.id,
      bidderId: alice.id,
      amount: new (require('@prisma/client').Prisma.Decimal)('850.00'),
      message: 'Initial offer for your Canon EOS R.',
    },
  });
  console.log(`💬 Created offers: Carol→Alice=${offerFromCarolToAlice.id}, Alice→Carol=${offerFromAliceToCarol.id}`);

  // Ensure negotiations exist for each offer
  const negCarolAlice = await prisma.negotiation.create({
    data: {
      tradeId: aliceTrade.id,
      offerId: offerFromCarolToAlice.id,
      ownerId: alice.id,
      bidderId: carol.id,
    },
  });

  const negAliceCarol = await prisma.negotiation.create({
    data: {
      tradeId: carolTrade.id,
      offerId: offerFromAliceToCarol.id,
      ownerId: carol.id,
      bidderId: alice.id,
    },
  });
  console.log(`🤝 Negotiations ready: Carol↔Alice=${negCarolAlice.id}, Alice↔Carol=${negAliceCarol.id}`);

  // Sequence of messages to keep negotiations active with two counters from each side
  // Negotiation: Carol → Alice (MacBook)
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negCarolAlice.id,
      senderId: carol.id,
      content: 'Proposal: 200 BYC, pickup at weekend.',
      messageType: MessageType.PROPOSAL,
      proposalData: { amount: '200.00', terms: 'Pickup on Saturday' },
    },
  });
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negCarolAlice.id,
      senderId: alice.id,
      content: 'Counter: 230 BYC, delivery available.',
      messageType: MessageType.COUNTER_OFFER,
      proposalData: { amount: '230.00', terms: 'Delivery to your address' },
    },
  });
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negCarolAlice.id,
      senderId: carol.id,
      content: 'Counter: 220 BYC, still prefer pickup.',
      messageType: MessageType.COUNTER_OFFER,
      proposalData: { amount: '220.00', terms: 'Pickup Sunday afternoon' },
    },
  });
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negCarolAlice.id,
      senderId: alice.id,
      content: 'Sounds good. Let’s keep it pending for now.',
      messageType: MessageType.REGULAR,
    },
  });

  // Negotiation: Alice → Carol (Canon EOS R)
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negAliceCarol.id,
      senderId: alice.id,
      content: 'Proposal: 850 BYC, can pick up today.',
      messageType: MessageType.PROPOSAL,
      proposalData: { amount: '850.00', terms: 'Pickup today evening' },
    },
  });
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negAliceCarol.id,
      senderId: carol.id,
      content: 'Counter: 900 BYC, delivery preferred.',
      messageType: MessageType.COUNTER_OFFER,
      proposalData: { amount: '900.00', terms: 'Delivery by Tuesday' },
    },
  });
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negAliceCarol.id,
      senderId: alice.id,
      content: 'Counter: 880 BYC, pickup still fine.',
      messageType: MessageType.COUNTER_OFFER,
      proposalData: { amount: '880.00', terms: 'Pickup Wednesday morning' },
    },
  });
  await prisma.negotiationMessage.create({
    data: {
      negotiationId: negAliceCarol.id,
      senderId: carol.id,
      content: 'Okay, let’s keep discussing details.',
      messageType: MessageType.REGULAR,
    },
  });

  console.log('📦 Setup complete: trades, offers, and active negotiations prepared.');
  console.log({
    aliceTrade: aliceTrade.id,
    carolTrade: carolTrade.id,
    offerFromCarolToAlice: offerFromCarolToAlice.id,
    offerFromAliceToCarol: offerFromAliceToCarol.id,
    negCarolAlice: negCarolAlice.id,
    negAliceCarol: negAliceCarol.id,
  });
}

main()
  .catch((e) => {
    console.error('❌ Error resetting and setting up negotiations:', e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });