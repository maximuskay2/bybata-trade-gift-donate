const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function testCommunityAccess() {
  console.log('Testing community access for creators...\n');
  
  // Test for Alice accessing Lagos Tech Community
  const alice = await prisma.user.findUnique({
    where: { email: 'alice@example.com' },
    select: { id: true, email: true }
  });

  const lagosCommunity = await prisma.community.findFirst({
    where: { name: 'Lagos Tech Community' },
    select: { id: true, name: true, createdById: true }
  });

  if (!alice || !lagosCommunity) {
    console.log('Alice or Lagos Tech Community not found');
    return;
  }

  console.log('Testing access for Alice to Lagos Tech Community...');
  console.log(`User: ${alice.email} (ID: ${alice.id})`);
  console.log(`Community: ${lagosCommunity.name} (ID: ${lagosCommunity.id})`);
  console.log(`Creator ID: ${lagosCommunity.createdById}\n`);

  // Check membership
  const membership = await prisma.communityMember.findUnique({
    where: {
      communityId_userId: {
        communityId: lagosCommunity.id,
        userId: alice.id
      }
    }
  });

  console.log('=== Membership Check ===');
  if (membership) {
    console.log(`✓ Alice IS a member`);
    console.log(`  Role: ${membership.role}`);
    console.log(`  Status: ${membership.status}`);
    console.log(`  Joined: ${membership.joinedAt}`);
  } else {
    console.log(`✗ Alice is NOT a member - THIS IS THE PROBLEM`);
  }

  // Check if creator
  const isCreator = alice.id === lagosCommunity.createdById;
  console.log(`\n=== Creator Check ===`);
  console.log(`Is Creator: ${isCreator ? 'YES ✓' : 'NO ✗'}`);

  // Check if owner role
  const isOwner = membership?.role === 'OWNER';
  console.log(`\n=== Owner Role Check ===`);
  console.log(`Has OWNER role: ${isOwner ? 'YES ✓' : 'NO ✗'}`);

  console.log(`\n=== Access Decision ===`);
  if (isCreator && isOwner && membership?.status === 'ACTIVE') {
    console.log('✓ Alice CAN access the community (Creator + Owner + Active Member)');
  } else if (isCreator && !membership) {
    console.log('✗ Alice CANNOT access (Creator but not in members table)');
  } else if (membership && membership.status !== 'ACTIVE') {
    console.log('✗ Alice CANNOT access (Member but not ACTIVE)');
  } else {
    console.log('✗ Alice CANNOT access (Unknown reason)');
  }
}

testCommunityAccess()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
