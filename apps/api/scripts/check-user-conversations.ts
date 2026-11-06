import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkUserConversations() {
  try {
    const userEmail = 'bob@example.com';
    
    console.log(`\n🔍 Checking conversations for user: ${userEmail}\n`);
    
    // Find the user
    const user = await prisma.user.findUnique({
      where: { email: userEmail },
      select: {
        id: true,
        email: true,
        profile: {
          select: {
            displayName: true,
          },
        },
      },
    });

    if (!user) {
      console.log(`❌ User ${userEmail} not found in database`);
      return;
    }

    console.log(`✅ User found:`);
    console.log(`   ID: ${user.id}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   Display Name: ${user.profile?.displayName || 'N/A'}\n`);

    // Check conversation participants
    const participants = await prisma.conversationParticipant.findMany({
      where: {
        userId: user.id,
        leftAt: null, // Only active participants
      },
      include: {
        conversation: {
          include: {
            participants: {
              where: { leftAt: null },
              include: {
                user: {
                  select: {
                    id: true,
                    email: true,
                    profile: {
                      select: {
                        displayName: true,
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
        },
      },
    });

    console.log(`📊 Conversation Participants Found: ${participants.length}\n`);

    if (participants.length === 0) {
      console.log('❌ No active conversations found for this user');
      console.log('\n💡 This means:');
      console.log('   - The user has not joined any conversations');
      console.log('   - OR all conversations have been left (leftAt is not null)');
      console.log('   - OR conversations exist but isActive is false');
    } else {
      console.log('✅ Active Conversations:\n');
      
      for (let i = 0; i < participants.length; i++) {
        const participant = participants[i];
        const conv = participant.conversation;
        const otherParticipants = conv.participants.filter(p => p.userId !== user.id);
        
        console.log(`   Conversation ${i + 1}:`);
        console.log(`   ├─ ID: ${conv.id}`);
        console.log(`   ├─ Type: ${conv.type}`);
        console.log(`   ├─ Title: ${conv.title || 'N/A'}`);
        console.log(`   ├─ Active: ${conv.isActive}`);
        console.log(`   ├─ Last Message At: ${conv.lastMessageAt || 'N/A'}`);
        console.log(`   ├─ Last Message: ${conv.lastMessage || 'N/A'}`);
        console.log(`   ├─ Message Count: ${conv._count.messages}`);
        console.log(`   ├─ Participants: ${conv.participants.length}`);
        
        if (otherParticipants.length > 0) {
          console.log(`   └─ Other Participants:`);
          otherParticipants.forEach((p, idx) => {
            console.log(`      ${idx + 1}. ${p.user.profile?.displayName || p.user.email} (${p.user.email})`);
          });
        } else {
          console.log(`   └─ No other participants`);
        }
        console.log('');
      }
    }

    // Also check all conversations (including inactive)
    const allParticipants = await prisma.conversationParticipant.findMany({
      where: {
        userId: user.id,
      },
      include: {
        conversation: {
          select: {
            id: true,
            type: true,
            isActive: true,
            title: true,
          },
        },
      },
    });

    const inactiveCount = allParticipants.filter(p => p.leftAt !== null || !p.conversation.isActive).length;
    
    if (inactiveCount > 0) {
      console.log(`\n📋 Inactive/Left Conversations: ${inactiveCount}`);
      console.log('   (These are not shown in the API response)\n');
    }

    // Check total conversations in database
    const totalConversations = await prisma.conversation.count();
    const activeConversations = await prisma.conversation.count({
      where: { isActive: true },
    });

    console.log(`\n📈 Database Statistics:`);
    console.log(`   Total Conversations: ${totalConversations}`);
    console.log(`   Active Conversations: ${activeConversations}`);
    console.log(`   Total Participants: ${await prisma.conversationParticipant.count()}`);
    console.log(`   Total Messages: ${await prisma.message.count()}\n`);

  } catch (error) {
    console.error('❌ Error checking conversations:', error);
  } finally {
    await prisma.$disconnect();
  }
}

checkUserConversations();

