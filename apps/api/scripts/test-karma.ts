import { PrismaClient, KarmaEventType, TrustLevel } from '@prisma/client';

const prisma = new PrismaClient();

async function testKarma() {
  try {
    const userId = 'cmgo8fh05000i2xddt9z6pox4'; // The test user ID
    
    console.log('Creating karma account...');
    
    // Upsert karma account
    const karmaAccount = await prisma.karmaAccount.upsert({
      where: { userId },
      update: {
        currentPoints: 110,
        totalPointsEarned: 110,
        level: 1,
        trustLevel: TrustLevel.NEWCOMER,
        streak: 1,
        lastActivityAt: new Date(),
      },
      create: {
        userId,
        currentPoints: 110,
        totalPointsEarned: 110,
        level: 1,
        trustLevel: TrustLevel.NEWCOMER,
        streak: 1,
        lastActivityAt: new Date(),
      },
    });
    
    console.log('Karma account created:', karmaAccount);
    
    // Create karma events
    await prisma.karmaEvent.createMany({
      data: [
        {
          userId,
          type: KarmaEventType.FIRST_LOGIN,
          points: 100,
          reason: 'Welcome to Bybata! Registration bonus.',
        },
        {
          userId,
          type: KarmaEventType.DAILY_LOGIN,
          points: 10,
          reason: 'Daily login bonus',
        },
      ],
    });
    
    console.log('Karma events created');
    
    // Test reading karma account
    const karmaData = await prisma.karmaAccount.findUnique({
      where: { userId },
    });
    
    console.log('Reading karma account:', karmaData);
    
    // Test reading karma history
    const history = await prisma.karmaEvent.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    
    console.log('Karma history:', history);
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

testKarma();