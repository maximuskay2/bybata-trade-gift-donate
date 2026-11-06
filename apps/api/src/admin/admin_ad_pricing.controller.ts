import { Body, Controller, Get, Post, UseGuards, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

const KEYS = {
  TRADE: 'AD_PRICING_TRADE_BYC_PER_DAY',
  GIFT: 'AD_PRICING_GIFT_BYC_PER_DAY',
  DONATION: 'AD_PRICING_DONATION_BYC_PER_DAY',
  NORMAL: 'AD_PRICING_NORMAL_BYC_PER_DAY',
} as const;

@Controller('v1/admin/settings/ad-pricing')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminAdPricingController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async get() {
    const [trade, gift, donation, normal] = await Promise.all([
      this.prisma.appSetting.findUnique({ where: { key: KEYS.TRADE } }),
      this.prisma.appSetting.findUnique({ where: { key: KEYS.GIFT } }),
      this.prisma.appSetting.findUnique({ where: { key: KEYS.DONATION } }),
      this.prisma.appSetting.findUnique({ where: { key: KEYS.NORMAL } }),
    ]);
    return {
      tradeBycPerDay: trade ? parseFloat(trade.value) : 2.5,
      giftBycPerDay: gift ? parseFloat(gift.value) : 2,
      donationBycPerDay: donation ? parseFloat(donation.value) : 2,
      normalBycPerDay: normal ? parseFloat(normal.value) : 3,
    };
  }

  @Post('upsert')
  async upsert(
    @Body()
    body: {
      tradeBycPerDay?: number;
      giftBycPerDay?: number;
      donationBycPerDay?: number;
      normalBycPerDay?: number;
    },
  ) {
    const validate = (v: number, name: string) => {
      if (v < 0 || v > 1000) {
        throw new BadRequestException(`${name} must be between 0 and 1000 BYC per day`);
      }
    };

    if (body.tradeBycPerDay !== undefined) {
      validate(body.tradeBycPerDay, 'Trade ads');
      await this.prisma.appSetting.upsert({
        where: { key: KEYS.TRADE },
        update: { value: String(body.tradeBycPerDay) },
        create: { key: KEYS.TRADE, value: String(body.tradeBycPerDay) },
      });
    }
    if (body.giftBycPerDay !== undefined) {
      validate(body.giftBycPerDay, 'Gift ads');
      await this.prisma.appSetting.upsert({
        where: { key: KEYS.GIFT },
        update: { value: String(body.giftBycPerDay) },
        create: { key: KEYS.GIFT, value: String(body.giftBycPerDay) },
      });
    }
    if (body.donationBycPerDay !== undefined) {
      validate(body.donationBycPerDay, 'Donation ads');
      await this.prisma.appSetting.upsert({
        where: { key: KEYS.DONATION },
        update: { value: String(body.donationBycPerDay) },
        create: { key: KEYS.DONATION, value: String(body.donationBycPerDay) },
      });
    }
    if (body.normalBycPerDay !== undefined) {
      validate(body.normalBycPerDay, 'Normal ads');
      await this.prisma.appSetting.upsert({
        where: { key: KEYS.NORMAL },
        update: { value: String(body.normalBycPerDay) },
        create: { key: KEYS.NORMAL, value: String(body.normalBycPerDay) },
      });
    }
    return this.get();
  }
}
