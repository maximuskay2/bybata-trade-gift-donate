const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Checking communities in database...\n');
  
  const communities = await prisma.community.findMany({
    include: {
      createdBy: {
        select: {
          id: true,
          email: true,
          profile: {
            select: {
              displayName: true
            }
          }
        }
      },
      members: {
        where: {
          status: 'ACTIVE'
        },
        include: {
          user: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true
                }
              }
            }
          }
        }
      }
    },
    orderBy: {
      createdAt: 'desc'
    }
  });

  console.log(`Total communities: ${communities.length}\n`);
  
  communities.forEach((community, index) => {
    console.log(`\n========== Community ${index + 1} ==========`);
    console.log(`ID: ${community.id}`);
    console.log(`Name: ${community.name}`);
    console.log(`Status: ${community.status}`);
    console.log(`Member Count: ${community.memberCount}`);
    console.log(`\nCreator/Owner:`);
    console.log(`  - User ID: ${community.createdBy.id}`);
    console.log(`  - Email: ${community.createdBy.email}`);
    console.log(`  - Display Name: ${community.createdBy.profile?.displayName || 'N/A'}`);
    
    console.log(`\nMembers (${community.members.length}):`);
    community.members.forEach((member) => {
      console.log(`  - ${member.user.email} (${member.user.profile?.displayName || 'N/A'}) - Role: ${member.role}`);
    });
    
    // Check if creator is in members list
    const creatorAsMember = community.members.find(m => m.userId === community.createdBy.id);
    console.log(`\nCreator in members list: ${creatorAsMember ? 'YES (Role: ' + creatorAsMember.role + ')' : 'NO - THIS IS THE PROBLEM!'}`);
  });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
