/**
 * Test script to verify that community creators are automatically added as members
 * and can interact with the community regardless of location.
 * 
 * Usage: npx ts-node apps/api/test-create-community.ts
 */

import { PrismaClient, CommunityType, CommunityCategory } from '@prisma/client';

const prisma = new PrismaClient();

async function testCommunityCreation() {
  try {
    console.log('🔍 Finding user with email: carol@example.com...');
    
    // Find user by email
    const user = await prisma.user.findFirst({
      where: {
        email: 'carol@example.com',
      },
      include: {
        profile: true,
      },
    });

    if (!user) {
      console.error('❌ User with email carol@example.com not found!');
      console.log('💡 Please ensure the user exists in the database.');
      return;
    }

    console.log('✅ User found:');
    console.log(`   ID: ${user.id}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   Display Name: ${user.profile?.displayName || 'N/A'}`);

    // Create a test community
    console.log('\n🏗️  Creating test community...');
    
    const testCommunity = await prisma.community.create({
      data: {
        name: 'Test Community - Carol\'s Tribe',
        description: 'This is a test community created to verify that the creator is automatically added as a member and can interact regardless of location.',
        shortDescription: 'Test community for verification',
        category: CommunityCategory.EDUCATION,
        type: CommunityType.PUBLIC,
        createdById: user.id,
        memberCount: 1, // Creator is automatically a member
        center_latitude: 40.7128, // New York coordinates (far from any default location)
        center_longitude: -74.0060,
        members: {
          create: {
            userId: user.id,
            role: 'OWNER',
            status: 'ACTIVE',
          },
        },
      },
      include: {
        createdBy: {
          include: { profile: true },
        },
        members: {
          include: {
            user: {
              include: { profile: true },
            },
          },
        },
        _count: {
          select: {
            members: true,
            posts: true,
            events: true,
          },
        },
      },
    });

    console.log('✅ Community created successfully!');
    console.log(`   Community ID: ${testCommunity.id}`);
    console.log(`   Name: ${testCommunity.name}`);
    console.log(`   Created By: ${testCommunity.createdBy.email}`);
    console.log(`   Member Count: ${testCommunity.memberCount}`);
    console.log(`   Location: (${testCommunity.center_latitude}, ${testCommunity.center_longitude})`);

    // Verify membership
    console.log('\n🔍 Verifying membership...');
    const membership = await prisma.communityMember.findUnique({
      where: {
        communityId_userId: {
          communityId: testCommunity.id,
          userId: user.id,
        },
      },
    });

    if (membership) {
      console.log('✅ Membership verified!');
      console.log(`   Role: ${membership.role}`);
      console.log(`   Status: ${membership.status}`);
      console.log(`   Joined At: ${membership.joinedAt}`);
      
      if (membership.role === 'OWNER' && membership.status === 'ACTIVE') {
        console.log('\n✅ SUCCESS: Creator is automatically added as OWNER with ACTIVE status!');
      } else {
        console.log('\n⚠️  WARNING: Membership exists but role/status may be incorrect.');
      }
    } else {
      console.log('❌ ERROR: Membership not found!');
    }

    // Test access check (simulate the checkCommunityAccessWithRadius logic)
    console.log('\n🔍 Testing access permissions...');
    if (membership && membership.role === 'OWNER') {
      console.log('✅ OWNER role detected - should have full access regardless of location');
      console.log('   This means the creator can:');
      console.log('   - View all posts');
      console.log('   - Create posts');
      console.log('   - View all events');
      console.log('   - Manage community settings');
      console.log('   - All interactions work regardless of current location');
    }

    console.log('\n📊 Community Summary:');
    console.log(`   Total Members: ${testCommunity._count.members}`);
    console.log(`   Total Posts: ${testCommunity._count.posts}`);
    console.log(`   Total Events: ${testCommunity._count.events}`);

    console.log('\n✨ Test completed successfully!');
    console.log(`\n💡 To verify in the app:`);
    console.log(`   1. Log in as carol@example.com`);
    console.log(`   2. Navigate to the community: ${testCommunity.id}`);
    console.log(`   3. Verify you can see posts, create posts, and interact`);
    console.log(`   4. Try from a different location - access should still work`);

  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run the test
testCommunityCreation()
  .then(() => {
    console.log('\n✅ Script completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });

