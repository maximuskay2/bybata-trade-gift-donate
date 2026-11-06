import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { ChatService } from '../chat/chat.service';
import { ConversationType, NotificationPriority, NotificationType, ChatMessageType } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { KarmaService } from '../karma/karma.service';
import { KarmaPointsConfigService } from '../karma/karma-points-config.service';
import { clampGiftReward } from '../karma/karma-points-config';
import { ReferralsService } from '../referrals/referrals.service';
import { KarmaEventType } from '@prisma/client';
import {
  SourceType,
  ExpressInterestDto,
  CompleteInteractionDto,
  InteractionResponse,
} from './dto/interaction.dto';

@Injectable()
export class InteractionsService {
  constructor(
    private prisma: PrismaService,
    private chatService: ChatService,
    private notifications: NotificationsService,
    private karmaService: KarmaService,
    private referralsService: ReferralsService,
    private karmaPointsConfig: KarmaPointsConfigService,
  ) {}

  async expressInterest(
    sourceType: SourceType,
    itemId: string,
    userId: string,
    dto: ExpressInterestDto,
  ): Promise<InteractionResponse> {
    // Fetch item details and owner based on source type
    const itemDetails = await this.getItemDetails(sourceType, itemId);

    if (!itemDetails) {
      throw new NotFoundException(`${sourceType} with id ${itemId} not found`);
    }

    // Prevent self-interest
    if (itemDetails.ownerId === userId) {
      throw new BadRequestException('You cannot express interest in your own item');
    }

    // Check if conversation already exists between these users for this item
    const existingConversation = await this.findExistingConversation(
      userId,
      itemDetails.ownerId,
      sourceType,
      itemId,
    );

    let conversationId: string;

    if (existingConversation) {
      conversationId = existingConversation.id;
    } else {
      // Create new conversation
      const conversationType = this.getConversationType(sourceType);
      const conversation = await this.chatService.createConversation({
        type: conversationType,
        title: `Re: ${itemDetails.title}`,
        participantIds: [userId, itemDetails.ownerId],
        createdBy: userId,
      });

      conversationId = conversation.id;

      // Validate that sourceType matches conversation type
      this._validateModuleMatch(sourceType, conversationType);

      // Update conversation metadata with item reference
      await this.prisma.conversation.update({
        where: { id: conversationId },
        data: {
          metadata: {
            sourceType,
            itemId,
            itemTitle: itemDetails.title,
          },
        },
      });

      // Emit a first SYSTEM message carrying structured item context so both
      // parties always see the full listing details (title, description, image)
      // at the top of the thread and can tap through to the details screen.
      try {
        await this.chatService.createMessage({
          conversationId,
          senderId: userId,
          type: ChatMessageType.SYSTEM,
          content: `📌 ${sourceType}: ${itemDetails.title}`,
          metadata: {
            kind: 'item_context',
            sourceType,
            itemId,
            itemTitle: itemDetails.title,
            itemDescription: itemDetails.description ?? null,
            itemImageKey: itemDetails.imageKey ?? null,
            itemOwnerId: itemDetails.ownerId,
            itemOwnerName: itemDetails.ownerName,
          },
        });
      } catch {
        // Non-blocking: chat should still work even if the context message fails.
      }
    }

    // Send initial message if provided
    if (dto.message) {
      await this.chatService.createMessage({
        conversationId,
        senderId: userId,
        content: dto.message,
      });
    } else {
      // Send default interest message
      await this.chatService.createMessage({
        conversationId,
        senderId: userId,
        content: `I'm interested in your ${sourceType.toLowerCase()}: ${itemDetails.title}`,
      });
    }

    return {
      conversationId,
      itemId,
      itemTitle: itemDetails.title,
      itemType: sourceType,
      ownerId: itemDetails.ownerId,
      ownerName: itemDetails.ownerName,
    };
  }

