import { Controller, Get, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/communities/metrics')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminMetricsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async get() {
    const [communities, members, posts, events] = await Promise.all([
      this.prisma.community.count(),
      this.prisma.communityMember.count({ where: { status: 'ACTIVE' } }),
      this.prisma.communityPost.count(),
      this.prisma.communityEvent.count(),
    ]);
    return { totalCommunities: communities, activeMembers: members, totalPosts: posts, totalEvents: events };
  }
}
