import { PrismaClient, GiftType, GiftCategory, GiftStatus } from '@prisma/client';
import * as zlib from 'zlib';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

// Directory for storing generated gift images
const IMAGES_DIR = path.join(__dirname, '../src/assets/gift-images');

// Ensure images directory exists
if (!fs.existsSync(IMAGES_DIR)) {
  fs.mkdirSync(IMAGES_DIR, { recursive: true });
  console.log(`📁 Created images directory: ${IMAGES_DIR}`);
}

// Gift templates with different categories and types
const giftTemplates = [
  {
    title: 'Free Programming Book Collection',
    description: 'A curated collection of programming books covering JavaScript, Python, React, and more. Perfect for developers looking to expand their knowledge.',
    type: GiftType.RANDOM,
    category: GiftCategory.BOOKS,
    karmaReward: 50,
    tags: ['programming', 'books', 'education'],
    color: '#4A90E2', // Blue
  },
  {
    title: 'Tech Mentoring Session',
    description: 'One-on-one mentoring session covering career advice, code review, and technical guidance. Perfect for junior developers.',
    type: GiftType.SKILL,
    category: GiftCategory.EDUCATION,
    karmaReward: 100,
    tags: ['mentoring', 'career', 'technology'],
    color: '#50C878', // Green
  },
  {
    title: 'Designer Accessories Collection',
    description: 'Beautiful collection of designer accessories and items in excellent condition. Perfect for fashion enthusiasts.',
    type: GiftType.RANDOM,
    category: GiftCategory.CLOTHING,
    karmaReward: 75,
    tags: ['fashion', 'designer', 'accessories'],
    color: '#E91E63', // Pink
  },
  {
    title: 'Premium Development Tools',
    description: 'Collection of premium development tools and resources including IDE licenses, API keys, and software subscriptions.',
    type: GiftType.DIGITAL,
    category: GiftCategory.TECHNOLOGY,
    karmaReward: 80,
    tags: ['technology', 'development', 'tools'],
    color: '#9C27B0', // Purple
  },
  {
    title: 'Healthy Meal Voucher',
    description: 'Voucher for healthy meals at local restaurants. Perfect for those looking to maintain a healthy lifestyle.',
    type: GiftType.RANDOM,
    category: GiftCategory.FOOD,
    karmaReward: 40,
    tags: ['food', 'health', 'voucher'],
    color: '#FF9800', // Orange
  },
  {
    title: 'Fitness Equipment Bundle',
    description: 'Collection of fitness equipment including resistance bands, yoga mat, and workout accessories.',
    type: GiftType.RANDOM,
    category: GiftCategory.SPORTS,
    karmaReward: 60,
    tags: ['fitness', 'sports', 'health'],
    color: '#F44336', // Red
  },
  {
    title: 'Art Supplies Collection',
    description: 'Complete art supplies collection including paints, brushes, canvases, and drawing materials.',
    type: GiftType.RANDOM,
    category: GiftCategory.ARTS,
    karmaReward: 55,
    tags: ['art', 'creativity', 'supplies'],
    color: '#FF5722', // Deep Orange
  },
  {
    title: 'Electronics Bundle',
    description: 'Collection of electronics including cables, adapters, and tech accessories in excellent condition.',
    type: GiftType.RANDOM,
    category: GiftCategory.ELECTRONICS,
    karmaReward: 70,
    tags: ['electronics', 'tech', 'accessories'],
    color: '#2196F3', // Light Blue
  },
];

/**
 * Generate a simple solid-color PNG image
 * Creates a minimal valid PNG with a solid color background
 */
