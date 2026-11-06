import { PrismaClient, AchievementCategory, AchievementRarity } from '@prisma/client';

const prisma = new PrismaClient();

export async function seedKarmaAchievements() {
  console.log('Seeding karma achievements...');

  const achievements = [
    // General Milestones
    {
      slug: 'welcome-aboard',
      name: 'Welcome Aboard',
      description: 'Welcome to Bybata! Complete your first login.',
      category: AchievementCategory.GENERAL,
      pointsRequired: null,
      pointsReward: 50,
      rarity: AchievementRarity.COMMON,
      iconUrl: '🎉',
      unlockCriteria: { eventType: 'FIRST_LOGIN' },
    },
    {
      slug: 'profile-perfectionist',
      name: 'Profile Perfectionist',
      description: 'Complete your profile with all required information.',
      category: AchievementCategory.GENERAL,
      pointsRequired: null,
      pointsReward: 100,
      rarity: AchievementRarity.COMMON,
      iconUrl: '👤',
      unlockCriteria: { eventType: 'PROFILE_COMPLETE' },
    },
    {
      slug: 'karma-collector',
      name: 'Karma Collector',
      description: 'Earn your first 100 karma points.',
      category: AchievementCategory.MILESTONES,
      pointsRequired: 100,
      pointsReward: 25,
      rarity: AchievementRarity.COMMON,
      iconUrl: '⭐',
    },
    {
      slug: 'rising-star',
      name: 'Rising Star',
      description: 'Earn 500 karma points.',
      category: AchievementCategory.MILESTONES,
      pointsRequired: 500,
      pointsReward: 100,
      rarity: AchievementRarity.UNCOMMON,
      iconUrl: '🌟',
    },
    {
      slug: 'karma-master',
      name: 'Karma Master',
      description: 'Earn 2000 karma points.',
      category: AchievementCategory.MILESTONES,
      pointsRequired: 2000,
      pointsReward: 250,
      rarity: AchievementRarity.RARE,
      iconUrl: '🏆',
    },
    {
      slug: 'legend',
      name: 'Legend',
      description: 'Earn 10000 karma points.',
      category: AchievementCategory.MILESTONES,
      pointsRequired: 10000,
      pointsReward: 500,
      rarity: AchievementRarity.LEGENDARY,
      iconUrl: '👑',
    },

    // Trading Achievements
    {
      slug: 'first-trader',
      name: 'First Trader',
      description: 'Post your first trade.',
      category: AchievementCategory.TRADING,
      pointsRequired: null,
      pointsReward: 75,
      rarity: AchievementRarity.COMMON,
      iconUrl: '🤝',
      unlockCriteria: { eventType: 'FIRST_TRADE_POSTED' },
    },
    {
      slug: 'deal-maker',
      name: 'Deal Maker',
      description: 'Complete your first trade.',
      category: AchievementCategory.TRADING,
      pointsRequired: null,
      pointsReward: 150,
      rarity: AchievementRarity.UNCOMMON,
      iconUrl: '💼',
      unlockCriteria: { eventType: 'FIRST_TRADE_COMPLETED' },
    },
    {
      slug: 'trade-veteran',
      name: 'Trade Veteran',
      description: 'Complete 10 successful trades.',
      category: AchievementCategory.TRADING,
      pointsRequired: null,
      pointsReward: 300,
      rarity: AchievementRarity.RARE,
      iconUrl: '🎯',
      unlockCriteria: { eventType: 'TRADE_COMPLETED', count: 10 },
    },

    // Donation Achievements
    {
      slug: 'generous-soul',
      name: 'Generous Soul',
      description: 'Make your first donation.',
      category: AchievementCategory.DONATIONS,
      pointsRequired: null,
      pointsReward: 100,
      rarity: AchievementRarity.COMMON,
      iconUrl: '💝',
      unlockCriteria: { eventType: 'FIRST_DONATION' },
    },
    {
      slug: 'philanthropist',
      name: 'Philanthropist',
      description: 'Donate to 5 different campaigns.',
      category: AchievementCategory.DONATIONS,
      pointsRequired: null,
      pointsReward: 250,
      rarity: AchievementRarity.UNCOMMON,
      iconUrl: '🤲',
      unlockCriteria: { eventType: 'DONATION_MADE', uniqueCampaigns: 5 },
    },

    // Gift Achievements
    {
      slug: 'gift-giver',
      name: 'Gift Giver',
      description: 'Give your first gift.',
      category: AchievementCategory.GIFTS,
      pointsRequired: null,
      pointsReward: 75,
      rarity: AchievementRarity.COMMON,
      iconUrl: '🎁',
      unlockCriteria: { eventType: 'FIRST_GIFT_GIVEN' },
    },
    {
      slug: 'santa-claus',
      name: 'Santa Claus',
      description: 'Give 10 gifts.',
      category: AchievementCategory.GIFTS,
      pointsRequired: null,
      pointsReward: 200,
      rarity: AchievementRarity.UNCOMMON,
      iconUrl: '🎅',
      unlockCriteria: { eventType: 'GIFT_GIVEN', count: 10 },
    },

    // Community Achievements
    {
      slug: 'community-explorer',
      name: 'Community Explorer',
      description: 'Join your first community.',
      category: AchievementCategory.COMMUNITY,
      pointsRequired: null,
      pointsReward: 50,
      rarity: AchievementRarity.COMMON,
      iconUrl: '🌍',
      unlockCriteria: { eventType: 'COMMUNITY_JOINED' },
    },
    {
      slug: 'social-butterfly',
      name: 'Social Butterfly',
      description: 'Join 5 communities.',
      category: AchievementCategory.COMMUNITY,
      pointsRequired: null,
      pointsReward: 150,
      rarity: AchievementRarity.UNCOMMON,
      iconUrl: '🦋',
      unlockCriteria: { eventType: 'COMMUNITY_JOINED', count: 5 },
    },
    {
      slug: 'content-creator',
      name: 'Content Creator',
      description: 'Create 10 community posts.',
      category: AchievementCategory.COMMUNITY,
      pointsRequired: null,
      pointsReward: 200,
      rarity: AchievementRarity.UNCOMMON,
      iconUrl: '📝',
      unlockCriteria: { eventType: 'COMMUNITY_POST', count: 10 },
    },

    // Social Achievements
    {
      slug: 'daily-devotee',
      name: 'Daily Devotee',
      description: 'Login for 7 consecutive days.',
      category: AchievementCategory.SOCIAL,
      pointsRequired: null,
      pointsReward: 100,
      rarity: AchievementRarity.UNCOMMON,
      iconUrl: '📅',
      unlockCriteria: { eventType: 'DAILY_LOGIN', streak: 7 },
    },
    {
      slug: 'streak-master',
      name: 'Streak Master',
      description: 'Login for 30 consecutive days.',
      category: AchievementCategory.SOCIAL,
      pointsRequired: null,
      pointsReward: 300,
      rarity: AchievementRarity.RARE,
      iconUrl: '🔥',
      unlockCriteria: { eventType: 'DAILY_LOGIN', streak: 30 },
    },
    {
      slug: 'verified-member',
      name: 'Verified Member',
      description: 'Get your profile verified.',
      category: AchievementCategory.SOCIAL,
      pointsRequired: null,
      pointsReward: 200,
      rarity: AchievementRarity.RARE,
      iconUrl: '✅',
      unlockCriteria: { eventType: 'PROFILE_VERIFIED' },
    },
  ];

  for (const achievement of achievements) {
    await prisma.achievement.upsert({
      where: { slug: achievement.slug },
      update: achievement,
      create: achievement,
    });
  }

  console.log(`Seeded ${achievements.length} achievements`);
}

if (require.main === module) {
  seedKarmaAchievements()
    .catch((e) => {
      console.error(e);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}