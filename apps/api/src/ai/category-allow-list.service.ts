import { Injectable, Logger } from '@nestjs/common';
import { GiftCategory, TradeCategory } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';

const SAFE_LABEL = /^[A-Za-z0-9][A-Za-z0-9 _-]{0,39}$/;

/**
 * Allow-list of category values the model may return.
 * Trade and gift categories come from the Prisma enums. Campaign categories
 * are free strings, so only distinct stored values that look like labels are
 * included.
 */
@Injectable()
export class CategoryAllowListService {
  private readonly logger = new Logger(CategoryAllowListService.name);
  private cached: { at: number; values: string[] } | null = null;

  constructor(private readonly prisma: PrismaService) {}

  async list(): Promise<string[]> {
    const now = Date.now();
    if (this.cached && now - this.cached.at < 60 * 60 * 1000) {
      return this.cached.values;
    }

    const values = new Set<string>([
      ...Object.values(TradeCategory),
      ...Object.values(GiftCategory),
    ]);

    try {
      const rows = await this.prisma.campaign.findMany({
        where: { category: { not: null } },
        distinct: ['category'],
        select: { category: true },
        take: 40,
      });
      for (const row of rows) {
        const label = row.category?.trim();
        if (label && SAFE_LABEL.test(label)) values.add(label);
      }
    } catch (err: any) {
      this.logger.warn(`category allow-list fallback to enums: ${err?.message || err}`);
    }

    const list = [...values];
    this.cached = { at: now, values: list };
    return list;
  }

  filterKnown(categories: string[], allow: string[]): string[] {
    const allowed = new Set(allow.map((c) => c.toLowerCase()));
    const out: string[] = [];
    for (const raw of categories) {
      const match = allow.find((c) => c.toLowerCase() === raw.trim().toLowerCase());
      if (match && allowed.has(match.toLowerCase()) && !out.includes(match)) {
        out.push(match);
      }
    }
    return out;
  }
}
