import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  const users = await prisma.user.findMany({
    include: {
      profile: true
    },
    orderBy: {
      createdAt: 'desc'
    }
  });

  console.log(`Found ${users.length} users:`);
  console.log('='.repeat(80));

  users.forEach((user, index) => {
    console.log(`${index + 1}. ID: ${user.id}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   Role: ${user.role}`);
    console.log(`   Banned: ${user.banned}`);
    console.log(`   Email Verified: ${user.emailVerifiedAt ? 'Yes' : 'No'}`);
    console.log(`   Created: ${user.createdAt.toISOString()}`);
    if (user.profile) {
      console.log(`   Display Name: ${user.profile.displayName}`);
      console.log(`   Bio: ${user.profile.bio || 'N/A'}`);
      console.log(`   Phone: ${user.profile.phone || 'N/A'}`);
      console.log(`   KYC Status: ${user.profile.kycStatus}`);
    } else {
      console.log(`   Profile: Not created`);
    }
    console.log('   ---');
  });

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});