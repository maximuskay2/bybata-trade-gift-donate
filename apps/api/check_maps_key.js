const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  
  try {
    const result = await prisma.appSetting.findUnique({
      where: { key: 'google_maps_api_key' }
    });
    
    console.log('Google Maps API Key setting:', result);
  } catch (error) {
    console.error('Error checking Google Maps API key:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();