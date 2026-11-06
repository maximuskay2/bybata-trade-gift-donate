import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/boost-types')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminBoostTypesController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list() {
    return this.prisma.boostType.findMany({ orderBy: { createdAt: 'desc' } });
  }

  @Post()
  async create(@Body() body: { slug: string; title: string; description?: string; active?: boolean }) {
    return this.prisma.boostType.create({
      data: {
        slug: body.slug,
        title: body.title,
        description: body.description,
        active: body.active ?? true,
      } as any,
    });
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() body: { title?: string; description?: string; active?: boolean }) {
    return this.prisma.boostType.update({
      where: { id },
      data: {
        title: body.title,
        description: body.description,
        active: body.active,
      } as any,
    });
  }

  @Delete(':id')
  async remove(@Param('id') id: string) {
    await this.prisma.boostType.delete({ where: { id } });
    return { ok: true };
  }
}
