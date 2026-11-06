import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  const pending = await prisma.giftRequest.findMany({
    where: { status: 'PENDING' },
    include: {
      requester: { include: { profile: true } },
      gift: { include: { giver: { include: { profile: true } } } },
    },
    orderBy: { createdAt: 'desc' },
  })

  if (pending.length === 0) {
    console.log('No pending gift requests found.')
    return
  }

  const rows = pending.map((r) => ({
    requestId: r.id,
    createdAt: r.createdAt.toISOString(),
    giftId: r.giftId,
    giftTitle: r.gift.title,
    requesterId: r.requesterId,
    requesterEmail: r.requester.email,
    requesterName: r.requester.profile?.displayName ?? null,
    ownerId: r.gift.giverId,
    ownerEmail: r.gift.giver.email,
    ownerName: r.gift.giver.profile?.displayName ?? null,
    message: r.message ?? null,
  }))

  console.table(rows)
}

main()
  .catch((err) => {
    console.error('Error listing pending gift requests:', err)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })