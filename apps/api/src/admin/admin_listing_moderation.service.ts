import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  CampaignStatus,
  GiftStatus,
  ListingModerationAction,
  Prisma,
  TradeStatus,
} from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import type { ListingType } from './dto/listing-moderation.dto';

type ModerateInput = {
  listingType: ListingType;
  listingId: string;
  adminId: string;
  action: ListingModerationAction | 'DELETE';
  reason: string;
  notifyOwner?: boolean;
};

@Injectable()
export class AdminListingModerationService {
  constructor(private prisma: PrismaService) {}

  async moderate(input: ModerateInput) {
    const reason = input.reason.trim();
    if (reason.length < 3) {
      throw new BadRequestException('Reason must be at least 3 characters');
    }

    if (input.action === 'DELETE') {
      return this.deleteListing(input, reason);
    }

    switch (input.listingType) {
      case 'trade':
        return this.moderateTrade(input, reason);
      case 'gift':
        return this.moderateGift(input, reason);
      case 'campaign':
        return this.moderateCampaign(input, reason);
      default:
        throw new BadRequestException('Invalid listing type');
    }
  }

  private async writeAudit(
    adminId: string,
    targetUserId: string | null,
    action: string,
    details: Prisma.InputJsonValue,
  ) {
    await this.prisma.adminActionAudit.create({
      data: {
        adminId,
        action,
        targetUserId: targetUserId ?? undefined,
        details,
      },
    });
  }

  private moderationFields(
    adminId: string,
    action: ListingModerationAction,
    reason: string,
  ) {
    const now = new Date();
    if (action === ListingModerationAction.RESTORE) {
      return {
        adminModerationAction: null,
        adminModerationReason: null,
        adminModeratedAt: null,
        adminModeratedById: null,
      };
    }
    return {
      adminModerationAction: action,
      adminModerationReason: reason,
      adminModeratedAt: now,
      adminModeratedById: adminId,
    };
  }

  private async moderateTrade(input: ModerateInput, reason: string) {
    const trade = await this.prisma.trade.findUnique({
      where: { id: input.listingId },
      include: { owner: { include: { profile: true } } },
    });
    if (!trade) throw new NotFoundException('Trade not found');

    const previousStatus = trade.status;
    let data: Record<string, unknown> = {
      ...this.moderationFields(input.adminId, input.action as ListingModerationAction, reason),
    };

    if (input.action === ListingModerationAction.PAUSE) {
      data.status = TradeStatus.PAUSED;
    } else if (input.action === ListingModerationAction.BAN) {
      data.status = TradeStatus.BANNED;
      data.cancelledAt = new Date();
    } else if (input.action === ListingModerationAction.RESTORE) {
      data.status = TradeStatus.OPEN;
      data.cancelledAt = null;
      data.closedAt = null;
    } else {
      throw new BadRequestException('Invalid moderation action for trade');
    }

    const updated = await this.prisma.trade.update({
      where: { id: input.listingId },
      data,
      include: { owner: { include: { profile: true } }, adminModeratedBy: { include: { profile: true } } },
    });

    await this.writeAudit(input.adminId, trade.ownerId, `TRADE_${input.action}`, {
      listingType: 'trade',
      listingId: trade.id,
      listingTitle: trade.title,
      previousStatus,
      newStatus: updated.status,
      reason,
      notifyOwner: input.notifyOwner ?? false,
    });

    return updated;
  }

  private async moderateGift(input: ModerateInput, reason: string) {
    const gift = await this.prisma.gift.findUnique({
      where: { id: input.listingId },
      include: { giver: { include: { profile: true } } },
    });
    if (!gift) throw new NotFoundException('Gift not found');

    const previousStatus = gift.status;
    let data: Record<string, unknown> = {
      ...this.moderationFields(input.adminId, input.action as ListingModerationAction, reason),
    };

    if (input.action === ListingModerationAction.PAUSE) {
      data.status = GiftStatus.PAUSED;
    } else if (input.action === ListingModerationAction.BAN) {
      data.status = GiftStatus.BANNED;
    } else if (input.action === ListingModerationAction.RESTORE) {
      data.status = GiftStatus.ACTIVE;
    } else {
      throw new BadRequestException('Invalid moderation action for gift');
    }

    const updated = await this.prisma.gift.update({
      where: { id: input.listingId },
      data,
      include: { giver: { include: { profile: true } }, adminModeratedBy: { include: { profile: true } } },
    });

    await this.writeAudit(input.adminId, gift.giverId, `GIFT_${input.action}`, {
      listingType: 'gift',
      listingId: gift.id,
      listingTitle: gift.title,
      previousStatus,
      newStatus: updated.status,
      reason,
      notifyOwner: input.notifyOwner ?? false,
    });

    return updated;
  }

