import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaService } from '../common/prisma.service';
import { KarmaPointsConfigService } from '../karma/karma-points-config.service';
import type { KarmaPointsConfig } from '../karma/karma-points-config';

@Controller('v1/admin/settings/karma')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminKarmaSettingsController {
  constructor(
    private prisma: PrismaService,
    private karmaPointsConfig: KarmaPointsConfigService,
  ) {}

  @Get()
  async get() {
    const [minSetting, rateSetting, points] = await Promise.all([
      this.prisma.appSetting.findUnique({
        where: { key: 'KARMA_MIN_WITHDRAWAL_THRESHOLD' },
      }),
      this.prisma.appSetting.findUnique({ where: { key: 'KARMA_TO_BYC_RATE' } }),
      this.karmaPointsConfig.getConfig(),
    ]);

    return {
      minWithdrawalThreshold: minSetting ? parseInt(minSetting.value, 10) : 500,
      karmaToBycRate: rateSetting ? parseFloat(rateSetting.value) : 100,
      points,
      defaults: this.karmaPointsConfig.getDefaults(),
      legacy: this.karmaPointsConfig.getLegacy(),
      fields: this.karmaPointsConfig.getFieldMeta(),
    };
  }

  @Post('upsert')
  async upsert(
    @Body()
    body: {
      minWithdrawalThreshold?: number;
      karmaToBycRate?: number;
      points?: Partial<KarmaPointsConfig>;
    },
  ) {
    if (body.minWithdrawalThreshold !== undefined) {
      await this.prisma.appSetting.upsert({
        where: { key: 'KARMA_MIN_WITHDRAWAL_THRESHOLD' },
        update: { value: String(body.minWithdrawalThreshold) },
        create: {
          key: 'KARMA_MIN_WITHDRAWAL_THRESHOLD',
          value: String(body.minWithdrawalThreshold),
        },
      });
    }
    if (body.karmaToBycRate !== undefined) {
      await this.prisma.appSetting.upsert({
        where: { key: 'KARMA_TO_BYC_RATE' },
        update: { value: String(body.karmaToBycRate) },
        create: {
          key: 'KARMA_TO_BYC_RATE',
          value: String(body.karmaToBycRate),
        },
      });
    }
    if (body.points && Object.keys(body.points).length > 0) {
      await this.karmaPointsConfig.upsertPartial(body.points);
    }
    return this.get();
  }
}
