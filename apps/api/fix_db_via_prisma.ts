import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function fixConversionRate() {
  try {
    const result = await prisma.$executeRawUnsafe(`
      UPDATE "ConversionRate" 
      SET "updatedAt" = COALESCE("updatedAt", "createdAt", NOW())
      WHERE "updatedAt" IS NULL;
    `);
    console.log(`✅ Fixed ${result} ConversionRate records`);
  } catch (error) {
    console.error('❌ Error fixing ConversionRate:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

fixConversionRate();
