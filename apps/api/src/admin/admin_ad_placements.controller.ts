import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/ad-placements')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminAdPlacementsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list() {
    return this.prisma.adPlacement.findMany({ orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }] });
  }

  @Post()
  async create(@Body() body: { key: string; title: string; description?: string; priority?: number; rules?: any; active?: boolean }) {
    return this.prisma.adPlacement.create({
      data: {
        key: body.key,
        title: body.title,
        description: body.description,
        priority: body.priority ?? 0,
        rules: body.rules,
        active: body.active ?? true,
      } as any,
    });
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() body: { title?: string; description?: string; priority?: number; rules?: any; active?: boolean }) {
    return this.prisma.adPlacement.update({
      where: { id },
      data: {
        title: body.title,
        description: body.description,
        priority: body.priority,
        rules: body.rules,
        active: body.active,
      } as any,
    });
  }

  @Delete(':id')
  async remove(@Param('id') id: string) {
    await this.prisma.adPlacement.delete({ where: { id } });
    return { ok: true };
  }
}
