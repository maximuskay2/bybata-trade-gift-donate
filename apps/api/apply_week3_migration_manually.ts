import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function applyWeek3Migration() {
  try {
    console.log('🔄 Applying Week 3 migration manually...\n');

    // Step 1: Add columns (updatedAt with default for existing rows)
    console.log('Step 1: Adding columns to ConversionRate...');
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "ConversionRate" ADD COLUMN IF NOT EXISTS "changeReason" TEXT;
    `);
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "ConversionRate" ADD COLUMN IF NOT EXISTS "createdBy" TEXT;
    `);
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "ConversionRate" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) DEFAULT NOW();
    `);
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "ConversionRate" ADD COLUMN IF NOT EXISTS "updatedBy" TEXT;
    `);
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "ConversionRate" ADD COLUMN IF NOT EXISTS "validFrom" TIMESTAMP(3);
    `);
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "ConversionRate" ADD COLUMN IF NOT EXISTS "validTo" TIMESTAMP(3);
    `);
    console.log('✅ Columns added\n');

    // Step 2: Update existing rows
    console.log('Step 2: Updating existing rows...');
    const updateResult = await prisma.$executeRawUnsafe(`
      UPDATE "ConversionRate" 
      SET "updatedAt" = COALESCE("updatedAt", "createdAt", NOW())
      WHERE "updatedAt" IS NULL;
    `);
    console.log(`✅ Updated ${updateResult} rows\n`);

    // Step 3: Make updatedAt NOT NULL
    console.log('Step 3: Making updatedAt NOT NULL...');
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "ConversionRate" ALTER COLUMN "updatedAt" SET NOT NULL;
    `);
    console.log('✅ updatedAt is now NOT NULL\n');

    // Step 4: Create indexes
    console.log('Step 4: Creating indexes...');
    await prisma.$executeRawUnsafe(`
      CREATE INDEX IF NOT EXISTS "ConversionRate_base_quote_active_idx" 
      ON "ConversionRate"("base", "quote", "active");
    `);
    await prisma.$executeRawUnsafe(`
      CREATE INDEX IF NOT EXISTS "ConversionRate_validFrom_validTo_idx" 
      ON "ConversionRate"("validFrom", "validTo");
    `);
    console.log('✅ Indexes created\n');

    console.log('🎉 Week 3 migration applied successfully!');
    console.log('\nNext step: Run: npx prisma migrate dev --name week3_schema_changes');
  } catch (error) {
    console.error('❌ Error applying migration:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

applyWeek3Migration();

