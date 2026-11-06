import { PrismaClient, GiftCategory, GiftStatus, GiftType, GiftRequestStatus } from '@prisma/client'
import bcrypt from 'bcrypt'

const prisma = new PrismaClient()

async function upsertUser(email: string, displayName: string, password = 'password123') {
  const passwordHash = await bcrypt.hash(password, 10)
  const user = await prisma.user.upsert({
    where: { email },
    update: {},
    create: {
      email,
      passwordHash,
      profile: {
        create: { displayName }
      }
    }
  })
  return user
}

async function main() {
  // 1) Ensure Carol (giver) and Alice (claimer) exist
  const carol = await upsertUser('carol@example.com', 'Carol')
  const alice = await upsertUser('alice@example.com', 'Alice')

  // 2) Create a gift owned by Carol (ACTIVE)
  const gift = await prisma.gift.create({
    data: {
      giverId: carol.id,
      title: 'Flow Gift - Carol → Alice',
      description: 'Gift for flow verification: pending request visible to both',
      type: GiftType.RANDOM,
      category: GiftCategory.OTHERS,
      status: GiftStatus.ACTIVE,
      mediaKeys: [],
      karmaReward: 10,
      maxClaims: 1,
      currentClaims: 0,
      tags: ['flow', 'verification']
    }
  })

  // 3) Create a pending gift request by Alice (do not approve)
  const request = await prisma.giftRequest.create({
    data: {
      giftId: gift.id,
      requesterId: alice.id,
      message: 'Alice would like to claim this gift',
      status: GiftRequestStatus.PENDING,
    },
    include: {
      gift: { include: { giver: { include: { profile: true } } } },
      requester: { include: { profile: true } }
    }
  })

  console.log('Seeded pending request:', {
    requestId: request.id,
    giftId: gift.id,
    giftTitle: gift.title,
    requesterEmail: 'alice@example.com',
    ownerEmail: 'carol@example.com'
  })

  // 4) Verify pending requests visible for both users
  // Carol: requests made by Carol OR requests for Carol's gifts
  const carolGiftIds = [gift.id]
  const carolRequests = await prisma.giftRequest.findMany({
    where: {
      status: GiftRequestStatus.PENDING,
      OR: [{ requesterId: carol.id }, { giftId: { in: carolGiftIds } }]
    },
    include: {
      gift: { include: { giver: { include: { profile: true } } } },
      requester: { include: { profile: true } }
    },
    orderBy: { createdAt: 'desc' }
  })

  const aliceRequests = await prisma.giftRequest.findMany({
    where: {
      status: GiftRequestStatus.PENDING,
      OR: [{ requesterId: alice.id }]
    },
    include: {
      gift: { include: { giver: { include: { profile: true } } } },
      requester: { include: { profile: true } }
    },
    orderBy: { createdAt: 'desc' }
  })

  console.log('\nPending requests visible to Carol (owner):')
  console.table(carolRequests.map(r => ({
    requestId: r.id,
    giftTitle: r.gift.title,
    requesterName: r.requester.profile?.displayName,
    status: r.status,
    createdAt: r.createdAt.toISOString(),
  })))

  console.log('\nPending requests visible to Alice (claimer):')
  console.table(aliceRequests.map(r => ({
    requestId: r.id,
    giftTitle: r.gift.title,
    ownerName: r.gift.giver.profile?.displayName,
    status: r.status,
    createdAt: r.createdAt.toISOString(),
  })))
}

main()
  .catch((err) => {
    console.error('Error seeding gift flow:', err)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })