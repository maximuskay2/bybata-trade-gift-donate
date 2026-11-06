/**
 * Purge ALL trades, gifts, campaigns/donations and related rows.
 *
 * Usage:
 *   npx ts-node -r dotenv/config scripts/purge-listing-data.ts --dry-run
 *   npx ts-node -r dotenv/config scripts/purge-listing-data.ts --confirm PURGE_PRODUCTION
 *
 * Requires DATABASE_URL (use Railway prod URL only when intentional).
 */
import 'dotenv/config';
import { KarmaEventType, PrismaClient, TransactionType } from '@prisma/client';

const prisma = new PrismaClient();

const CONFIRM_TOKEN = 'PURGE_PRODUCTION';

const LISTING_REFERENCE_TYPES = [
  'trade',
  'gift',
  'campaign',
  'donation',
  'boost',
  'promotion',
];

const LISTING_WALLET_TYPES: TransactionType[] = [
  TransactionType.PROMOTION,
  TransactionType.DONATION,
  TransactionType.ADVERT,
];

const LISTING_KARMA_TYPES: KarmaEventType[] = [
  KarmaEventType.FIRST_TRADE_POSTED,
  KarmaEventType.FIRST_TRADE_COMPLETED,
  KarmaEventType.TRADE_COMPLETED,
  KarmaEventType.FIRST_DONATION,
  KarmaEventType.DONATION_MADE,
  KarmaEventType.FIRST_GIFT_GIVEN,
  KarmaEventType.GIFT_GIVEN,
  KarmaEventType.GIFT_CLAIMED,
];

const LISTING_REVIEW_SOURCES = ['TRADE', 'GIFT', 'DONATION'];

type Counts = Record<string, number>;

function parseArgs() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const confirmIdx = args.indexOf('--confirm');
  const confirm =
    confirmIdx >= 0 ? args[confirmIdx + 1] : undefined;
  return { dryRun, confirm };
}

async function countAll(): Promise<Counts> {
  const [
    negotiationMessage,
    negotiation,
    tradeOffer,
    tradeComment,
    trade,
    giftClaim,
    giftRequest,
    giftLike,
    giftClaimBlock,
    giftComment,
    gift,
    donationReward,
    donation,
    rewardTier,
    campaignUpdate,
    campaignComment,
    campaign,
    boostPurchase,
    listingWalletTx,
    listingReviews,
    listingKarma,
    listingNotifications,
    linkedPosts,
    promotion,
    adSchedule,
  ] = await Promise.all([
    prisma.negotiationMessage.count(),
    prisma.negotiation.count(),
    prisma.tradeOffer.count(),
    prisma.tradeComment.count(),
    prisma.trade.count(),
    prisma.giftClaim.count(),
    prisma.giftRequest.count(),
    prisma.giftLike.count(),
    prisma.giftClaimBlock.count(),
    prisma.giftComment.count(),
    prisma.gift.count(),
    prisma.donationReward.count(),
    prisma.donation.count(),
    prisma.rewardTier.count(),
    prisma.campaignUpdate.count(),
    prisma.campaignComment.count(),
    prisma.campaign.count(),
    prisma.boostPurchase.count(),
    prisma.walletTransaction.count({
      where: {
        OR: [
          { type: { in: LISTING_WALLET_TYPES } },
          {
            referenceType: {
              in: LISTING_REFERENCE_TYPES,
              mode: 'insensitive',
            },
          },
          { promotionId: { not: null } },
        ],
      },
    }),
    prisma.profileReview.count({
      where: { sourceType: { in: LISTING_REVIEW_SOURCES } },
    }),
    prisma.karmaEvent.count({
      where: { type: { in: LISTING_KARMA_TYPES } },
    }),
    prisma.notification.count({
      where: {
        sourceType: {
          in: ['trade', 'gift', 'campaign', 'donation', 'TRADE', 'GIFT', 'CAMPAIGN', 'DONATION'],
        },
      },
    }),
    prisma.communityPost.count({
      where: {
        OR: [
          { linkedTradeId: { not: null } },
          { linkedGiftId: { not: null } },
          { linkedCampaignId: { not: null } },
        ],
      },
    }),
    prisma.promotion.count(),
    prisma.adSchedule.count({
      where: {
        transaction: {
          OR: [
            { type: { in: LISTING_WALLET_TYPES } },
            {
              referenceType: {
                in: LISTING_REFERENCE_TYPES,
                mode: 'insensitive',
              },
            },
            { promotionId: { not: null } },
          ],
        },
      },
    }),
  ]);

  return {
    negotiationMessage,
    negotiation,
    tradeOffer,
    tradeComment,
    trade,
    giftClaim,
    giftRequest,
    giftLike,
    giftClaimBlock,
    giftComment,
    gift,
    donationReward,
    donation,
    rewardTier,
    campaignUpdate,
    campaignComment,
    campaign,
    boostPurchase,
    listingWalletTx,
    listingReviews,
    listingKarma,
    listingNotifications,
    linkedPosts,
    promotion,
    adSchedule,
  };
}

function printCounts(label: string, counts: Counts) {
  console.log(`\n${label}`);
  console.log('─'.repeat(40));
  for (const [key, value] of Object.entries(counts)) {
    console.log(`  ${key.padEnd(22)} ${value}`);
  }
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  console.log('─'.repeat(40));
  console.log(`  ${'TOTAL ROWS'.padEnd(22)} ${total}`);
}