  async completeInteraction(
    sourceType: SourceType,
    itemId: string,
    userId: string,
    dto: CompleteInteractionDto,
  ): Promise<{ success: boolean; message: string }> {
    // Fetch item and verify ownership or participation
    const itemDetails = await this.getItemDetails(sourceType, itemId);

    if (!itemDetails) {
      throw new NotFoundException(`${sourceType} with id ${itemId} not found`);
    }

    // Verify user is owner or authorized participant
    const isOwner = itemDetails.ownerId === userId;
    if (!isOwner) {
      throw new ForbiddenException('Only the item owner can mark it as completed');
    }

    // Update item status based on source type
    await this.updateItemStatus(sourceType, itemId);

    // Award karma for completion
    await this.awardCompletionKarma(sourceType, itemId, userId, dto);

    // Referral bonuses for first-time actions
    try {
      const counterpartId = await this.getCompletionCounterpartUserId(sourceType, itemId, userId);
      if (sourceType === SourceType.TRADE) {
        await this.referralsService.onReferredUserFirstTrade(userId);
        if (counterpartId) await this.referralsService.onReferredUserFirstTrade(counterpartId);
      } else if (sourceType === SourceType.GIFT) {
        await this.referralsService.onReferredUserFirstGift(userId);
      }
    } catch {
      // Non-blocking
    }

    // Notify counterpart on completion (trade/gift)
    try {
      const counterpartId = await this.getCompletionCounterpartUserId(
        sourceType,
        itemId,
        userId,
      );
      if (counterpartId) {
        const type =
          sourceType === SourceType.TRADE
            ? NotificationType.TRADE_COMPLETED
            : sourceType === SourceType.GIFT
              ? NotificationType.GIFT_CLAIMED
              : NotificationType.SYSTEM_ANNOUNCEMENT;
        await this.notifications.createNotification({
          userId: counterpartId,
          type,
          title: 'Interaction completed',
          message: `${itemDetails.title} was marked as completed`,
          actionUrl: `/${sourceType.toLowerCase()}s/${itemId}`,
          sourceId: itemId,
          sourceType: sourceType.toLowerCase(),
          priority: NotificationPriority.NORMAL,
          data: { itemId, sourceType },
        });
      }
    } catch {
      // Non-blocking
    }

    // If rating provided, store it
    if (dto.rating) {
      await this.storeRating(sourceType, itemId, userId, dto.rating, dto.comment);
    }

    return {
      success: true,
      message: `${sourceType} marked as completed successfully`,
    };
  }

  private async getItemDetails(
    sourceType: SourceType,
    itemId: string,
  ): Promise<{
    ownerId: string;
    ownerName: string;
    title: string;
    description?: string | null;
    imageKey?: string | null;
  } | null> {
    switch (sourceType) {
      case SourceType.TRADE:
        const trade = await this.prisma.trade.findUnique({
          where: { id: itemId },
          include: {
            owner: {
              include: { profile: true },
            },
          },
        });
        if (!trade) return null;
        return {
          ownerId: trade.ownerId,
          ownerName: trade.owner.profile?.displayName || trade.owner.email,
          title: trade.title,
          description: trade.description ?? null,
          imageKey: trade.mediaKeys?.[0] ?? null,
        };

      case SourceType.GIFT:
        const gift = await this.prisma.gift.findUnique({
          where: { id: itemId },
          include: {
            giver: {
              include: { profile: true },
            },
          },
        });
        if (!gift) return null;
        return {
          ownerId: gift.giverId,
          ownerName: gift.giver.profile?.displayName || gift.giver.email,
          title: gift.title,
          description: gift.description ?? null,
          imageKey: gift.mediaKeys?.[0] ?? null,
        };

      case SourceType.REQUEST:
        const request = await this.prisma.communityPost.findUnique({
          where: { id: itemId },
          include: {
            author: {
              include: { profile: true },
            },
          },
        });
        if (!request) return null;
        return {
          ownerId: request.authorId,
          ownerName: request.author.profile?.displayName || request.author.email,
          title: request.title || request.content.substring(0, 50),
          description: request.content ?? null,
          imageKey: request.mediaKeys?.[0] ?? null,
        };

      case SourceType.CAMPAIGN:
        const campaign = await this.prisma.campaign.findUnique({
          where: { id: itemId },
          include: {
            founder: {
              include: { profile: true },
            },
          },
        });
        if (!campaign) return null;
        return {
          ownerId: campaign.founderId,
          ownerName: campaign.founder.profile?.displayName || campaign.founder.email,
          title: campaign.title,
          description: campaign.description ?? null,
          imageKey: campaign.mediaKeys?.[0] ?? null,
        };

      default:
        return null;
    }
  }

