const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const communityId = 'cminhs1ov002d2xa7xxaqbibs'; // Kilimanjaro Champion
  const userId = 'cmim5fzzr00002x5rm2qmtiwg'; // Alice
  
  console.log('\n=== Debugging Kilimanjaro Champion Access ===\n');
  console.log('Community ID:', communityId);
  console.log('User ID:', userId);
  
  // Check community
  const community = await prisma.community.findUnique({
    where: { id: communityId },
    select: {
      id: true,
      name: true,
      createdById: true,
      status: true,
    }
  });
  
  console.log('\nCommunity:');
  console.log(JSON.stringify(community, null, 2));
  
  // Check membership
  const membership = await prisma.communityMember.findUnique({
    where: {
      communityId_userId: {
        communityId,
        userId
      }
    }
  });
  
  console.log('\nMembership:');
  console.log(membership ? JSON.stringify(membership, null, 2) : 'NOT FOUND');
  
  // List all members
  const allMembers = await prisma.communityMember.findMany({
    where: { communityId },
    include: {
      user: {
        select: {
          email: true
        }
      }
    }
  });
  
  console.log('\nAll members:');
  console.log(JSON.stringify(allMembers, null, 2));
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
