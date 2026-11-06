import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seed...');

  // Create test users
  const user1 = await prisma.user.upsert({
    where: { email: 'alice@example.com' },
    update: {},
    create: {
      email: 'alice@example.com',
      passwordHash: await bcrypt.hash('password123', 10),
      emailVerifiedAt: new Date(),
      profile: {
        create: {
          displayName: 'Alice Johnson',
          bio: 'Love trading books and electronics!',
          phone: '+1234567890',
        },
      },
      account: {
        create: {
          balance: 100,
        },
      },
    },
    include: {
      profile: true,
    },
  });

  const user2 = await prisma.user.upsert({
    where: { email: 'bob@example.com' },
    update: {},
    create: {
      email: 'bob@example.com',
      passwordHash: await bcrypt.hash('password123', 10),
      emailVerifiedAt: new Date(),
      profile: {
        create: {
          displayName: 'Bob Smith',
          bio: 'Tech enthusiast and gadget collector',
          phone: '+1987654321',
        },
      },
      account: {
        create: {
          balance: 250,
        },
      },
    },
    include: {
      profile: true,
    },
  });

  const user3 = await prisma.user.upsert({
    where: { email: 'carol@example.com' },
    update: {},
    create: {
      email: 'carol@example.com',
      passwordHash: await bcrypt.hash('password123', 10),
      emailVerifiedAt: new Date(),
      profile: {
        create: {
          displayName: 'Carol Davis',
          bio: 'Fashion lover and book worm',
        },
      },
      account: {
        create: {
          balance: 75,
        },
      },
    },
    include: {
      profile: true,
    },
  });

  // Create admin user
  const adminUser = await prisma.user.upsert({
    where: { email: 'admin@bybata.com' },
    update: {},
    create: {
      email: 'admin@bybata.com',
      passwordHash: await bcrypt.hash('Akingbade34', 10),
      emailVerifiedAt: new Date(),
      role: 'ADMIN',
      profile: {
        create: {
          displayName: 'System Admin',
          bio: 'Platform administrator',
        },
      },
      account: {
        create: {
          balance: 1000,
        },
      },
    },
    include: {
      profile: true,
    },
  });

  console.log('✅ Created test users:', { user1: user1.email, user2: user2.email, user3: user3.email, admin: adminUser.email });

  // Create sample communities
  const community1 = await prisma.community.create({
    data: {
      name: 'Bybata Builders',
      description: 'A community for builders, makers, and problem solvers.',
      shortDescription: 'Builders and makers community',
      category: 'TECHNOLOGY',
      type: 'PUBLIC',
      createdById: user1.id,
      mediaKeys: [],
      tags: ['builders', 'technology', 'innovation'],
      location: 'Online',
      isFeatured: true,
    },
  });

  const community2 = await prisma.community.create({
    data: {
      name: 'Local Givers',
      description: 'Connect with people giving and sharing in your area.',
      shortDescription: 'Local giving and sharing',
      category: 'SOCIAL_IMPACT',
      type: 'PUBLIC',
      createdById: user2.id,
      mediaKeys: [],
      tags: ['giving', 'community', 'local'],
      location: 'City Center',
    },
  });

  console.log('✅ Created test communities:', {
    community1: community1.name,
    community2: community2.name,
  });

  // Seed conversion rates if none exist
  const existingRates = await (prisma as any).conversionRate.count();
  if (!existingRates) {
    await (prisma as any).conversionRate.create({ data: { base: 'BYC', quote: 'USD', rate: 10, active: true } });
    await (prisma as any).conversionRate.create({ data: { base: 'BYC', quote: 'NGN', rate: 1500, active: true } });
    console.log('✅ Seeded conversion rates (BYC→USD=10, BYC→NGN=1500)');
  }

  // Create test trades
  const trade1 = await prisma.trade.create({
    data: {
      ownerId: user1.id,
      title: 'iPhone 13 Pro - Excellent Condition',
      description: 'Barely used iPhone 13 Pro in excellent condition. Comes with original charger and case.',
      mediaKeys: ['iphone-1.jpg', 'iphone-2.jpg'],
      status: 'OPEN',
    },
  });

  const trade2 = await prisma.trade.create({
    data: {
      ownerId: user2.id,
      title: 'MacBook Air M2',
      description: 'Lightly used MacBook Air with M2 chip. Perfect for students or professionals.',
      mediaKeys: ['macbook-1.jpg', 'macbook-2.jpg'],
      status: 'OPEN',
    },
  });

  const trade3 = await prisma.trade.create({
    data: {
      ownerId: user3.id,
      title: 'Designer Handbag Collection',
      description: 'Beautiful collection of designer handbags in great condition.',
      mediaKeys: ['handbag-1.jpg'],
      status: 'OPEN',
    },
  });

  const trade4 = await prisma.trade.create({
    data: {
      ownerId: user1.id,
      title: 'Programming Books Bundle',
      description: 'Collection of programming books including React, Node.js, and Python guides.',
      mediaKeys: [],
      status: 'OPEN',
    },
  });

  console.log('✅ Created test trades:', { 
    trade1: trade1.title, 
    trade2: trade2.title, 
    trade3: trade3.title,
    trade4: trade4.title 
  });

  // Create a few trade offers
  const offer1 = await prisma.tradeOffer.create({
    data: {
      tradeId: trade1.id,
      bidderId: user2.id,
      message: 'Would you trade this for my MacBook Air?',
      status: 'PENDING',
    },
  });

  const offer2 = await prisma.tradeOffer.create({
    data: {
      tradeId: trade2.id,
      bidderId: user3.id,
      message: 'Interested in trading some designer items for this.',
      status: 'PENDING',
    },
  });

  console.log('✅ Created test offers');

  // Create test gifts
  const gift1 = await prisma.gift.create({
    data: {
      giverId: user1.id,
      title: 'Free Programming Book Bundle',
      description: 'Collection of excellent programming books including JavaScript, Python, and React guides.',
      type: 'RANDOM',
      category: 'BOOKS',
      karmaReward: 50,
      maxClaims: 3,
      mediaKeys: ['book-bundle.jpg'],
      tags: ['programming', 'learning', 'development'],
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
    },
  });

  const gift2 = await prisma.gift.create({
    data: {
      giverId: user2.id,
      title: 'Tech Mentoring Session',
      description: 'One-on-one tech mentoring session for junior developers. Will cover career advice, code review, and technical guidance.',
      type: 'SKILL',
      category: 'EDUCATION',
      karmaReward: 100,
      maxClaims: 1,
      location: 'Online (Zoom)',
      tags: ['mentoring', 'career', 'technology'],
      metadata: {
        duration: '60 minutes',
        topics: ['career guidance', 'code review', 'technical skills']
      },
      expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000), // 14 days from now
    },
  });

  const gift3 = await prisma.gift.create({
    data: {
      giverId: user3.id,
      title: 'Designer Items Giveaway',
      description: 'Beautiful collection of designer accessories and items in excellent condition.',
      type: 'RANDOM',
      category: 'CLOTHING',
      karmaReward: 75,
      maxClaims: 2,
      location: 'Downtown Area',
      isLocationRestricted: true,
      tags: ['fashion', 'designer', 'accessories'],
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days from now
    },
  });

  const gift4 = await prisma.gift.create({
    data: {
      giverId: user1.id,
      title: 'Targeted Gift for Bob',
      description: 'Special tech gift just for Bob - premium development tools and resources.',
      type: 'TARGETED',
      category: 'TECHNOLOGY',
      karmaReward: 80,
      maxClaims: 1,
      targetUserId: user2.id,
      tags: ['technology', 'development', 'tools'],
      expiresAt: new Date(Date.now() + 21 * 24 * 60 * 60 * 1000), // 21 days from now
    },
  });

  console.log('✅ Created test gifts:', {
    gift1: gift1.title,
    gift2: gift2.title,
    gift3: gift3.title,
    gift4: gift4.title
  });

  // Create sample notifications
  const welcome = await prisma.notification.create({
    data: {
      userId: user1.id,
      type: 'SYSTEM_ANNOUNCEMENT',
      title: 'Welcome to Bybata',
      message: 'Thanks for joining! Explore trades, gifts, and communities.',
      priority: 'NORMAL',
    },
  });

  const tradeAlert = await prisma.notification.create({
    data: {
      userId: user2.id,
      type: 'TRADE_OFFER_RECEIVED',
      title: 'New Trade Offer',
      message: 'You received a new trade offer. Tap to review.',
      priority: 'HIGH',
    },
  });

  console.log('✅ Created sample notifications:', {
    welcome: welcome.id,
    tradeAlert: tradeAlert.id,
  });

  // Create sample broadcast and delivery logs
  const broadcastSent = await prisma.broadcastNotification.create({
    data: {
      title: 'Platform Update',
      message: 'We have improved search and chat experience. Check it out!',
      status: 'SENT',
      recipientCount: 2,
      deliveredCount: 2,
      readCount: 1,
      sentAt: new Date(),
      createdBy: adminUser.id,
    },
  });

  await prisma.notification.createMany({
    data: [
      {
        userId: user1.id,
        type: 'BROADCAST',
        title: broadcastSent.title,
        message: broadcastSent.message,
        priority: 'NORMAL',
        sourceId: broadcastSent.id,
        sourceType: 'broadcast',
        read: true,
        readAt: new Date(),
      },
      {
        userId: user2.id,
        type: 'BROADCAST',
        title: broadcastSent.title,
        message: broadcastSent.message,
        priority: 'NORMAL',
        sourceId: broadcastSent.id,
        sourceType: 'broadcast',
        read: false,
      },
    ],
  });

  const broadcastDraft = await prisma.broadcastNotification.create({
    data: {
      title: 'Community Spotlight',
      message: 'Discover new communities created this week.',
      status: 'DRAFT',
      createdBy: adminUser.id,
    },
  });

  console.log('✅ Created sample broadcasts:', {
    broadcastSent: broadcastSent.id,
    broadcastDraft: broadcastDraft.id,
  });

  console.log('🌱 Database seeded successfully!');
  
  console.log('\n📋 Test Accounts:');
  console.log('- alice@example.com / password123');
  console.log('- bob@example.com / password123');  
  console.log('- carol@example.com / password123');
  console.log('- admin@bybata.com / Akingbade34 (ADMIN)');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
