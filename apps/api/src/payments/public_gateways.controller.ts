import { Controller, Get, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Controller('v1/public/gateways')
export class PublicGatewaysController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(@Query('mode') mode?: 'test' | 'live') {
    const items = await (this.prisma as any).paymentGatewayConfig.findMany({
      where: { active: true, ...(mode ? { mode } : {}) },
      orderBy: { gateway: 'asc' },
    });
    // sanitize secrets
    return {
      items: items.map((i: any) => ({
        gateway: i.gateway,
        mode: i.mode,
        publicKey: i.publicKey,
        currencies: i.currencies,
        active: i.active,
      })),
    };
  }
}
