const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function debugCommunityVisibility() {
  console.log('Debugging community visibility...\n');
  
  const communities = await prisma.community.findMany({
    select: {
      id: true,
      name: true,
      status: true,
      center_latitude: true,
      center_longitude: true,
      createdAt: true,
      memberCount: true,
      createdBy: {
        select: { email: true }
      }
    },
    orderBy: { createdAt: 'desc' }
  });

  console.log(`Total communities in database: ${communities.length}\n`);
  
  communities.forEach((c, i) => {
    console.log(`${i + 1}. ${c.name}`);
    console.log(`   Status: ${c.status}`);
    console.log(`   Has GPS coordinates: ${c.center_latitude && c.center_longitude ? 'YES' : 'NO'}`);
    if (c.center_latitude && c.center_longitude) {
      console.log(`   Lat: ${c.center_latitude}, Lng: ${c.center_longitude}`);
    }
    console.log(`   Member Count: ${c.memberCount}`);
    console.log(`   Creator: ${c.createdBy.email}`);
    console.log(`   Created: ${c.createdAt}`);
    console.log('');
  });

  // Check what the /nearby endpoint would return
  console.log('=== Checking nearby endpoint criteria ===');
  const activeWithCoords = communities.filter(c => 
    c.status === 'ACTIVE' && 
    c.center_latitude !== null && 
    c.center_longitude !== null
  );
  
  console.log(`Communities that meet /nearby criteria: ${activeWithCoords.length}`);
  activeWithCoords.forEach(c => {
    console.log(`  ✓ ${c.name}`);
  });

  const activeWithoutCoords = communities.filter(c => 
    c.status === 'ACTIVE' && 
    (c.center_latitude === null || c.center_longitude === null)
  );
  
  if (activeWithoutCoords.length > 0) {
    console.log(`\n❌ Communities MISSING GPS coordinates (won't show in discover):`);
    activeWithoutCoords.forEach(c => {
      console.log(`  - ${c.name} (Creator: ${c.createdBy.email})`);
    });
  }
}

debugCommunityVisibility()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
