import { Test, TestingModule } from '@nestjs/testing';
import { CampaignsService } from './campaigns.service';
import { PrismaService } from '../common/prisma.service';
import { WalletService } from '../wallet/wallet.service';
import { ChatGateway } from '../chat/chat.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { CampaignStatus, TxStatus } from '@prisma/client';
import { BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';

describe('CampaignsService', () => {
  let service: CampaignsService;
  let prisma: PrismaService;
  let wallet: WalletService;
  let notifications: NotificationsService;

  const mockPrisma = {
    campaign: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    donation: {
      create: jest.fn(),
      findMany: jest.fn(),
      aggregate: jest.fn(),
      count: jest.fn(),
    },
    campaignUpdate: {
      create: jest.fn(),
      findMany: jest.fn(),
    },
    rewardTier: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    donationReward: {
      create: jest.fn(),
      deleteMany: jest.fn(),
    },
    $transaction: jest.fn(),
  };

  const mockWallet = {
    processDonation: jest.fn(),
  };

  const mockNotifications = {
    createNotification: jest.fn(),
  };

  const mockChatGateway = {
    server: {
      emit: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CampaignsService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
        {
          provide: WalletService,
          useValue: mockWallet,
        },
        {
          provide: ChatGateway,
          useValue: mockChatGateway,
        },
        {
          provide: NotificationsService,
          useValue: mockNotifications,
        },
      ],
    }).compile();

    service = module.get<CampaignsService>(CampaignsService);
    prisma = module.get<PrismaService>(PrismaService);
    wallet = module.get<WalletService>(WalletService);
    notifications = module.get<NotificationsService>(NotificationsService);

    jest.clearAllMocks();
  });

  describe('createCampaign', () => {
    it('should create a campaign successfully', async () => {
      const founderId = 'user1';
      const campaignData = {
        title: 'Test Campaign',
        goalAmount: 1000,
        currency: 'BYC',
      };

      mockPrisma.campaign.create.mockResolvedValue({
        id: 'camp1',
        ...campaignData,
        founderId,
        status: CampaignStatus.DRAFT,
      });

      const result = await service.createCampaign(founderId, campaignData);

      expect(result).toBeDefined();
      expect(mockPrisma.campaign.create).toHaveBeenCalled();
    });

    it('should reject campaign with invalid goal amount', async () => {
      const founderId = 'user1';
      const campaignData = {
        title: 'Test Campaign',
        goalAmount: -100,
      };

      await expect(
        service.createCampaign(founderId, campaignData),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('donate', () => {
    it('should process donation successfully', async () => {
      const donorId = 'donor1';
      const campaignId = 'camp1';
      const donationData = {
        amount: 100,
        currency: 'BYC',
        isAnonymous: false,
      };

      const mockCampaign = {
        id: campaignId,
        founderId: 'founder1',
        title: 'Test Campaign',
        status: CampaignStatus.ACTIVE,
        goalAmount: { toNumber: () => 1000 },
        currentAmount: { add: jest.fn().mockReturnValue({ toNumber: () => 100, gte: jest.fn().mockReturnValue(false) }) },
        donorCount: 0,
        minimumDonation: null,
      };

      mockPrisma.campaign.findUnique.mockResolvedValue(mockCampaign);
      mockWallet.processDonation.mockResolvedValue({
        debitTransactionId: 'tx1',
        creditTransactionId: 'tx2',
      });

      mockPrisma.$transaction.mockImplementation(async (callback) => {
        const mockTx = {
          donation: {
            create: jest.fn().mockResolvedValue({
              id: 'don1',
              ...donationData,
              campaign: mockCampaign,
              donor: { id: donorId, profile: { displayName: 'Donor' } },
            }),
          },
          rewardTier: {
            findUnique: jest.fn(),
            update: jest.fn(),
          },
          donationReward: {
            create: jest.fn(),
          },
          campaign: {
            update: jest.fn().mockResolvedValue({
              ...mockCampaign,
              currentAmount: { toNumber: () => 100 },
              donorCount: 1,
            }),
          },
        };
        return callback(mockTx);
      });

      const result = await service.donate(donorId, campaignId, donationData);

      expect(result).toBeDefined();
      expect(mockWallet.processDonation).toHaveBeenCalled();
    });

    it('should reject donation to inactive campaign', async () => {
      const donorId = 'donor1';
      const campaignId = 'camp1';
      const donationData = { amount: 100 };

      mockPrisma.campaign.findUnique.mockResolvedValue({
        id: campaignId,
        status: CampaignStatus.COMPLETED,
      });

      await expect(
        service.donate(donorId, campaignId, donationData),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject donation below minimum', async () => {
      const donorId = 'donor1';
      const campaignId = 'camp1';
      const donationData = { amount: 5 };

      mockPrisma.campaign.findUnique.mockResolvedValue({
        id: campaignId,
        status: CampaignStatus.ACTIVE,
        minimumDonation: { toNumber: () => 10 },
      });

      await expect(
        service.donate(donorId, campaignId, donationData),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('listCampaigns', () => {
    it('should list campaigns with pagination', async () => {
      const params = { page: 1, size: 20 };
      const mockCampaigns = [
        { id: 'camp1', title: 'Campaign 1', status: CampaignStatus.ACTIVE },
        { id: 'camp2', title: 'Campaign 2', status: CampaignStatus.ACTIVE },
      ];

      mockPrisma.campaign.findMany.mockResolvedValue(mockCampaigns);
      mockPrisma.campaign.count.mockResolvedValue(2);

      const result = await service.listCampaigns(params);

      expect(result.items).toHaveLength(2);
      expect(result.total).toBe(2);
      expect(result.page).toBe(1);
    });
  });

  describe('createUpdate', () => {
    it('should create campaign update', async () => {
      const authorId = 'founder1';
      const campaignId = 'camp1';
      const updateData = {
        type: 'TEXT',
        content: 'Test update',
      };

      mockPrisma.campaign.findUnique.mockResolvedValue({
        id: campaignId,
        founderId: authorId,
      });

      mockPrisma.campaignUpdate.create.mockResolvedValue({
        id: 'update1',
        campaignId,
        authorId,
        ...updateData,
      });

      const result = await service.createUpdate(authorId, campaignId, updateData);

      expect(result).toBeDefined();
      expect(mockPrisma.campaignUpdate.create).toHaveBeenCalled();
    });

    it('should reject update from non-founder', async () => {
      const authorId = 'user1';
      const campaignId = 'camp1';

      mockPrisma.campaign.findUnique.mockResolvedValue({
        id: campaignId,
        founderId: 'founder1',
      });

      await expect(
        service.createUpdate(authorId, campaignId, { content: 'Test' }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('createRewardTier', () => {
    it('should create reward tier', async () => {
      const userId = 'founder1';
      const campaignId = 'camp1';
      const tierData = {
        title: 'Basic Tier',
        description: 'Basic reward',
        minimumDonation: 50,
      };

      mockPrisma.campaign.findUnique.mockResolvedValue({
        id: campaignId,
        founderId: userId,
      });

      mockPrisma.rewardTier.create.mockResolvedValue({
        id: 'tier1',
        campaignId,
        ...tierData,
      });

      const result = await service.createRewardTier(userId, campaignId, tierData);

      expect(result).toBeDefined();
      expect(mockPrisma.rewardTier.create).toHaveBeenCalled();
    });
  });
});

