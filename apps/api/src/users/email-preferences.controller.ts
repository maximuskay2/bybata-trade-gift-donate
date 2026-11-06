import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';

@Controller('v1/email/preferences')
@UseGuards(JwtAuthGuard)
export class EmailPreferencesController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async getPreferences(@CurrentUser() user: any) {
    const pref = await (this.prisma as any).emailPreference.findUnique({ where: { userId: user.sub } });
    if (pref) return pref;
    return {
      transactional: true,
      marketing: true,
      digest: true,
      weeklyReport: false,
    };
  }

  @Put()
  async updatePreferences(
    @CurrentUser() user: any,
    @Body() body: { transactional?: boolean; marketing?: boolean; digest?: boolean; weeklyReport?: boolean },
  ) {
    const existing = await (this.prisma as any).emailPreference.findUnique({ where: { userId: user.sub } });
    const data = {
      transactional: body.transactional ?? existing?.transactional ?? true,
      marketing: body.marketing ?? existing?.marketing ?? true,
      digest: body.digest ?? existing?.digest ?? true,
      weeklyReport: body.weeklyReport ?? existing?.weeklyReport ?? false,
    };
    const updated = await (this.prisma as any).emailPreference.upsert({
      where: { userId: user.sub },
      update: data,
      create: { userId: user.sub, ...data },
    });
    return updated;
  }
}
