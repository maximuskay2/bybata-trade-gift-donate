const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Fixing communities without creator as member...\n');
  
  // Find all communities
  const communities = await prisma.community.findMany({
    include: {
      createdBy: {
        select: {
          id: true,
          email: true
        }
      },
      members: {
        where: {
          status: 'ACTIVE'
        }
      }
    }
  });

  let fixedCount = 0;

  for (const community of communities) {
    const creatorAsMember = community.members.find(m => m.userId === community.createdBy.id);
    
    if (!creatorAsMember) {
      console.log(`\nFixing community: ${community.name} (ID: ${community.id})`);
      console.log(`Adding creator ${community.createdBy.email} as OWNER member...`);
      
      // Add creator as OWNER member
      await prisma.communityMember.create({
        data: {
          communityId: community.id,
          userId: community.createdBy.id,
          role: 'OWNER',
          status: 'ACTIVE',
          joinedAt: community.createdAt // Use community creation date as join date
        }
      });
      
      // Update member count
      await prisma.community.update({
        where: { id: community.id },
        data: {
          memberCount: {
            increment: 1
          }
        }
      });
      
      console.log(`✓ Fixed!`);
      fixedCount++;
    } else {
      console.log(`✓ Community "${community.name}" already has creator as member (Role: ${creatorAsMember.role})`);
    }
  }

  console.log(`\n========================================`);
  console.log(`Total communities checked: ${communities.length}`);
  console.log(`Communities fixed: ${fixedCount}`);
  console.log(`========================================\n`);
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
