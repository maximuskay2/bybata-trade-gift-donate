import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { 
  CommunityRole, 
  CommunityType, 
  MemberStatus, 
  PostStatus, 
  EventStatus,
  AttendeeStatus,
  CommunityStatus,
  PostType,
  NotificationType,
  NotificationPriority,
  CommunityInviteStatus
} from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { 
  CreateCommunityDto, 
  UpdateCommunityDto, 
  CreatePostDto, 
  UpdatePostDto,
  CreateEventDto,
  UpdateEventDto,
  JoinCommunityDto,
  UpdateMemberRoleDto,
  CreateCommentDto
} from './dto/community.dto';
import { CreateRequestDto } from './dto/create-request.dto';

@Injectable()
export class CommunitiesService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
  ) {}

  // Community CRUD
  async createCommunity(userId: string, dto: CreateCommunityDto) {
    // Create community with creator automatically enrolled as OWNER member
    const community = await this.prisma.community.create({
      data: {
        ...dto,
        createdById: userId,
        memberCount: 1, // Creator is automatically a member
        members: {
          create: {
            userId,
            role: CommunityRole.OWNER,
            status: MemberStatus.ACTIVE,
          }
        }
      },
      include: {
        createdBy: {
          include: { profile: true }
        },
        members: {
          include: {
            user: {
              include: { profile: true }
            }
          }
        },
        _count: {
          select: {
            members: true,
            posts: true,
            events: true
          }
        }
      }
    });

    return community;
  }

  async getCommunities(page = 1, size = 20, category?: string, type?: CommunityType, search?: string) {
    const skip = (page - 1) * size;
    const where: any = {
      status: CommunityStatus.ACTIVE
    };

    if (category) {
      where.category = category;
    }

    if (type) {
      where.type = type;
    }

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { tags: { hasSome: [search] } }
      ];
    }

    const [communities, total] = await Promise.all([
      this.prisma.community.findMany({
        where,
        include: {
          createdBy: {
            include: { profile: true }
          },
          _count: {
            select: {
              members: true,
              posts: true,
              events: true
            }
          }
        },
        skip,
        take: size,
        orderBy: [
          { isFeatured: 'desc' },
          { memberCount: 'desc' },
          { createdAt: 'desc' }
        ]
      }),
      this.prisma.community.count({ where })
    ]);

    return {
      items: communities,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size)
    };
  }

  async getNearbyCommunities(userLat: number, userLng: number, radiusMeters = 20000, page = 1, size = 20) {
    const skip = (page - 1) * size;
    
    // Fetch all active communities with full data
    // NOTE: All communities are now searchable/visible regardless of distance
    // The 20km radius restriction is only enforced during JOIN, not discovery
    const [communities, total] = await Promise.all([
      this.prisma.community.findMany({
        where: { 
          status: CommunityStatus.ACTIVE,
          // Only include communities that have geo coordinates
          center_latitude: { not: null },
          center_longitude: { not: null }
        },
        include: {
          createdBy: {
            include: {
              profile: true
            }
          },
          _count: {
            select: {
              members: true,
              posts: true,
              events: true
            }
          }
        },
        skip,
        take: size,
        orderBy: [{ createdAt: 'desc' }],
      }),
      this.prisma.community.count({
        where: {
          status: CommunityStatus.ACTIVE,
          center_latitude: { not: null },
          center_longitude: { not: null }
        }
      })
    ]);
    
    // Calculate distances for display purposes (no filtering)
    const withDistance = communities.map((c) => {
      const d = haversineMeters(userLat, userLng, c.center_latitude ?? 0, c.center_longitude ?? 0);
      return { ...c, distanceMeters: d };
    });
    
    // Return all communities sorted by distance (nearest first)
    const sorted = withDistance.sort((a, b) => a.distanceMeters - b.distanceMeters);
    
    return {
      items: sorted,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size),
    };
  }

  async getJoinedCommunities(userId: string, page = 1, size = 20) {
    const skip = (page - 1) * size;
    const [memberships, total] = await Promise.all([
      this.prisma.communityMember.findMany({
        where: {
          userId,
          status: MemberStatus.ACTIVE,
        },
        include: {
          community: {
            include: {
              createdBy: { include: { profile: true } },
              _count: { select: { members: true, posts: true, events: true } },
            },
          },
        },
        skip,
        take: size,
        orderBy: [{ joinedAt: 'desc' }],
      }),
      this.prisma.communityMember.count({ where: { userId, status: MemberStatus.ACTIVE } }),
    ]);

    const communities = memberships.map((m) => m.community).filter(Boolean);
    return {
      items: communities,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size),
    };
  }

  async getCommunity(id: string, userId?: string) {
    const community = await this.prisma.community.findUnique({
      where: { id },
      include: {
        createdBy: {
          include: { profile: true }
        },
        members: {
          where: { status: MemberStatus.ACTIVE },
          include: {
            user: {
              include: { profile: true }
            }
          },
          orderBy: [
            { role: 'asc' },
            { joinedAt: 'asc' }
          ]
        },
        _count: {
          select: {
            members: true,
            posts: true,
            events: true
          }
        }
      }
    });

    if (!community) {
      throw new NotFoundException('Community not found');
    }

    // Check if user can access private community
    if (community.type !== CommunityType.PUBLIC && userId) {
      const membership = await this.prisma.communityMember.findUnique({
        where: {
          communityId_userId: {
            communityId: id,
            userId
          }
        }
      });

      if (!membership || membership.status !== MemberStatus.ACTIVE) {
        throw new ForbiddenException('Access denied to private community');
      }
    }

    return community;
  }

  async updateCommunity(id: string, userId: string, dto: UpdateCommunityDto) {
    await this.checkCommunityPermission(id, userId, [CommunityRole.OWNER, CommunityRole.ADMIN]);

    return this.prisma.community.update({
      where: { id },
      data: dto,
      include: {
        createdBy: {
          include: { profile: true }
        },
        _count: {
          select: {
            members: true,
            posts: true,
            events: true
          }
        }
      }
    });
  }

  async deleteCommunity(id: string, userId: string) {
    await this.checkCommunityPermission(id, userId, [CommunityRole.OWNER]);

    return this.prisma.community.update({
      where: { id },
      data: { status: CommunityStatus.ARCHIVED }
    });
  }

  // Member Management
  async joinCommunity(communityId: string, userId: string, dto?: JoinCommunityDto) {
    const community = await this.prisma.community.findUnique({
      where: { id: communityId }
    });

    if (!community) {
      throw new NotFoundException('Community not found');
    }

    // Geofence enforcement: require lat/lng and ensure within configured distance
    if (typeof (dto as any)?.lat === 'number' && typeof (dto as any)?.lng === 'number') {
      const maxDistanceMeters = await this.getCommunityJoinDistance();
      const dist = haversineMeters((dto as any).lat, (dto as any).lng, community.center_latitude ?? 0, community.center_longitude ?? 0);
      if (dist > maxDistanceMeters) {
        const distanceKm = Math.round(maxDistanceMeters / 1000);
        throw new ForbiddenException(`You must be within ${distanceKm}km of this community's area to join.`);
      }
    }

    // Check if already a member
    const existingMembership = await this.prisma.communityMember.findUnique({
      where: {
        communityId_userId: {
          communityId,
          userId
        }
      },
      include: {
        user: {
          include: { profile: true }
        },
        community: true
      }
    });

    let matchedInvite = null as any;
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true },
    });

    if (community.type === CommunityType.PRIVATE) {
      const now = new Date();
      if (dto?.inviteCode) {
        matchedInvite = await this.prisma.communityInvite.findFirst({
          where: {
            communityId,
            inviteCode: dto.inviteCode,
            status: CommunityInviteStatus.PENDING,
          },
        });
        if (!matchedInvite) {
          throw new ForbiddenException('Invite code required for private community');
        }
        if (matchedInvite.expiresAt && matchedInvite.expiresAt < now) {
          await this.prisma.communityInvite.update({
            where: { id: matchedInvite.id },
            data: { status: CommunityInviteStatus.EXPIRED },
          });
          throw new ForbiddenException('Invite code required for private community');
        }
        if (
          matchedInvite.inviteeUserId &&
          matchedInvite.inviteeUserId !== userId
        ) {
          throw new ForbiddenException('Invite code required for private community');
        }
        if (
          matchedInvite.inviteeEmail &&
          user?.email &&
          matchedInvite.inviteeEmail.toLowerCase() !== user.email.toLowerCase()
        ) {
          throw new ForbiddenException('Invite code required for private community');
        }
      } else {
        matchedInvite = await this.prisma.communityInvite.findFirst({
          where: {
            communityId,
            status: CommunityInviteStatus.PENDING,
            AND: [
              {
                OR: [
                  { inviteeUserId: userId },
                  ...(user?.email
                    ? [{ inviteeEmail: user.email.toLowerCase() }]
                    : []),
                ],
              },
              {
                OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
              },
            ],
          },
        });
        if (!matchedInvite) {
          throw new ForbiddenException('Invite code required for private community');
        }
      }
    }

    // If already an active member, return the existing membership (idempotent)
    if (existingMembership && existingMembership.status === MemberStatus.ACTIVE) {
      return existingMembership;
    }

    // Check if user is the creator (owner) - they should already be a member
    if (community.createdById === userId) {
      // Ensure owner membership exists
      if (!existingMembership) {
        const ownerMember = await this.prisma.communityMember.create({
          data: {
            communityId,
            userId,
            role: CommunityRole.OWNER,
            status: MemberStatus.ACTIVE
          },
          include: {
            user: {
              include: { profile: true }
            },
            community: true
          }
        });
        // Update member count only if it wasn't already set
        await this.prisma.community.update({
          where: { id: communityId },
          data: {
            memberCount: {
              increment: 1
            }
          }
        });
        return ownerMember;
      }
      // If owner membership exists but inactive, reactivate it
      if (existingMembership.status !== MemberStatus.ACTIVE) {
        return await this.prisma.communityMember.update({
          where: {
            communityId_userId: {
              communityId,
              userId
            }
          },
          data: {
            status: MemberStatus.ACTIVE,
            leftAt: null,
            bannedAt: null,
            banReason: null
          },
          include: {
            user: {
              include: { profile: true }
            },
            community: true
          }
        });
      }
      return existingMembership;
    }

    const requiresApproval = Boolean(community.requiresApproval);
    const shouldApproveImmediately = Boolean(matchedInvite);
    const targetStatus = requiresApproval && !shouldApproveImmediately
      ? MemberStatus.PENDING
      : MemberStatus.ACTIVE;

    // Create or reactivate membership for regular members
    const wasNewMember = !existingMembership;
    const existing = await this.prisma.communityMember.findUnique({
      where: { communityId_userId: { communityId, userId } },
    });
    if (existing && existing.status === MemberStatus.ACTIVE) {
      return existing;
    }
    if (existing && existing.status === MemberStatus.PENDING) {
      return existing;
    }

    const member = await this.prisma.communityMember.upsert({
      where: {
        communityId_userId: {
          communityId,
          userId
        }
      },
      create: {
        communityId,
        userId,
        role: CommunityRole.MEMBER,
        status: targetStatus,
        joinedAt: targetStatus === MemberStatus.ACTIVE ? new Date() : undefined,
      },
      update: {
        status: targetStatus,
        leftAt: null,
        bannedAt: null,
        banReason: null,
        joinedAt: targetStatus === MemberStatus.ACTIVE ? new Date() : undefined,
      },
      include: {
        user: {
          include: { profile: true }
        },
        community: true
      }
    });

    // Update member count only if this is a new active membership
    if (wasNewMember && targetStatus === MemberStatus.ACTIVE) {
      await this.prisma.community.update({
        where: { id: communityId },
        data: {
          memberCount: {
            increment: 1
          }
        }
      });
    }

    if (wasNewMember || existingMembership?.status !== MemberStatus.ACTIVE) {
      try {
        await this.notifications.createNotification({
          userId: community.createdById,
          type: NotificationType.SYSTEM_ANNOUNCEMENT,
          title: 'New community member',
          message: `${member.user?.profile?.displayName || 'Someone'} joined ${community.name}`,
          actionUrl: `/communities/${communityId}`,
          sourceId: communityId,
          sourceType: 'community',
          priority: NotificationPriority.NORMAL,
          data: { communityId, memberId: member.id },
        });
        if (member.invitedBy) {
          await this.notifications.createNotification({
            userId: member.invitedBy,
            type: NotificationType.SYSTEM_ANNOUNCEMENT,
            title: 'Invite accepted',
            message: `${member.user?.profile?.displayName || 'Someone'} accepted your invite to ${community.name}`,
            actionUrl: `/communities/${communityId}`,
            sourceId: communityId,
            sourceType: 'community',
            priority: NotificationPriority.NORMAL,
            data: { communityId, memberId: member.id },
          });
        }
      } catch {
        // Non-blocking
      }
    }

    if (matchedInvite && matchedInvite.status === CommunityInviteStatus.PENDING) {
      try {
        await this.prisma.communityInvite.update({
          where: { id: matchedInvite.id },
          data: { status: CommunityInviteStatus.ACCEPTED, acceptedAt: new Date() },
        });
      } catch {
        // Non-blocking
      }
    }

    return member;
  }

  async listPendingJoinRequests(communityId: string, userId: string, page = 1, size = 20) {
    await this.checkCommunityPermission(communityId, userId, [
      CommunityRole.OWNER,
      CommunityRole.ADMIN,
      CommunityRole.MODERATOR,
    ]);
    const skip = (page - 1) * size;
    const where = { communityId, status: MemberStatus.PENDING } as any;
    const [total, items] = await this.prisma.$transaction([
      this.prisma.communityMember.count({ where }),
      this.prisma.communityMember.findMany({
        where,
        include: {
          user: { include: { profile: true } },
          community: true,
        },
        orderBy: { joinedAt: 'desc' },
        skip,
        take: size,
      }),
    ]);
    return { items, page, size, total };
  }

  async approveJoinRequest(communityId: string, memberId: string, moderatorId: string) {
    await this.checkCommunityPermission(communityId, moderatorId, [
      CommunityRole.OWNER,
      CommunityRole.ADMIN,
      CommunityRole.MODERATOR,
    ]);
    const member = await this.prisma.communityMember.findUnique({
      where: { id: memberId },
      include: { user: { include: { profile: true } }, community: true },
    });
    if (!member || member.communityId !== communityId) throw new NotFoundException('Member not found');
    if (member.status !== MemberStatus.PENDING) {
      return member;
    }
    const updated = await this.prisma.communityMember.update({
      where: { id: memberId },
      data: { status: MemberStatus.ACTIVE, joinedAt: new Date(), leftAt: null },
      include: { user: { include: { profile: true } }, community: true },
    });
    await this.prisma.community.update({
      where: { id: communityId },
      data: { memberCount: { increment: 1 } },
    });
    if (updated.user?.email) {
      this.email.dispatchInBackground({
        eventName: EmailEventName.CommunityJoinRequestApproved,
        recipient: { email: updated.user.email, userId: updated.userId },
        vars: {
          targetName: updated.user.profile?.displayName || updated.user.email,
          communityName: updated.community.name,
          communityUrl: this.emailLinkRouter.getCommunityLink(communityId),
        },
      });
    }
    return updated;
  }

  async rejectJoinRequest(communityId: string, memberId: string, moderatorId: string, reason?: string) {
    await this.checkCommunityPermission(communityId, moderatorId, [
      CommunityRole.OWNER,
      CommunityRole.ADMIN,
      CommunityRole.MODERATOR,
    ]);
    const member = await this.prisma.communityMember.findUnique({
      where: { id: memberId },
      include: { user: { include: { profile: true } }, community: true },
    });
    if (!member || member.communityId !== communityId) throw new NotFoundException('Member not found');
    const updated = await this.prisma.communityMember.update({
      where: { id: memberId },
      data: { status: MemberStatus.REJECTED, leftAt: new Date(), banReason: reason },
      include: { user: { include: { profile: true } }, community: true },
    });
    if (updated.user?.email) {
      this.email.dispatchInBackground({
        eventName: EmailEventName.CommunityJoinRequestRejected,
        recipient: { email: updated.user.email, userId: updated.userId },
        vars: {
          targetName: updated.user.profile?.displayName || updated.user.email,
          communityName: updated.community.name,
          reason: reason || 'Request rejected',
        },
      });
    }
    return updated;
  }

  async inviteMember(
    communityId: string,
    inviterId: string,
    inviteeId?: string,
    inviteeIds?: string[],
    email?: string,
    emails?: string[],
    username?: string,
    usernames?: string[],
    message?: string,
    expiresAt?: string,
    templateKey?: string,
  ) {
    const ids = new Set<string>();
    if (inviteeId) ids.add(inviteeId);
    (inviteeIds || []).forEach((id) => ids.add(id));

    const emailList = new Set<string>();
    if (email) emailList.add(email);
    (emails || []).forEach((e) => emailList.add(e));

    const usernameList = new Set<string>();
    if (username) usernameList.add(username);
    (usernames || []).forEach((u) => usernameList.add(u));

    if (ids.size === 0 && emailList.size === 0 && usernameList.size === 0) {
      throw new BadRequestException('No invite recipients provided');
    }

    if (ids.has(inviterId)) {
      throw new BadRequestException('Cannot invite yourself');
    }

    const community = await this.prisma.community.findUnique({
      where: { id: communityId },
    });
    if (!community) throw new NotFoundException('Community not found');

    await this.checkCommunityPermission(communityId, inviterId, [
      CommunityRole.OWNER,
      CommunityRole.ADMIN,
      CommunityRole.MODERATOR,
    ]);

    const results: any[] = [];
    const skipped: string[] = [];

    if (usernameList.size > 0) {
      for (const rawName of usernameList) {
        const uname = rawName.trim().replace(/^@/, '');
        if (!uname) continue;

        const usernameMatches = await this.prisma.user.findMany({
          where: { profile: { username: { contains: uname, mode: 'insensitive' } } },
          select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
        });

        let candidates = usernameMatches;
        let exactMatches = candidates.filter(
          (u) => (u.profile?.username ?? '').toLowerCase() === uname.toLowerCase(),
        );

        if (candidates.length === 0) {
          candidates = await this.prisma.user.findMany({
            where: { profile: { displayName: { contains: uname, mode: 'insensitive' } } },
            select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
          });
          exactMatches = candidates.filter(
            (u) => (u.profile?.displayName ?? '').toLowerCase() === uname.toLowerCase(),
          );
        }

        if (exactMatches.length === 1) {
          ids.add(exactMatches[0].id);
        } else if (candidates.length === 1) {
          ids.add(candidates[0].id);
        } else if (candidates.length > 1) {
          skipped.push(`username:${rawName}:ambiguous`);
        } else {
          skipped.push(`username:${rawName}:not_found`);
        }
      }
    }

    const usersByEmail = new Map<string, { id: string; email: string }>();
    if (emailList.size > 0) {
      const users = await this.prisma.user.findMany({
        where: { email: { in: Array.from(emailList).map((e) => e.toLowerCase()) } },
        select: { id: true, email: true },
      });
      users.forEach((u) => usersByEmail.set(u.email.toLowerCase(), u));
      users.forEach((u) => ids.add(u.id));
    }

    const inviter = await this.prisma.user.findUnique({
      where: { id: inviterId },
      select: { profile: { select: { displayName: true } }, email: true },
    });
    const inviterName = inviter?.profile?.displayName || inviter?.email || 'Someone';

    for (const userId of ids) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true },
      });
      if (!user) {
        skipped.push(userId);
        continue;
      }

      const invite = await this.createOrUpdateInvite(
        communityId,
        inviterId,
        { userId, email: user.email },
        message,
        expiresAt,
      );
      await this.sendInviteNotificationAndEmail(invite, community, inviterName, templateKey);
      results.push({ ...invite, inviteLink: this.buildInviteLink(invite.inviteCode) });
    }

    for (const emailAddress of emailList) {
      const normalized = emailAddress.toLowerCase();
      if (usersByEmail.has(normalized)) continue;
      const invite = await this.createOrUpdateInvite(
        communityId,
        inviterId,
        { email: normalized },
        message,
        expiresAt,
      );
      await this.sendInviteNotificationAndEmail(invite, community, inviterName, templateKey);
      results.push({ ...invite, inviteLink: this.buildInviteLink(invite.inviteCode) });
    }

    return { items: results, skipped };
  }

  async getMyInvites(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true },
    });
    const items = await this.prisma.communityInvite.findMany({
      where: {
        status: CommunityInviteStatus.PENDING,
        OR: [
          { inviteeUserId: userId },
          ...(user?.email ? [{ inviteeEmail: user.email.toLowerCase() }] : []),
        ],
      },
      include: {
        community: true,
        inviter: { include: { profile: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return { items: items.map((i) => ({ ...i, inviteLink: this.buildInviteLink(i.inviteCode) })) };
  }

  async getCommunityInvites(communityId: string, userId: string) {
    await this.checkCommunityPermission(communityId, userId, [
      CommunityRole.OWNER,
      CommunityRole.ADMIN,
      CommunityRole.MODERATOR,
    ]);
    const items = await this.prisma.communityInvite.findMany({
      where: { communityId, status: CommunityInviteStatus.PENDING },
      include: {
        invitee: { include: { profile: true } },
        inviter: { include: { profile: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return { items: items.map((i) => ({ ...i, inviteLink: this.buildInviteLink(i.inviteCode) })) };
  }

  async lookupInvite(code: string) {
    const invite = await this.prisma.communityInvite.findUnique({
      where: { inviteCode: code },
      include: {
        community: true,
        inviter: { include: { profile: true } },
      },
    });
    if (!invite) throw new NotFoundException('Invite not found');
    if (invite.status !== CommunityInviteStatus.PENDING) {
      throw new BadRequestException('Invite is no longer active');
    }
    if (invite.expiresAt && invite.expiresAt < new Date()) {
      await this.prisma.communityInvite.update({
        where: { id: invite.id },
        data: { status: CommunityInviteStatus.EXPIRED },
      });
      throw new BadRequestException('Invite expired');
    }
    return {
      invite,
      link: this.buildInviteLink(invite.inviteCode),
      community: invite.community,
      inviter: invite.inviter,
    };
  }

  async acceptInvite(communityId: string, userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true },
    });
    const invite = await this.prisma.communityInvite.findFirst({
      where: {
        communityId,
        status: CommunityInviteStatus.PENDING,
        OR: [
          { inviteeUserId: userId },
          ...(user?.email ? [{ inviteeEmail: user.email.toLowerCase() }] : []),
        ],
      },
      include: { community: true },
    });
    if (!invite) throw new NotFoundException('Invite not found');
    return this.acceptInviteRecord(invite, userId);
  }

  async acceptInviteByCode(code: string, userId: string) {
    const invite = await this.prisma.communityInvite.findUnique({
      where: { inviteCode: code },
      include: { community: true },
    });
    if (!invite) throw new NotFoundException('Invite not found');
    return this.acceptInviteRecord(invite, userId);
  }

  async declineInvite(communityId: string, userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true },
    });
    const invite = await this.prisma.communityInvite.findFirst({
      where: {
        communityId,
        status: CommunityInviteStatus.PENDING,
        OR: [
          { inviteeUserId: userId },
          ...(user?.email ? [{ inviteeEmail: user.email.toLowerCase() }] : []),
        ],
      },
    });
    if (!invite) throw new NotFoundException('Invite not found');
    const updated = await this.prisma.communityInvite.update({
      where: { id: invite.id },
      data: { status: CommunityInviteStatus.DECLINED },
    });
    try {
      const inviter = await this.prisma.user.findUnique({
        where: { id: invite.inviterId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      const community = await this.prisma.community.findUnique({
        where: { id: invite.communityId },
        select: { name: true },
      });
      if (inviter?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.CommunityInviteDeclined,
          recipient: { email: inviter.email, userId: invite.inviterId },
          vars: {
            actorName: user?.email || 'Someone',
            targetName: inviter.email,
            communityName: community?.name || invite.communityId,
          },
        });
      }
    } catch {
      // Non-blocking
    }
    return updated;
  }

  async revokeInvite(
    communityId: string,
    inviterId: string,
    inviteeId?: string,
    inviteId?: string,
    email?: string,
  ) {
    await this.checkCommunityPermission(communityId, inviterId, [
      CommunityRole.OWNER,
      CommunityRole.ADMIN,
      CommunityRole.MODERATOR,
    ]);
    const invite = inviteId
      ? await this.prisma.communityInvite.findUnique({ where: { id: inviteId } })
      : await this.prisma.communityInvite.findFirst({
          where: {
            communityId,
            status: CommunityInviteStatus.PENDING,
            ...(inviteeId ? { inviteeUserId: inviteeId } : {}),
            ...(email ? { inviteeEmail: email.toLowerCase() } : {}),
          },
        });
    if (!invite) throw new NotFoundException('Invite not found');
    return this.prisma.communityInvite.update({
      where: { id: invite.id },
      data: { status: CommunityInviteStatus.REVOKED },
    });
  }

  async resendInvites(
    communityId: string,
    inviterId: string,
    inviteId?: string,
    inviteIds?: string[],
    templateKey?: string,
  ) {
    await this.checkCommunityPermission(communityId, inviterId, [
      CommunityRole.OWNER,
      CommunityRole.ADMIN,
      CommunityRole.MODERATOR,
    ]);
    const ids = inviteId ? [inviteId] : inviteIds ?? [];
    const invites = ids.length
      ? await this.prisma.communityInvite.findMany({
          where: { id: { in: ids }, communityId },
          include: { community: true, inviter: { include: { profile: true } } },
        })
      : await this.prisma.communityInvite.findMany({
          where: { communityId, status: CommunityInviteStatus.PENDING },
          include: { community: true, inviter: { include: { profile: true } } },
        });
    let resent = 0;
    for (const invite of invites) {
      if (invite.status !== CommunityInviteStatus.PENDING) continue;
      if (invite.expiresAt && invite.expiresAt < new Date()) {
        await this.prisma.communityInvite.update({
          where: { id: invite.id },
          data: { status: CommunityInviteStatus.EXPIRED },
        });
        continue;
      }
      await this.sendInviteNotificationAndEmail(
        invite,
        invite.community,
        invite.inviter.profile?.displayName || invite.inviter.email || 'Someone',
        templateKey,
      );
      resent += 1;
    }
    return { resent };
  }

  private async createOrUpdateInvite(
    communityId: string,
    inviterId: string,
    invitee: { userId?: string; email?: string },
    message?: string,
    expiresAt?: string,
  ) {
    const existing = await this.prisma.communityInvite.findFirst({
      where: {
        communityId,
        status: CommunityInviteStatus.PENDING,
        ...(invitee.userId ? { inviteeUserId: invitee.userId } : {}),
        ...(invitee.email ? { inviteeEmail: invitee.email.toLowerCase() } : {}),
      },
    });
    const inviteCode = this.generateInviteCode();
    if (existing) {
      return this.prisma.communityInvite.update({
        where: { id: existing.id },
        data: {
          inviteCode,
          message: message?.trim() || null,
          expiresAt: expiresAt ? new Date(expiresAt) : null,
          status: CommunityInviteStatus.PENDING,
        },
      });
    }
    return this.prisma.communityInvite.create({
      data: {
        communityId,
        inviterId,
        inviteeUserId: invitee.userId,
        inviteeEmail: invitee.email?.toLowerCase(),
        inviteCode,
        message: message?.trim() || null,
        expiresAt: expiresAt ? new Date(expiresAt) : null,
      },
    });
  }

  private buildInviteLink(code: string) {
    return this.emailLinkRouter.getCommunityInviteLink(code);
  }

  private generateInviteCode() {
    return Math.random().toString(36).slice(2, 10).toUpperCase();
  }

  private async sendInviteNotificationAndEmail(
    invite: any,
    community: any,
    inviterName: string,
    templateKey?: string,
  ) {
    const link = this.buildInviteLink(invite.inviteCode);
    if (invite.inviteeUserId) {
      try {
        await this.notifications.createNotification({
          userId: invite.inviteeUserId,
          type: NotificationType.COMMUNITY_INVITE,
          title: 'Community invite',
          message: `${inviterName} invited you to join ${community.name}`,
          actionUrl: `/communities/${community.id}`,
          sourceId: community.id,
          sourceType: 'community',
          priority: NotificationPriority.HIGH,
          data: {
            communityId: community.id,
            inviterName,
            inviteCode: invite.inviteCode,
            inviteLink: link,
            message: invite.message,
            expiresAt: invite.expiresAt,
          },
        });
      } catch {
        // Non-blocking
      }
    }

    const toEmail = invite.inviteeEmail || (invite.inviteeUserId
      ? (await this.prisma.user.findUnique({
          where: { id: invite.inviteeUserId },
          select: { email: true },
        }))?.email
      : null);
    if (!toEmail) return;

    try {
      this.email.dispatchInBackground({
        eventName: EmailEventName.CommunityInviteReceived,
        recipient: { email: toEmail },
        vars: {
          targetName: toEmail,
          communityName: community.name,
          inviterName,
          inviteUrl: link,
        },
      });
    } catch {
      // Non-blocking
    }
  }

  private async acceptInviteRecord(invite: any, userId: string) {
    if (invite.status !== CommunityInviteStatus.PENDING) {
      throw new BadRequestException('Invite is no longer active');
    }
    if (invite.expiresAt && invite.expiresAt < new Date()) {
      await this.prisma.communityInvite.update({
        where: { id: invite.id },
        data: { status: CommunityInviteStatus.EXPIRED },
      });
      throw new BadRequestException('Invite expired');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, profile: { select: { displayName: true } } },
    });
    if (invite.inviteeUserId && invite.inviteeUserId !== userId) {
      throw new ForbiddenException('Invite not for this user');
    }
    if (invite.inviteeEmail && user?.email && invite.inviteeEmail !== user.email.toLowerCase()) {
      throw new ForbiddenException('Invite not for this user');
    }

    const existing = await this.prisma.communityMember.findUnique({
      where: { communityId_userId: { communityId: invite.communityId, userId } },
    });

    const member = await this.prisma.communityMember.upsert({
      where: { communityId_userId: { communityId: invite.communityId, userId } },
      create: {
        communityId: invite.communityId,
        userId,
        role: CommunityRole.MEMBER,
        status: MemberStatus.ACTIVE,
        invitedBy: invite.inviterId,
        joinedAt: new Date(),
      },
      update: {
        status: MemberStatus.ACTIVE,
        invitedBy: invite.inviterId,
        joinedAt: new Date(),
      },
      include: { user: { include: { profile: true } }, community: true },
    });

    await this.prisma.communityInvite.update({
      where: { id: invite.id },
      data: { status: CommunityInviteStatus.ACCEPTED, acceptedAt: new Date() },
    });

    if (!existing || existing.status !== MemberStatus.ACTIVE) {
      await this.prisma.community.update({
        where: { id: invite.communityId },
        data: { memberCount: { increment: 1 } },
      });
    }

    try {
      await this.notifications.createNotification({
        userId: invite.inviterId,
        type: NotificationType.SYSTEM_ANNOUNCEMENT,
        title: 'Invite accepted',
        message: `${user?.profile?.displayName || 'Someone'} accepted your invite`,
        actionUrl: `/communities/${invite.communityId}`,
        sourceId: invite.communityId,
        sourceType: 'community',
        priority: NotificationPriority.NORMAL,
        data: { communityId: invite.communityId, memberId: member.id },
      });
      const inviter = await this.prisma.user.findUnique({
        where: { id: invite.inviterId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (inviter?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.CommunityInviteAccepted,
          recipient: { email: inviter.email, userId: invite.inviterId },
          vars: {
            actorName: user?.profile?.displayName || user?.email || 'Someone',
            targetName: inviter.email,
            communityName: member.community.name,
          },
        });
      }
    } catch {
      // Non-blocking
    }

    return member;
  }

  async leaveCommunity(communityId: string, userId: string) {
    const membership = await this.prisma.communityMember.findUnique({
      where: {
        communityId_userId: {
          communityId,
          userId
        }
      }
    });

    if (!membership || membership.status !== MemberStatus.ACTIVE) {
      throw new NotFoundException('Membership not found');
    }

    if (membership.role === CommunityRole.OWNER) {
      throw new ForbiddenException('Owner cannot leave community');
    }

    await Promise.all([
      this.prisma.communityMember.update({
        where: {
          communityId_userId: {
            communityId,
            userId
          }
        },
        data: {
          status: MemberStatus.LEFT,
          leftAt: new Date()
        }
      }),
      this.prisma.community.update({
        where: { id: communityId },
        data: {
          memberCount: {
            decrement: 1
          }
        }
      })
    ]);

    return { success: true };
  }

  async getCommunityMembers(communityId: string, userId: string) {
    if (!userId || userId.trim() === '') {
      throw new ForbiddenException('Authentication required');
    }
    
    const community = await this.prisma.community.findUnique({
      where: { id: communityId }
    });
    
    if (!community) {
      throw new NotFoundException('Community not found');
    }

    // Check if user is the creator (owner) - they always have access
    if (community.createdById === userId) {
      // Owner can view all members
      const communityWithMembers = await this.prisma.community.findUnique({
        where: { id: communityId },
        include: {
          members: {
            where: { status: MemberStatus.ACTIVE },
            include: {
              user: {
                include: { profile: true }
              }
            },
            orderBy: [
              { role: 'asc' },
              { joinedAt: 'asc' }
            ]
          }
        }
      });
      
      return {
        members: communityWithMembers?.members ?? [],
        total: communityWithMembers?.members.length ?? 0
      };
    }

    // For non-owners, check membership
    // Public communities allow viewing members even if not a member
    // Private communities require membership
    if (community.type === CommunityType.PRIVATE) {
      // Private communities require active membership
      await this.checkCommunityAccessWithRadius(communityId, userId);
    } else {
      // Public communities - check if user is a member, but don't require it
      const membership = await this.prisma.communityMember.findUnique({
        where: {
          communityId_userId: {
            communityId,
            userId
          }
        }
      });
      
      // If user is not a member of a public community, they can still view members
      // but we log it for reference
      if (!membership || membership.status !== MemberStatus.ACTIVE) {
        // Public community: non-members may still view member list
      }
    }
    
    const communityWithMembers = await this.prisma.community.findUnique({
      where: { id: communityId },
      include: {
        members: {
          where: { status: MemberStatus.ACTIVE },
          include: {
            user: {
              include: { profile: true }
            }
          },
          orderBy: [
            { role: 'asc' },
            { joinedAt: 'asc' }
          ]
        }
      }
    });
    
    return {
      members: communityWithMembers?.members ?? [],
      total: communityWithMembers?.members.length ?? 0
    };
  }

  async getMyMembership(communityId: string, userId: string) {
    // Check if user is the creator (owner)
    const community = await this.prisma.community.findUnique({
      where: { id: communityId },
      select: { createdById: true }
    });

    if (!community) {
      throw new NotFoundException('Community not found');
    }

    // If user is the creator, they are automatically a member with OWNER role
    if (community.createdById === userId) {
      return {
        isMember: true,
        role: CommunityRole.OWNER,
        status: MemberStatus.ACTIVE,
        isOwner: true,
      };
    }

    // Check membership
    const membership = await this.prisma.communityMember.findUnique({
      where: {
        communityId_userId: {
          communityId,
          userId
        }
      }
    });

    if (!membership || membership.status !== MemberStatus.ACTIVE) {
      return {
        isMember: false,
        role: null,
        status: null,
        isOwner: false,
      };
    }

    return {
      isMember: true,
      role: membership.role,
      status: membership.status,
      isOwner: membership.role === CommunityRole.OWNER,
    };
  }

  async updateMemberRole(communityId: string, memberId: string, userId: string, dto: UpdateMemberRoleDto) {
    await this.checkCommunityPermission(communityId, userId, [CommunityRole.OWNER, CommunityRole.ADMIN]);

    const member = await this.prisma.communityMember.findUnique({
      where: { id: memberId },
      include: { user: { include: { profile: true } } }
    });

    if (!member || member.communityId !== communityId) {
      throw new NotFoundException('Member not found');
    }

    if (member.role === CommunityRole.OWNER && dto.role !== CommunityRole.OWNER) {
      throw new ForbiddenException('Cannot change owner role');
    }

    return this.prisma.communityMember.update({
      where: { id: memberId },
      data: { role: dto.role },
      include: {
        user: {
          include: { profile: true }
        }
      }
    });
  }

  async removeMember(communityId: string, memberId: string, userId: string, banReason?: string) {
    await this.checkCommunityPermission(communityId, userId, [CommunityRole.OWNER, CommunityRole.ADMIN]);

    const member = await this.prisma.communityMember.findUnique({
      where: { id: memberId }
    });

    if (!member || member.communityId !== communityId) {
      throw new NotFoundException('Member not found');
    }

    if (member.role === CommunityRole.OWNER) {
      throw new ForbiddenException('Cannot remove community owner');
    }

    await Promise.all([
      this.prisma.communityMember.update({
        where: { id: memberId },
        data: {
          status: banReason ? MemberStatus.BANNED : MemberStatus.LEFT,
          bannedAt: banReason ? new Date() : null,
          banReason
        }
      }),
      this.prisma.community.update({
        where: { id: communityId },
        data: {
          memberCount: {
            decrement: 1
          }
        }
      })
    ]);

    return { success: true };
  }

  // Posts
  async createPost(communityId: string, userId: string, dto: CreatePostDto) {
    await this.checkMembership(communityId, userId);

    const post = await this.prisma.communityPost.create({
      data: {
        ...dto,
        communityId,
        authorId: userId,
        type: dto.type || PostType.TEXT
      },
      include: {
        author: {
          include: { profile: true }
        },
        community: true,
        _count: {
          select: {
            likes: true,
            comments: true
          }
        }
      }
    });

    // Update community post count
    await this.prisma.community.update({
      where: { id: communityId },
      data: {
        postCount: {
          increment: 1
        }
      }
    });

    await this.notifyMentions(post, dto.content || '', dto.title || '');

    return post;
  }

  // Ask-Request: Create a request post
  async createRequest(userId: string, dto: CreateRequestDto) {
    await this.checkMembership(dto.communityId, userId);

    const request = await this.prisma.communityPost.create({
      data: {
        title: dto.title,
        content: dto.content,
        communityId: dto.communityId,
        authorId: userId,
        type: PostType.TEXT,
        intentType: 'ASK',
        intentSubType: 'REQUEST',
        tags: dto.tags || [],
        mediaKeys: dto.mediaKeys || [],
      },
      include: {
        author: {
          include: { profile: true }
        },
        community: true,
        _count: {
          select: {
            likes: true,
            comments: true
          }
        }
      }
    });

    // Update community post count
    await this.prisma.community.update({
      where: { id: dto.communityId },
      data: {
        postCount: {
          increment: 1
        }
      }
    });

    await this.notifyMentions(request, dto.content || '', dto.title || '');

    return request;
  }

  private async notifyMentions(post: any, content: string, title: string) {
    const usernames = new Set<string>();
    const extract = (text: string) => {
      const regex = /@([a-zA-Z0-9_]{3,20})/g;
      let match: RegExpExecArray | null = null;
      while ((match = regex.exec(text)) !== null) {
        usernames.add(match[1].toLowerCase());
      }
    };
    extract(content);
    extract(title);
    if (usernames.size === 0) return;

    const users = await this.prisma.user.findMany({
      where: { profile: { username: { in: Array.from(usernames), mode: 'insensitive' } } },
      select: { id: true, email: true, profile: { select: { displayName: true, username: true } } },
    });

    const actorName = post.author?.profile?.displayName || post.author?.email || 'Someone';
    const communityName = post.community?.name || 'community';
    await Promise.all(
      users
        .filter((u) => u.email && u.id !== post.authorId)
        .map((u) =>
          this.email.dispatch({
            eventName: EmailEventName.CommunityMention,
            recipient: { email: u.email as string, userId: u.id },
            vars: {
              targetName: u.profile?.displayName || u.email,
              actorName,
              communityName,
              postUrl: this.emailLinkRouter.getWebLink(`/communities/${post.communityId}/posts/${post.id}`),
            },
            metadata: { ref: `${post.communityId}:${post.id}` },
          }),
        ),
    );
  }

  async getCommunityPosts(communityId: string, userId?: string, page = 1, size = 20) {
    if (!userId) {
      throw new ForbiddenException('Authentication required');
    }
    
    // This will check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(communityId, userId);
    
    const skip = (page - 1) * size;
    const [posts, total] = await Promise.all([
      this.prisma.communityPost.findMany({
        where: {
          communityId,
          status: PostStatus.ACTIVE
        },
        include: {
          author: {
            include: { profile: true }
          },
          _count: {
            select: {
              likes: true,
              comments: true
            }
          }
        },
        skip,
        take: size,
        orderBy: [
          { isPinned: 'desc' },
          { createdAt: 'desc' }
        ]
      }),
      this.prisma.communityPost.count({
        where: {
          communityId,
          status: PostStatus.ACTIVE
        }
      })
    ]);

    return {
      items: posts,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size)
    };
  }

  async likePost(postId: string, userId: string) {
    const post = await this.prisma.communityPost.findUnique({
      where: { id: postId },
      include: {
        author: { select: { id: true, profile: { select: { displayName: true } } } },
        community: { select: { name: true } },
      },
    });
    if (!post) throw new NotFoundException('Post not found');
    // Check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(post.communityId, userId);
    await this.prisma.communityPostLike.upsert({
      where: { postId_userId: { postId, userId } },
      update: {},
      create: { postId, userId },
    });

    if (post.author?.id && post.author.id !== userId) {
      try {
        const liker = await this.prisma.user.findUnique({
          where: { id: userId },
          select: { profile: { select: { displayName: true } } },
        });
        const likerName = liker?.profile?.displayName || 'Someone';
        const communityName = post.community?.name || 'your community';
        await this.notifications.createNotification({
          userId: post.author.id,
          type: NotificationType.COMMUNITY_POST_LIKED,
          title: 'Your post got a like',
          message: `${likerName} liked your post in ${communityName}`,
          actionUrl: `/communities/${post.communityId}/posts/${postId}`,
          sourceId: postId,
          sourceType: 'community_post',
          priority: NotificationPriority.NORMAL,
          data: { postId, communityId: post.communityId },
        });
      } catch {
        // Non-blocking
      }
    }
    return { ok: true };
  }

  async unlikePost(postId: string, userId: string) {
    const post = await this.prisma.communityPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('Post not found');
    // Check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(post.communityId, userId);
    await this.prisma.communityPostLike.deleteMany({ where: { postId, userId } });
    return { ok: true };
  }

  async getPostComments(postId: string, userId: string, page = 1, size = 10) {
    const post = await this.prisma.communityPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('Post not found');
    
    // Check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(post.communityId, userId);
    
    const skip = (page - 1) * size;
    const [comments, total] = await Promise.all([
      this.prisma.communityPostComment.findMany({
        where: { postId },
        include: { author: { include: { profile: true } } },
        skip,
        take: size,
        orderBy: [{ createdAt: 'asc' }],
      }),
      this.prisma.communityPostComment.count({ where: { postId } }),
    ]);
    return { items: comments, total, page, size, totalPages: Math.ceil(total / size) };
  }

  async createPostComment(postId: string, userId: string, body: { content: string; parentCommentId?: string }) {
    const post = await this.prisma.communityPost.findUnique({
      where: { id: postId },
      include: {
        author: { select: { id: true, profile: { select: { displayName: true } } } },
        community: { select: { name: true } },
      },
    });
    if (!post) throw new NotFoundException('Post not found');
    // Check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(post.communityId, userId);
    const comment = await this.prisma.communityPostComment.create({
      data: {
        postId,
        authorId: userId,
        content: body.content,
        parentId: body.parentCommentId ?? null,
      },
      include: { author: { include: { profile: true } } },
    });

    if (post.author?.id && post.author.id !== userId) {
      try {
        const commenterName = comment.author?.profile?.displayName || 'Someone';
        const communityName = post.community?.name || 'your community';
        await this.notifications.createNotification({
          userId: post.author.id,
          type: NotificationType.COMMUNITY_POST_COMMENTED,
          title: 'New comment on your post',
          message: `${commenterName} commented on your post in ${communityName}`,
          actionUrl: `/communities/${post.communityId}/posts/${postId}`,
          sourceId: postId,
          sourceType: 'community_post',
          priority: NotificationPriority.NORMAL,
          data: { postId, communityId: post.communityId },
        });
      } catch {
        // Non-blocking
      }
    }
    return comment;
  }

  async createEvent(communityId: string, userId: string, dto: CreateEventDto) {
    // Check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(communityId, userId);

    const event = await this.prisma.communityEvent.create({
      data: {
        ...dto,
        communityId,
        organizerId: userId,
        startDate: new Date(dto.startDate),
        endDate: new Date(dto.endDate),
        registrationDeadline: dto.registrationDeadline ? new Date(dto.registrationDeadline) : null,
        price: dto.price ? parseFloat(dto.price) : null
      },
      include: {
        organizer: {
          include: { profile: true }
        },
        community: true,
        _count: {
          select: {
            attendees: true
          }
        }
      }
    });

    // Update community event count
    await this.prisma.community.update({
      where: { id: communityId },
      data: {
        eventCount: {
          increment: 1
        }
      }
    });

    return event;
  }

  async getCommunityEvents(communityId: string, userId: string, page = 1, size = 20, upcoming = true) {
    if (!userId) {
      throw new ForbiddenException('Authentication required');
    }
    
    // Check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(communityId, userId);

    const skip = (page - 1) * size;
    const where: any = {
      communityId,
      status: { in: [EventStatus.UPCOMING, EventStatus.ONGOING] }
    };

    if (upcoming) {
      where.startDate = { gte: new Date() };
    }

    const [events, total] = await Promise.all([
      this.prisma.communityEvent.findMany({
        where,
        include: {
          organizer: {
            include: { profile: true }
          },
          _count: {
            select: {
              attendees: true
            }
          }
        },
        skip,
        take: size,
        orderBy: { startDate: 'asc' }
      }),
      this.prisma.communityEvent.count({ where })
    ]);

    return {
      items: events,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size)
    };
  }

  async registerForEvent(eventId: string, userId: string) {
    const event = await this.prisma.communityEvent.findUnique({
      where: { id: eventId },
      include: { community: true, _count: { select: { attendees: true } } }
    });

    if (!event) {
      throw new NotFoundException('Event not found');
    }

    // Check both membership and allow existing members access
    await this.checkCommunityAccessWithRadius(event.communityId, userId);

    // Check if already registered
    const existingRegistration = await this.prisma.communityEventAttendee.findUnique({
      where: {
        eventId_userId: {
          eventId,
          userId
        }
      }
    });

    if (existingRegistration) {
      throw new BadRequestException('Already registered for this event');
    }

    // Check capacity
    if (event.maxAttendees && event._count.attendees >= event.maxAttendees) {
      throw new BadRequestException('Event is full');
    }

    const attendee = await this.prisma.communityEventAttendee.create({
      data: {
        eventId,
        userId,
        status: AttendeeStatus.REGISTERED
      },
      include: {
        user: {
          include: { profile: true }
        }
      }
    });

    // Update attendee count
    await this.prisma.communityEvent.update({
      where: { id: eventId },
      data: {
        attendeeCount: {
          increment: 1
        }
      }
    });

    return attendee;
  }

  // Helper methods
  private async checkCommunityPermission(communityId: string, userId: string, requiredRoles: CommunityRole[]) {
    const membership = await this.prisma.communityMember.findUnique({
      where: {
        communityId_userId: {
          communityId,
          userId
        }
      }
    });

    if (!membership || membership.status !== MemberStatus.ACTIVE || !requiredRoles.includes(membership.role)) {
      throw new ForbiddenException('Insufficient permissions');
    }

    return membership;
  }

  private async checkMembership(communityId: string, userId: string) {
    const membership = await this.prisma.communityMember.findUnique({
      where: {
        communityId_userId: {
          communityId,
          userId
        }
      }
    });

    if (!membership || membership.status !== MemberStatus.ACTIVE) {
      throw new ForbiddenException('Must be a community member');
    }

    return membership;
  }

  private async checkCommunityAccess(communityId: string, userId?: string) {
    const community = await this.prisma.community.findUnique({
      where: { id: communityId }
    });

    if (!community) {
      throw new NotFoundException('Community not found');
    }

    if (community.type !== CommunityType.PUBLIC && userId) {
      await this.checkMembership(communityId, userId);
    }

    return community;
  }


  async checkCommunityAccessWithRadius(communityId: string, userId: string) {
    const community = await this.prisma.community.findUnique({
      where: { id: communityId }
    });

    if (!community) {
      throw new NotFoundException('Community not found');
    }

    // Community creators (owners) have full access regardless of location or membership record
    // Check this FIRST before checking membership
    if (community.createdById === userId) {
      // Ensure membership record exists for creator (should already exist, but create if missing)
      let membership = await this.prisma.communityMember.findUnique({
        where: {
          communityId_userId: {
            communityId,
            userId
          }
        }
      });

      // If membership doesn't exist, create it (shouldn't happen, but safety check)
      if (!membership) {
        membership = await this.prisma.communityMember.create({
          data: {
            communityId,
            userId,
            role: CommunityRole.OWNER,
            status: MemberStatus.ACTIVE,
          }
        });
        // Update member count
        await this.prisma.community.update({
          where: { id: communityId },
          data: { memberCount: { increment: 1 } }
        });
      }
      
      return { community, membership };
    }

    // Check membership for non-creators
    const membership = await this.prisma.communityMember.findUnique({
      where: {
        communityId_userId: {
          communityId,
          userId
        }
      }
    });

    if (!membership || membership.status !== MemberStatus.ACTIVE) {
      throw new ForbiddenException('Must be a community member');
    }

    // Existing members retain access regardless of current location
    // They met the radius requirements when they initially joined
    return { community, membership };
  }

  /**
   * Get the maximum distance (in meters) allowed for joining a community
   * Defaults to 100km (100000m) if not configured
   */
  async getCommunityJoinDistance(): Promise<number> {
    try {
      const setting = await (this.prisma as any).appSetting.findUnique({
        where: { key: 'community_join_distance_meters' }
      });
      if (setting?.value) {
        const distance = parseInt(setting.value, 10);
        if (!isNaN(distance) && distance > 0) {
          return distance;
        }
      }
    } catch (e) {
      console.error('[getCommunityJoinDistance] Error fetching setting:', e);
    }
    // Default to 100km (100000 meters)
    return 100000;
  }
}

export function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (v: number) => (v * Math.PI) / 180;
  const R = 6371000; // Earth radius in meters
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