async function purge(): Promise<Counts> {
  const deleted: Counts = {};

  await prisma.$transaction(
    async (tx) => {
      // ── Trades / offers / negotiations ──
      deleted.negotiationMessage = (
        await tx.negotiationMessage.deleteMany({})
      ).count;
      deleted.negotiation = (await tx.negotiation.deleteMany({})).count;

      await tx.trade.updateMany({
        data: { acceptedOfferId: null, activePromotionId: null },
      });
      await tx.tradeOffer.updateMany({
        data: {
          offeredTradeId: null,
          requestedTradeId: null,
          parentOfferId: null,
        },
      });
      deleted.tradeOffer = (await tx.tradeOffer.deleteMany({})).count;
      await tx.tradeComment.updateMany({ data: { parentId: null } });
      deleted.tradeComment = (await tx.tradeComment.deleteMany({})).count;
      deleted.trade = (await tx.trade.deleteMany({})).count;

      // ── Campaigns / donations ──
      deleted.donationReward = (await tx.donationReward.deleteMany({})).count;
      deleted.donation = (await tx.donation.deleteMany({})).count;
      deleted.rewardTier = (await tx.rewardTier.deleteMany({})).count;
      deleted.campaignUpdate = (await tx.campaignUpdate.deleteMany({})).count;
      await tx.campaignComment.updateMany({ data: { parentId: null } });
      deleted.campaignComment = (await tx.campaignComment.deleteMany({})).count;
      deleted.campaign = (await tx.campaign.deleteMany({})).count;

      // ── Gifts ──
      deleted.giftClaim = (await tx.giftClaim.deleteMany({})).count;
      deleted.giftRequest = (await tx.giftRequest.deleteMany({})).count;
      deleted.giftLike = (await tx.giftLike.deleteMany({})).count;
      deleted.giftClaimBlock = (await tx.giftClaimBlock.deleteMany({})).count;
      await tx.giftComment.updateMany({ data: { parentId: null } });
      deleted.giftComment = (await tx.giftComment.deleteMany({})).count;
      await tx.gift.updateMany({ data: { chainParentId: null } });
      deleted.gift = (await tx.gift.deleteMany({})).count;

      // ── Community links ──
      deleted.linkedPosts = (
        await tx.communityPost.updateMany({
          data: {
            linkedTradeId: null,
            linkedGiftId: null,
            linkedCampaignId: null,
          },
        })
      ).count;

      // ── Boosts & listing wallet activity ──
      deleted.boostPurchase = (await tx.boostPurchase.deleteMany({})).count;
      deleted.adSchedule = (
        await tx.adSchedule.deleteMany({
          where: {
            transaction: {
              OR: [
                { type: { in: LISTING_WALLET_TYPES } },
                {
                  referenceType: {
                    in: LISTING_REFERENCE_TYPES,
                    mode: 'insensitive',
                  },
                },
                { promotionId: { not: null } },
              ],
            },
          },
        })
      ).count;
      deleted.listingWalletTx = (
        await tx.walletTransaction.deleteMany({
          where: {
            OR: [
              { type: { in: LISTING_WALLET_TYPES } },
              {
                referenceType: {
                  in: LISTING_REFERENCE_TYPES,
                  mode: 'insensitive',
                },
              },
              { promotionId: { not: null } },
            ],
          },
        })
      ).count;
      await tx.walletTransaction.updateMany({
        where: { promotionId: { not: null } },
        data: { promotionId: null },
      });
      deleted.promotion = (await tx.promotion.deleteMany({})).count;

      // ── Reviews / karma tied to listings ──
      deleted.listingReviews = (
        await tx.profileReview.deleteMany({
          where: { sourceType: { in: LISTING_REVIEW_SOURCES } },
        })
      ).count;
      deleted.listingKarma = (
        await tx.karmaEvent.deleteMany({
          where: { type: { in: LISTING_KARMA_TYPES } },
        })
      ).count;
      deleted.listingNotifications = (
        await tx.notification.deleteMany({
          where: {
            sourceType: {
              in: ['trade', 'gift', 'campaign', 'donation', 'TRADE', 'GIFT', 'CAMPAIGN', 'DONATION'],
            },
          },
        })
      ).count;

      // ── Referral first-action timestamps ──
      await tx.userReferral.updateMany({
        data: {
          firstTradeAt: null,
          firstDonationAt: null,
          firstGiftAt: null,
        },
      });
    },
    { maxWait: 60_000, timeout: 300_000 },
  );

  return deleted;
}

async function main() {
  const { dryRun, confirm } = parseArgs();

  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is not set.');
    process.exit(1);
  }

  const before = await countAll();
  printCounts('Rows that will be affected', before);

  if (dryRun) {
    console.log('\nDry run only — no data deleted.');
    console.log(`To execute: npx ts-node -r dotenv/config scripts/purge-listing-data.ts --confirm ${CONFIRM_TOKEN}`);
    return;
  }

  if (confirm !== CONFIRM_TOKEN) {
    console.error(
      `\nRefusing to run without --confirm ${CONFIRM_TOKEN}`,
    );
    process.exit(1);
  }

  console.log('\n⚠️  Starting FULL listing purge in 3 seconds…');
  await new Promise((r) => setTimeout(r, 3000));

  const deleted = await purge();
  printCounts('Deleted / updated', deleted);

  const after = await countAll();
  printCounts('Remaining (should be 0 for core tables)', {
    trade: after.trade,
    gift: after.gift,
    campaign: after.campaign,
    donation: after.donation,
    tradeOffer: after.tradeOffer,
    boostPurchase: after.boostPurchase,
  });

  console.log('\n✅ Listing purge complete.');
  console.log(
    'Note: User accounts, wallet balances, chats, and media files were NOT removed.',
  );
  console.log(
    'Listing-related wallet txs were deleted; reconcile Account.balance if needed.',
  );
}

main()
  .catch((e) => {
    console.error('Purge failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