  private async moderateCampaign(input: ModerateInput, reason: string) {
    const campaign = await this.prisma.campaign.findUnique({
      where: { id: input.listingId },
      include: { founder: { include: { profile: true } } },
    });
    if (!campaign) throw new NotFoundException('Campaign not found');

    const previousStatus = campaign.status;
    let data: Record<string, unknown> = {
      ...this.moderationFields(input.adminId, input.action as ListingModerationAction, reason),
    };

    if (input.action === ListingModerationAction.PAUSE) {
      data.status = CampaignStatus.PAUSED;
      data.pausedAt = new Date();
    } else if (input.action === ListingModerationAction.BAN) {
      data.status = CampaignStatus.BANNED;
      data.cancelledAt = new Date();
    } else if (input.action === ListingModerationAction.RESTORE) {
      data.status = CampaignStatus.ACTIVE;
      data.launchedAt = campaign.launchedAt ?? new Date();
      data.pausedAt = null;
      data.cancelledAt = null;
    } else {
      throw new BadRequestException('Invalid moderation action for campaign');
    }

    const updated = await this.prisma.campaign.update({
      where: { id: input.listingId },
      data,
      include: { founder: { include: { profile: true } }, adminModeratedBy: { include: { profile: true } } },
    });

    await this.writeAudit(input.adminId, campaign.founderId, `CAMPAIGN_${input.action}`, {
      listingType: 'campaign',
      listingId: campaign.id,
      listingTitle: campaign.title,
      previousStatus,
      newStatus: updated.status,
      reason,
      notifyOwner: input.notifyOwner ?? false,
    });

    return updated;
  }

  private async deleteListing(input: ModerateInput, reason: string) {
    const ownerId = await this.resolveOwnerId(input.listingType, input.listingId);
    const title = await this.resolveTitle(input.listingType, input.listingId);

    await this.writeAudit(input.adminId, ownerId, `${input.listingType.toUpperCase()}_DELETE`, {
      listingType: input.listingType,
      listingId: input.listingId,
      listingTitle: title,
      reason,
      notifyOwner: input.notifyOwner ?? false,
    });

    switch (input.listingType) {
      case 'trade':
        return this.prisma.trade.delete({ where: { id: input.listingId } });
      case 'gift':
        return this.prisma.gift.delete({ where: { id: input.listingId } });
      case 'campaign':
        return this.prisma.campaign.delete({ where: { id: input.listingId } });
      default:
        throw new BadRequestException('Invalid listing type');
    }
  }

  private async resolveOwnerId(listingType: ListingType, listingId: string): Promise<string | null> {
    switch (listingType) {
      case 'trade': {
        const row = await this.prisma.trade.findUnique({ where: { id: listingId }, select: { ownerId: true } });
        return row?.ownerId ?? null;
      }
      case 'gift': {
        const row = await this.prisma.gift.findUnique({ where: { id: listingId }, select: { giverId: true } });
        return row?.giverId ?? null;
      }
      case 'campaign': {
        const row = await this.prisma.campaign.findUnique({ where: { id: listingId }, select: { founderId: true } });
        return row?.founderId ?? null;
      }
      default:
        return null;
    }
  }

  private async resolveTitle(listingType: ListingType, listingId: string): Promise<string> {
    switch (listingType) {
      case 'trade': {
        const row = await this.prisma.trade.findUnique({ where: { id: listingId }, select: { title: true } });
        return row?.title ?? listingId;
      }
      case 'gift': {
        const row = await this.prisma.gift.findUnique({ where: { id: listingId }, select: { title: true } });
        return row?.title ?? listingId;
      }
      case 'campaign': {
        const row = await this.prisma.campaign.findUnique({ where: { id: listingId }, select: { title: true } });
        return row?.title ?? listingId;
      }
      default:
        return listingId;
    }
  }
}
