import { BadRequestException, Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { loadIntentMetrics } from '../search/intent-metrics';
import { ROLLOUT_CITIES, parseRolloutPercent, rolloutCity } from '../search/intent-rollout';

const KEY = 'AI_INTENT_ENABLED';
const PERCENT_KEY = 'AI_INTENT_ROLLOUT_PERCENT';
const CITY_KEY = 'AI_INTENT_ROLLOUT_CITY';

@Controller('v1/admin/settings/ai-intent')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminAiIntentSettingsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async get() {
    const [enabledRow, percentRow, cityRow, metrics] = await Promise.all([
      this.prisma.appSetting.findUnique({ where: { key: KEY } }),
      this.prisma.appSetting.findUnique({ where: { key: PERCENT_KEY } }),
      this.prisma.appSetting.findUnique({ where: { key: CITY_KEY } }),
      loadIntentMetrics(this.prisma),
    ]);
    const envDefault = (process.env.AI_INTENT_ENABLED ?? 'false').toLowerCase() === 'true';
    const override = enabledRow?.value === 'true' || enabledRow?.value === 'false' ? enabledRow.value : null;
    const enabled = override == null ? envDefault : override === 'true';
    const rolloutPercent = parseRolloutPercent(
      percentRow?.value ?? process.env.AI_INTENT_ROLLOUT_PERCENT,
    );
    const rolloutCityName = rolloutCity(cityRow?.value ?? process.env.AI_INTENT_ROLLOUT_CITY);
    return {
      enabled,
      override,
      envDefault,
      rolloutPercent,
      rolloutCity: rolloutCityName,
      cities: Object.keys(ROLLOUT_CITIES),
      metrics,
    };
  }

  @Post()
  async set(@Body() body: { enabled?: boolean; rolloutPercent?: number; rolloutCity?: string | null }) {
    if (typeof body?.enabled === 'boolean') {
      const enabled = body.enabled === true;
      await this.prisma.appSetting.upsert({
        where: { key: KEY },
        update: { value: enabled ? 'true' : 'false' },
        create: { key: KEY, value: enabled ? 'true' : 'false' },
      });
    }
    if (typeof body?.rolloutPercent === 'number' && Number.isFinite(body.rolloutPercent)) {
      const percent = String(parseRolloutPercent(String(body.rolloutPercent)));
      await this.prisma.appSetting.upsert({
        where: { key: PERCENT_KEY },
        update: { value: percent },
        create: { key: PERCENT_KEY, value: percent },
      });
    }
    if (body && Object.prototype.hasOwnProperty.call(body, 'rolloutCity')) {
      const raw = (body.rolloutCity ?? '').trim();
      if (raw && !rolloutCity(raw)) {
        throw new BadRequestException('Unknown rollout city. Leave it blank for every city, or use Uyo.');
      }
      if (!raw) {
        await this.prisma.appSetting.deleteMany({ where: { key: CITY_KEY } });
      } else {
        const city = rolloutCity(raw)!;
        await this.prisma.appSetting.upsert({
          where: { key: CITY_KEY },
          update: { value: city },
          create: { key: CITY_KEY, value: city },
        });
      }
    }
    return this.get();
  }
}