  private async findExistingConversation(
    userId: string,
    ownerId: string,
    sourceType: SourceType,
    itemId: string,
  ) {
    return this.prisma.conversation.findFirst({
      where: {
        participants: {
          every: {
            userId: {
              in: [userId, ownerId],
            },
          },
        },
        metadata: {
          path: ['itemId'],
          equals: itemId,
        },
        isActive: true,
      },
    });
  }

  private getConversationType(sourceType: SourceType): ConversationType {
    switch (sourceType) {
      case SourceType.TRADE:
        return ConversationType.TRADE;
      case SourceType.GIFT:
        return ConversationType.DIRECT; // Gifts use DIRECT with metadata
      case SourceType.REQUEST:
        return ConversationType.GROUP; // Community requests use GROUP
      case SourceType.CAMPAIGN:
        return ConversationType.DONATION;
      default:
        return ConversationType.DIRECT;
    }
  }

  /**
   * Validates that the sourceType matches the conversation type
   * This ensures module isolation is maintained
   */
  private _validateModuleMatch(sourceType: SourceType, conversationType: ConversationType): void {
    const expectedType = this.getConversationType(sourceType);
    if (conversationType !== expectedType) {
      throw new BadRequestException(
        `Conversation type ${conversationType} does not match source type ${sourceType}. Expected ${expectedType}`
      );
    }
  }

  private async updateItemStatus(sourceType: SourceType, itemId: string) {
    switch (sourceType) {
      case SourceType.TRADE:
        await this.prisma.trade.update({
          where: { id: itemId },
          data: { status: 'CLOSED' },
        });
        break;

      case SourceType.GIFT:
        await this.prisma.gift.update({
          where: { id: itemId },
          data: { status: 'CLAIMED' },
        });
        break;

      case SourceType.REQUEST:
        await this.prisma.communityPost.update({
          where: { id: itemId },
          data: {
            status: 'HIDDEN',
            metadata: {
              ...(await this.prisma.communityPost.findUnique({ where: { id: itemId } }))?.metadata as any,
              completedAt: new Date().toISOString(),
              completedBy: 'owner',
            },
          },
        });
        break;

      case SourceType.CAMPAIGN:
        await this.prisma.campaign.update({
          where: { id: itemId },
          data: { status: 'COMPLETED' },
        });
        break;
    }
  }

  private async awardCompletionKarma(
    sourceType: SourceType,
    itemId: string,
    userId: string,
    dto: CompleteInteractionDto,
  ) {
    const config = await this.karmaPointsConfig.getConfig();
    let points = 0;
    let karmaType: KarmaEventType = KarmaEventType.MANUAL_ADJUSTMENT;
    let description = '';

    switch (sourceType) {
      case SourceType.TRADE:
        points = config.tradeComplete;
        karmaType = KarmaEventType.TRADE_COMPLETED;
        description = 'Completed a trade';
        break;
      case SourceType.GIFT:
        points = config.giftGiven;
        karmaType = KarmaEventType.GIFT_GIVEN;
        description = 'Completed a gift';
        break;
      case SourceType.REQUEST:
        points = config.helpCommunity;
        karmaType = KarmaEventType.COMMUNITY_POST;
        description = 'Fulfilled a request';
        break;
      case SourceType.CAMPAIGN:
        points = config.makeDonation;
        karmaType = KarmaEventType.DONATION_MADE;
        description = 'Completed a campaign';
        break;
      default:
        return;
    }

    if (points <= 0) return;

    await this.karmaService.awardKarma(
      userId,
      karmaType,
      points,
      description,
      {
        sourceType,
        itemId,
        rating: dto.rating,
        comment: dto.comment,
      },
      itemId,
      sourceType.toLowerCase(),
    );
  }

