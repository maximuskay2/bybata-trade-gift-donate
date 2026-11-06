import { Test, TestingModule } from '@nestjs/testing';
import { CommunitiesService } from './communities.service';
import { PrismaService } from '../common/prisma.service';
import { CommunityRole, CommunityType, MemberStatus, CommunityStatus } from '@prisma/client';
import { NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';

describe('CommunitiesService', () => {
  let service: CommunitiesService;
  let prisma: PrismaService;

  const mockPrisma = {
    community: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    communityMember: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    communityPost: {
      create: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    communityEvent: {
      create: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CommunitiesService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    service = module.get<CommunitiesService>(CommunitiesService);
    prisma = module.get<PrismaService>(PrismaService);

    jest.clearAllMocks();
  });

  describe('createCommunity', () => {
    it('should create community with owner as member', async () => {
      const userId = 'user1';
      const dto = {
        name: 'Test Community',
        description: 'Test description',
        type: CommunityType.PUBLIC,
        center_latitude: 0,
        center_longitude: 0,
      };

      mockPrisma.community.create.mockResolvedValue({
        id: 'comm1',
        createdById: userId,
        ...dto,
        members: [{
          userId,
          role: CommunityRole.OWNER,
          status: MemberStatus.ACTIVE,
        }],
      });

      const result = await service.createCommunity(userId, dto);

      expect(result).toBeDefined();
      expect(mockPrisma.community.create).toHaveBeenCalled();
    });
  });

  describe('joinCommunity', () => {
    it('should join community within 20km radius', async () => {
      const userId = 'user1';
      const communityId = 'comm1';
      const dto = {
        lat: 0.001, // ~111m from center
        lng: 0.001,
      };

      mockPrisma.community.findUnique.mockResolvedValue({
        id: communityId,
        type: CommunityType.PUBLIC,
        center_latitude: 0,
        center_longitude: 0,
      });

      mockPrisma.communityMember.findUnique.mockResolvedValue(null);
      mockPrisma.communityMember.upsert.mockResolvedValue({
        id: 'member1',
        communityId,
        userId,
        role: CommunityRole.MEMBER,
        status: MemberStatus.ACTIVE,
      });

      mockPrisma.community.update.mockResolvedValue({});

      const result = await service.joinCommunity(communityId, userId, dto);

      expect(result).toBeDefined();
    });

    it('should reject join if outside 20km radius', async () => {
      const userId = 'user1';
      const communityId = 'comm1';
      const dto = {
        lat: 0.5, // ~55km from center (0,0)
        lng: 0.5,
      };

      mockPrisma.community.findUnique.mockResolvedValue({
        id: communityId,
        type: CommunityType.PUBLIC,
        center_latitude: 0,
        center_longitude: 0,
      });

      await expect(
        service.joinCommunity(communityId, userId, dto),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should require invite code for private community', async () => {
      const userId = 'user1';
      const communityId = 'comm1';

      mockPrisma.community.findUnique.mockResolvedValue({
        id: communityId,
        type: CommunityType.PRIVATE,
      });

      await expect(
        service.joinCommunity(communityId, userId),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('createPost', () => {
    it('should create post in community', async () => {
      const userId = 'user1';
      const communityId = 'comm1';
      const dto = {
        content: 'Test post',
        type: 'TEXT' as any,
      };

      mockPrisma.community.findUnique.mockResolvedValue({
        id: communityId,
        status: CommunityStatus.ACTIVE,
      });

      mockPrisma.communityMember.findUnique.mockResolvedValue({
        userId,
        status: MemberStatus.ACTIVE,
      });

      mockPrisma.communityPost.create.mockResolvedValue({
        id: 'post1',
        communityId,
        authorId: userId,
        ...dto,
      });

      const result = await service.createPost(communityId, userId, dto);

      expect(result).toBeDefined();
      expect(mockPrisma.communityPost.create).toHaveBeenCalled();
    });

    it('should reject post from non-member', async () => {
      const userId = 'user1';
      const communityId = 'comm1';

      mockPrisma.community.findUnique.mockResolvedValue({
        id: communityId,
        status: CommunityStatus.ACTIVE,
      });

      mockPrisma.communityMember.findUnique.mockResolvedValue(null);

      await expect(
        service.createPost(communityId, userId, { content: 'Test' }),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});