function generateSimplePNG(
  width: number,
  height: number,
  backgroundColor: string,
): Buffer {
  // Parse hex color to RGB
  const hex = backgroundColor.replace('#', '');
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);

  // PNG signature
  const pngSignature = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  
  // Helper to calculate CRC32
  const crc32 = (data: Buffer): number => {
    const table: number[] = [];
    for (let i = 0; i < 256; i++) {
      let c = i;
      for (let j = 0; j < 8; j++) {
        c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[i] = c;
    }
    let crc = 0xFFFFFFFF;
    for (let i = 0; i < data.length; i++) {
      crc = table[(crc ^ data[i]) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) >>> 0;
  };

  // Helper to create PNG chunk
  const createChunk = (type: string, data: Buffer): Buffer => {
    const typeBuf = Buffer.from(type, 'ascii');
    const chunkData = Buffer.concat([typeBuf, data]);
    const crc = crc32(chunkData);
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length, 0);
    const crcBuf = Buffer.alloc(4);
    crcBuf.writeUInt32BE(crc, 0);
    return Buffer.concat([length, chunkData, crcBuf]);
  };

  // IHDR chunk
  const ihdrData = Buffer.alloc(13);
  ihdrData.writeUInt32BE(width, 0);
  ihdrData.writeUInt32BE(height, 4);
  ihdrData[8] = 8; // bit depth
  ihdrData[9] = 2; // color type (RGB)
  ihdrData[10] = 0; // compression
  ihdrData[11] = 0; // filter
  ihdrData[12] = 0; // interlace
  const ihdr = createChunk('IHDR', ihdrData);

  // IDAT chunk - create pixel data (RGB for each pixel)
  const rowSize = width * 3 + 1; // +1 for filter byte
  const imageData = Buffer.alloc(height * rowSize);
  for (let y = 0; y < height; y++) {
    const rowStart = y * rowSize;
    imageData[rowStart] = 0; // filter type (none)
    for (let x = 0; x < width; x++) {
      const pixelStart = rowStart + 1 + x * 3;
      imageData[pixelStart] = r;
      imageData[pixelStart + 1] = g;
      imageData[pixelStart + 2] = b;
    }
  }
  
  // Compress the image data using zlib
  const compressed = zlib.deflateSync(imageData, { level: 9 });
  const idat = createChunk('IDAT', compressed);

  // IEND chunk
  const iend = createChunk('IEND', Buffer.alloc(0));

  return Buffer.concat([pngSignature, ihdr, idat, iend]);
}

/**
 * Save image locally and return the relative path/key
 */
function saveImageLocally(
  userId: string,
  imageBuffer: Buffer,
  giftTitle: string,
  index: number,
): string {
  try {
    // Create a safe filename from gift title and user ID
    const safeTitle = giftTitle
      .replace(/[^a-zA-Z0-9]/g, '_')
      .substring(0, 30)
      .toLowerCase();
    const timestamp = Date.now();
    const userPrefix = userId.substring(0, 8);
    const filename = `gift_${userPrefix}_${safeTitle}_${timestamp}_${index}.png`;
    
    // Create user-specific subdirectory
    const userDir = path.join(IMAGES_DIR, userPrefix);
    if (!fs.existsSync(userDir)) {
      fs.mkdirSync(userDir, { recursive: true });
    }
    
    const filepath = path.join(userDir, filename);
    
    // Write image to file
    fs.writeFileSync(filepath, imageBuffer);
    
    // Return a key that can be used to reference the image
    // Using a path relative to src/assets for easier access
    return `gifts/${userPrefix}/${filename}`;
  } catch (error) {
    console.error(`Failed to save image for gift "${giftTitle}":`, error);
    // Return empty string if save fails - gift will be created without image
    return '';
  }
}