  private async storeRating(
    sourceType: SourceType,
    itemId: string,
    userId: string,
    rating: number,
    comment?: string,
  ) {
    try {
      const counterpartId = await this.getCompletionCounterpartUserId(
        sourceType,
        itemId,
        userId,
      );
      if (!counterpartId) return;

      // Create ProfileReview (unified reviews for profile display)
      await this.prisma.profileReview.create({
        data: {
          revieweeId: counterpartId,
          reviewerId: userId,
          rating,
          comment: comment ?? null,
          sourceType,
          sourceId: itemId,
        },
      });

      // Award karma: positive review (4-5) adds points, negative (1-2) subtracts
      const pointsConfig = await this.karmaPointsConfig.getConfig();
      const positivePoints = pointsConfig.positiveReview;
      const negativePoints = pointsConfig.negativeReview;
      if (rating >= 4) {
        await this.karmaService.awardKarma(
          counterpartId,
          KarmaEventType.RECEIVE_REVIEW,
          positivePoints,
          `Received positive review (${rating}★) from ${sourceType}`,
          { sourceType, sourceId: itemId, rating },
          itemId,
          sourceType,
        );
      } else if (rating <= 2) {
        await this.karmaService.awardKarma(
          counterpartId,
          KarmaEventType.RECEIVE_NEGATIVE_REVIEW,
          -negativePoints,
          `Received negative review (${rating}★) from ${sourceType}`,
          { sourceType, sourceId: itemId, rating },
          itemId,
          sourceType,
        );
      }

      // Notify reviewee
      const notifType =
        sourceType === SourceType.TRADE
          ? NotificationType.TRADE_COMPLETED
          : sourceType === SourceType.GIFT
            ? NotificationType.GIFT_CLAIMED
            : NotificationType.SYSTEM_ANNOUNCEMENT;
      await this.notifications.createNotification({
        userId: counterpartId,
        type: notifType,
        title: 'You received a rating',
        message: `You received a ${rating}★ rating${comment ? `: "${comment}"` : ''}`,
        actionUrl: `/${sourceType.toLowerCase()}s/${itemId}`,
        sourceId: itemId,
        sourceType: sourceType.toLowerCase(),
        priority: NotificationPriority.NORMAL,
        data: { itemId, sourceType, rating, comment },
      });
    } catch {
      // Non-blocking
    }
  }

  private async getCompletionCounterpartUserId(
    sourceType: SourceType,
    itemId: string,
    userId: string,
  ): Promise<string | null> {
    switch (sourceType) {
      case SourceType.TRADE: {
        const trade = await this.prisma.trade.findUnique({
          where: { id: itemId },
          include: { acceptedOffer: { select: { bidderId: true } } },
        });
        const counterpart = trade?.acceptedOffer?.bidderId;
        return counterpart && counterpart !== userId ? counterpart : null;
      }
      case SourceType.GIFT: {
        const claim = await this.prisma.giftClaim.findFirst({
          where: { giftId: itemId },
          orderBy: { claimedAt: 'desc' },
          select: { claimerId: true },
        });
        const counterpart = claim?.claimerId;
        return counterpart && counterpart !== userId ? counterpart : null;
      }
      default:
        return null;
    }
  }
}
