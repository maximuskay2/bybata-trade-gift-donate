import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Controller('v1/public/funding-packages')
export class PublicFundingPackagesController {
  constructor(private prisma: PrismaService) {}

  /**
   * Get active funding packages with BYC amounts calculated from current exchange rates.
   */
  @Get()
  async list() {
    const packages = await this.prisma.fundingPackage.findMany({
      where: { active: true },
      orderBy: { sortOrder: 'asc' },
    });

    const now = new Date();
    const rates = await this.prisma.conversionRate.findMany({
      where: { active: true },
      orderBy: { createdAt: 'desc' },
    });

    const validRates = rates.filter((r: any) => {
      const validFrom = r.validFrom ? new Date(r.validFrom) : null;
      const validTo = r.validTo ? new Date(r.validTo) : null;
      const isFromValid = !validFrom || validFrom <= now;
      const isToValid = !validTo || validTo >= now;
      return isFromValid && isToValid;
    });

    const rateMap = new Map<string, number>();
    for (const r of validRates) {
      const key = `${r.base}_${r.quote}`;
      if (!rateMap.has(key)) {
        rateMap.set(key, Number(r.rate));
      }
    }

    // rate base_quote: 1 base = rate quote. So BYC_USD=0.10 means 1 BYC = $0.10, hence 1 USD = 10 BYC
    const bycPerUsd = rateMap.has('BYC_USD')
      ? 1 / rateMap.get('BYC_USD')!
      : rateMap.get('USD_BYC') ?? 10;
    const bycPerNgn = rateMap.has('BYC_NGN')
      ? 1 / rateMap.get('BYC_NGN')!
      : rateMap.get('NGN_BYC') ?? 1 / 800;

    return packages.map((pkg: any) => {
      const price = Number(pkg.price);
      const bonusPct = Number(pkg.bonusPercentage ?? 0);
      const currency = pkg.currency || 'USD';
      const bycAmount =
        currency === 'NGN' ? price * bycPerNgn : price * bycPerUsd;
      const bonus = bycAmount * (bonusPct / 100);
      const totalBYC = bycAmount + bonus;
      return {
        id: pkg.id,
        name: pkg.name,
        description: pkg.description,
        bycAmount: Math.round(bycAmount * 100) / 100,
        totalBYC: Math.round(totalBYC * 100) / 100,
        usdPrice: currency === 'USD' ? price : price * (bycPerNgn / bycPerUsd),
        price,
        currency,
        bonusPercentage: bonusPct,
        isPopular: pkg.isPopular ?? false,
      };
    });
  }
}
