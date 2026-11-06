import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/boost-configs')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminBoostConfigsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list() {
    return this.prisma.boostConfig.findMany({
      orderBy: { createdAt: 'desc' },
      include: { boostType: true },
    });
  }

  @Post()
  async create(@Body() body: {
    boostTypeId: string;
    minDays?: number;
    maxDays?: number;
    pricingModel?: string;
    baseCostBYC?: number;
    dailyCostBYC?: number;
    tiers?: any;
    placementKeys?: string[];
    active?: boolean;
  }) {
    return this.prisma.boostConfig.create({
      data: {
        boostTypeId: body.boostTypeId,
        minDays: body.minDays ?? 1,
        maxDays: body.maxDays ?? 30,
        pricingModel: body.pricingModel ?? 'FIXED',
        baseCostBYC: body.baseCostBYC,
        dailyCostBYC: body.dailyCostBYC,
        tiers: body.tiers,
        placementKeys: body.placementKeys ?? [],
        active: body.active ?? true,
      } as any,
    });
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() body: {
    minDays?: number;
    maxDays?: number;
    pricingModel?: string;
    baseCostBYC?: number;
    dailyCostBYC?: number;
    tiers?: any;
    placementKeys?: string[];
    active?: boolean;
  }) {
    return this.prisma.boostConfig.update({
      where: { id },
      data: {
        minDays: body.minDays,
        maxDays: body.maxDays,
        pricingModel: body.pricingModel,
        baseCostBYC: body.baseCostBYC,
        dailyCostBYC: body.dailyCostBYC,
        tiers: body.tiers,
        placementKeys: body.placementKeys,
        active: body.active,
      } as any,
    });
  }

  @Delete(':id')
  async remove(@Param('id') id: string) {
    await this.prisma.boostConfig.delete({ where: { id } });
    return { ok: true };
  }
}