async function main() {
  console.log('🌱 Starting gift seeding with images...\n');

  try {
    // Step 1: Delete all existing gifts and related records
    console.log('🗑️  Deleting all existing gifts and related records...');
    
    // Delete in order to respect foreign key constraints
    await prisma.giftRequest.deleteMany({});
    await prisma.giftClaim.deleteMany({});
    await prisma.giftComment.deleteMany({});
    await prisma.giftLike.deleteMany({});
    await prisma.gift.deleteMany({});
    
    console.log('✅ All existing gifts deleted\n');

    // Step 2: Get all users
    console.log('👥 Fetching all users...');
    const users = await prisma.user.findMany({
      where: {
        // Exclude admin users if needed, or include all
      },
    });
    console.log(`✅ Found ${users.length} users\n`);

    if (users.length === 0) {
      console.log('⚠️  No users found. Please seed users first.');
      return;
    }

    // Step 3: Create 2 gifts for each user
    console.log('🎁 Creating 2 gifts per user with images...\n');
    let totalGiftsCreated = 0;
    let totalImagesUploaded = 0;

    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      console.log(`Processing user ${i + 1}/${users.length}: ${user.email}`);

      // Select 2 different gift templates for this user
      const templateIndex1 = i % giftTemplates.length;
      const templateIndex2 = (i + Math.floor(i / giftTemplates.length) + 1) % giftTemplates.length;
      
      const template1 = giftTemplates[templateIndex1];
      const template2 = giftTemplates[templateIndex2];

      // Create first gift
      try {
        // Generate image for first gift
        let imageKey1 = '';
        try {
          const imageBuffer1 = generateSimplePNG(
            800,
            600,
            template1.color,
          );
          imageKey1 = saveImageLocally(
            user.id,
            imageBuffer1,
            template1.title,
            1,
          );
        } catch (imageError) {
          console.error(`  ⚠️  Failed to generate/save image for gift 1: ${imageError}`);
        }

        const gift1 = await prisma.gift.create({
          data: {
            giverId: user.id,
            title: `${template1.title} (${user.email})`,
            description: template1.description,
            type: template1.type,
            category: template1.category,
            status: GiftStatus.ACTIVE,
            mediaKeys: imageKey1 ? [imageKey1] : [],
            karmaReward: template1.karmaReward,
            maxClaims: Math.floor(Math.random() * 3) + 1, // 1-3 claims
            currentClaims: 0,
            tags: template1.tags,
            expiresAt: new Date(Date.now() + (30 + Math.random() * 60) * 24 * 60 * 60 * 1000), // 30-90 days
          },
        });

        console.log(`  ✅ Created gift 1: "${gift1.title}" ${imageKey1 ? `(image: ${imageKey1})` : '(no image)'}`);
        totalGiftsCreated++;
        if (imageKey1) totalImagesUploaded++;

        // Generate image for second gift
        let imageKey2 = '';
        try {
          const imageBuffer2 = generateSimplePNG(
            800,
            600,
            template2.color,
          );
          imageKey2 = saveImageLocally(
            user.id,
            imageBuffer2,
            template2.title,
            2,
          );
        } catch (imageError) {
          console.error(`  ⚠️  Failed to generate/save image for gift 2: ${imageError}`);
        }

        const gift2 = await prisma.gift.create({
          data: {
            giverId: user.id,
            title: `${template2.title} (${user.email})`,
            description: template2.description,
            type: template2.type,
            category: template2.category,
            status: GiftStatus.ACTIVE,
            mediaKeys: imageKey2 ? [imageKey2] : [],
            karmaReward: template2.karmaReward,
            maxClaims: Math.floor(Math.random() * 3) + 1, // 1-3 claims
            currentClaims: 0,
            tags: template2.tags,
            expiresAt: new Date(Date.now() + (30 + Math.random() * 60) * 24 * 60 * 60 * 1000), // 30-90 days
          },
        });

        console.log(`  ✅ Created gift 2: "${gift2.title}" ${imageKey2 ? `(image: ${imageKey2})` : '(no image)'}`);
        totalGiftsCreated++;
        if (imageKey2) totalImagesUploaded++;
      } catch (error) {
        console.error(`  ❌ Failed to create gifts for user ${user.email}:`, error);
      }

      console.log('');
    }

    console.log('✅ Gift seeding completed!');
    console.log(`📊 Summary:`);
    console.log(`   - Total gifts created: ${totalGiftsCreated}`);
    console.log(`   - Total images saved: ${totalImagesUploaded}`);
    console.log(`   - Users processed: ${users.length}`);
    console.log(`   - Images directory: ${IMAGES_DIR}`);
  } catch (error) {
    console.error('❌ Error during seeding:', error);
    throw error;
  }
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

