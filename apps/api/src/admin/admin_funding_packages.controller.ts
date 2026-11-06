import { Body, Controller, Get, Post, Patch, Delete, Param, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/funding-packages')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminFundingPackagesController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list() {
    return this.prisma.fundingPackage.findMany({
      orderBy: { sortOrder: 'asc' },
    });
  }

  @Post()
  async create(
    @Body()
    body: {
      name: string;
      description?: string;
      price: number;
      currency?: string;
      bonusPercentage?: number;
      isPopular?: boolean;
      sortOrder?: number;
      active?: boolean;
    },
  ) {
    return this.prisma.fundingPackage.create({
      data: {
        name: body.name,
        description: body.description ?? null,
        price: body.price,
        currency: body.currency ?? 'USD',
        bonusPercentage: body.bonusPercentage ?? 0,
        isPopular: body.isPopular ?? false,
        sortOrder: body.sortOrder ?? 0,
        active: body.active ?? true,
      },
    });
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body()
    body: {
      name?: string;
      description?: string;
      price?: number;
      currency?: string;
      bonusPercentage?: number;
      isPopular?: boolean;
      sortOrder?: number;
      active?: boolean;
    },
  ) {
    const data: Record<string, unknown> = {};
    if (body.name != null) data.name = body.name;
    if (body.description != null) data.description = body.description;
    if (body.price != null) data.price = body.price;
    if (body.currency != null) data.currency = body.currency;
    if (body.bonusPercentage != null) data.bonusPercentage = body.bonusPercentage;
    if (body.isPopular != null) data.isPopular = body.isPopular;
    if (body.sortOrder != null) data.sortOrder = body.sortOrder;
    if (body.active != null) data.active = body.active;
    return this.prisma.fundingPackage.update({
      where: { id },
      data,
    });
  }

  @Delete(':id')
  async delete(@Param('id') id: string) {
    return this.prisma.fundingPackage.delete({ where: { id } });
  }
}
