import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function testAchievements() {
  try {
    const userId = 'cmgo8fh05000i2xddt9z6pox4';
    
    // Get user's current points
    const karmaAccount = await prisma.karmaAccount.findUnique({
      where: { userId },
    });
    
    console.log('Current karma account:', karmaAccount);
    
    if (!karmaAccount) {
      console.log('No karma account found');
      return;
    }
    
    // Get point-based achievements that user should have unlocked
    const pointAchievements = await prisma.achievement.findMany({
      where: {
        isActive: true,
        pointsRequired: { lte: karmaAccount.totalPointsEarned },
        NOT: {
          userAchievements: {
            some: { userId },
          },
        },
      },
    });
    
    console.log('Achievements to unlock:', pointAchievements.map(a => ({ name: a.name, pointsRequired: a.pointsRequired })));
    
    // Unlock them
    for (const achievement of pointAchievements) {
      console.log(`Unlocking achievement: ${achievement.name}`);
      
      await prisma.userAchievement.create({
        data: {
          userId,
          achievementId: achievement.id,
        },
      });
      
      // Award achievement points
      if (achievement.pointsReward > 0) {
        await prisma.karmaEvent.create({
          data: {
            userId,
            type: 'MANUAL_ADJUSTMENT',
            points: achievement.pointsReward,
            reason: `Achievement unlocked: ${achievement.name}`,
            sourceId: achievement.id,
            sourceType: 'achievement',
          },
        });
        
        // Update karma account
        await prisma.karmaAccount.update({
          where: { userId },
          data: {
            currentPoints: { increment: achievement.pointsReward },
            totalPointsEarned: { increment: achievement.pointsReward },
          },
        });
      }
    }
    
    console.log('Achievement processing complete');
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

testAchievements();