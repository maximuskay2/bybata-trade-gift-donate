import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/promotions')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminPromotionsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list() {
    return this.prisma.promotion.findMany({ orderBy: { createdAt: 'desc' } });
  }

  @Post()
  async create(@Body() body: { slug: string; title: string; type: string; amountBYC: number; active?: boolean; startsAt?: string; endsAt?: string }) {
    return this.prisma.promotion.create({
      data: {
        slug: body.slug,
        title: body.title,
        type: body.type,
        amountBYC: Number(body.amountBYC),
        active: body.active ?? true,
        startsAt: body.startsAt ? new Date(body.startsAt) : undefined,
        endsAt: body.endsAt ? new Date(body.endsAt) : undefined,
      } as any,
    });
  }

  @Patch('toggle')
  async toggle(@Body() body: { slug: string; active: boolean }) {
    return this.prisma.promotion.update({ where: { slug: body.slug }, data: { active: body.active } });
  }
}