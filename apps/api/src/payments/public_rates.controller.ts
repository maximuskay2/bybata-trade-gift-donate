import { Controller, Get, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Controller('v1/public/rates')
export class PublicRatesController {
  constructor(private prisma: PrismaService) {}

  /**
   * Get public conversion rates
   * Only returns rates that are currently valid (respects validity windows)
   */
  @Get()
  async list(@Query('active') active?: string) {
    const onlyActive = active === 'true' || active === '1' || active === undefined;
    const now = new Date();

    // Get all rates (active or all based on query param)
    const allRates = await (this.prisma as any).conversionRate.findMany({
      where: onlyActive ? { active: true } : {},
      orderBy: { createdAt: 'desc' },
    });

    // Filter to only include rates that are currently valid
    const validRates = allRates.filter((rate: any) => {
      const validFrom = rate.validFrom ? new Date(rate.validFrom) : null;
      const validTo = rate.validTo ? new Date(rate.validTo) : null;

      const isFromValid = !validFrom || validFrom <= now;
      const isToValid = !validTo || validTo >= now;

      return isFromValid && isToValid;
    });

    // Group by base/quote pair and return the most recent valid rate for each
    const rateMap = new Map<string, any>();
    for (const rate of validRates) {
      const key = `${rate.base}_${rate.quote}`;
      if (!rateMap.has(key)) {
        rateMap.set(key, rate);
      }
    }

    return { items: Array.from(rateMap.values()) };
  }
}
