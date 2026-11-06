import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function testChatEndpoint() {
  try {
    const userEmail = 'bob@example.com';
    
    // Find the user
    const user = await prisma.user.findUnique({
      where: { email: userEmail },
      select: { id: true, email: true },
    });

    if (!user) {
      console.log(`❌ User ${userEmail} not found`);
      return;
    }

    console.log(`\n✅ Testing with user ID: ${user.id}\n`);

    // Simulate the exact query from chat.service.ts
    const whereClause = {
      participants: {
        some: {
          userId: user.id,
          leftAt: null,
        },
      },
      isActive: true,
    };

    console.log('Query whereClause:', JSON.stringify(whereClause, null, 2));

    const [conversations, total] = await Promise.all([
      prisma.conversation.findMany({
        where: whereClause,
        include: {
          participants: {
            where: { leftAt: null },
            include: {
              user: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true,
                    },
                  },
                },
              },
            },
          },
          _count: {
            select: {
              messages: true,
            },
          },
        },
        orderBy: {
          lastMessageAt: 'desc',
        },
        skip: 0,
        take: 20,
      }),
      prisma.conversation.count({
        where: whereClause,
      }),
    ]);

    console.log(`\n📊 Query Results:`);
    console.log(`   Total conversations found: ${total}`);
    console.log(`   Conversations returned: ${conversations.length}\n`);

    if (conversations.length === 0) {
      console.log('❌ No conversations found with the query');
      console.log('\n🔍 Debugging: Checking all participants for this user...\n');
      
      const allParticipants = await prisma.conversationParticipant.findMany({
        where: { userId: user.id },
        include: {
          conversation: {
            select: {
              id: true,
              type: true,
              isActive: true,
            },
          },
        },
      });

      console.log(`   Total participants (including left): ${allParticipants.length}`);
      allParticipants.forEach((p, i) => {
        console.log(`   ${i + 1}. Conversation ${p.conversation.id}:`);
        console.log(`      - Type: ${p.conversation.type}`);
        console.log(`      - Active: ${p.conversation.isActive}`);
        console.log(`      - Left At: ${p.leftAt || 'null (active)'}`);
      });
    } else {
      console.log('✅ Conversations found:\n');
      conversations.forEach((conv, i) => {
        console.log(`   ${i + 1}. ${conv.id}`);
        console.log(`      - Type: ${conv.type}`);
        console.log(`      - Title: ${conv.title || 'N/A'}`);
        console.log(`      - Active: ${conv.isActive}`);
        console.log(`      - Participants: ${conv.participants.length}`);
        console.log(`      - Messages: ${conv._count.messages}`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

testChatEndpoint();

