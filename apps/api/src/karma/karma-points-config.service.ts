import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import {
  DEFAULT_KARMA_POINTS,
  KARMA_POINTS_FIELD_META,
  KARMA_POINTS_SETTING_KEYS,
  KarmaPointsConfig,
  LEGACY_KARMA_POINTS,
  parsePointsConfigValue,
} from './karma-points-config';

@Injectable()
export class KarmaPointsConfigService {
  private cache: KarmaPointsConfig | null = null;
  private cacheAt = 0;
  private readonly cacheTtlMs = 30_000;

  constructor(private prisma: PrismaService) {}

  invalidateCache(): void {
    this.cache = null;
    this.cacheAt = 0;
  }

  async getConfig(): Promise<KarmaPointsConfig> {
    const now = Date.now();
    if (this.cache && now - this.cacheAt < this.cacheTtlMs) {
      return this.cache;
    }

    const keys = Object.values(KARMA_POINTS_SETTING_KEYS);
    const rows = await this.prisma.appSetting.findMany({
      where: { key: { in: keys } },
    });
    const byKey = new Map(rows.map((r) => [r.key, r.value]));

    const config = { ...DEFAULT_KARMA_POINTS };
    for (const field of KARMA_POINTS_FIELD_META) {
      const settingKey = KARMA_POINTS_SETTING_KEYS[field.key];
      config[field.key] = parsePointsConfigValue(
        field.key,
        byKey.get(settingKey),
      );
    }

    // Ensure gift min/max ordering
    if (config.giftRewardMin > config.giftRewardMax) {
      const tmp = config.giftRewardMin;
      config.giftRewardMin = config.giftRewardMax;
      config.giftRewardMax = tmp;
    }

    this.cache = config;
    this.cacheAt = now;
    return config;
  }

  async upsertPartial(
    partial: Partial<KarmaPointsConfig>,
  ): Promise<KarmaPointsConfig> {
    const entries = Object.entries(partial).filter(
      ([, v]) => v !== undefined && v !== null,
    ) as [keyof KarmaPointsConfig, number][];

    for (const [key, value] of entries) {
      const settingKey = KARMA_POINTS_SETTING_KEYS[key];
      if (!settingKey) continue;
      const meta = KARMA_POINTS_FIELD_META.find((f) => f.key === key);
      const clamped = meta
        ? Math.min(meta.max, Math.max(meta.min, Number(value)))
        : Number(value);
      await this.prisma.appSetting.upsert({
        where: { key: settingKey },
        update: { value: String(clamped) },
        create: { key: settingKey, value: String(clamped) },
      });
    }

    this.invalidateCache();
    return this.getConfig();
  }

  getDefaults() {
    return DEFAULT_KARMA_POINTS;
  }

  getLegacy() {
    return LEGACY_KARMA_POINTS;
  }

  getFieldMeta() {
    return KARMA_POINTS_FIELD_META;
  }
}
