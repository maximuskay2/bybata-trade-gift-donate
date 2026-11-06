import { Body, Controller, Get, Post, Put, Query, UseGuards, Req, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { encryptSecret } from '../common/crypto.util';
import type { Request } from 'express';
// use global fetch available in Node 18+

type UpsertGatewayDto = {
  gateway: 'paystack' | 'stripe' | 'paypal' | 'flutterwave';
  mode: 'test' | 'live';
  publicKey: string;
  secretKey: string;
  webhookUrl?: string;
  webhookSecret?: string;
  currencies?: string; // comma-separated
  active?: boolean;
};

@Controller('v1/admin/settings/gateways')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminGatewayConfigController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(@Query('gateway') gateway?: string) {
    const where: any = {};
    if (gateway) where.gateway = gateway;
    const items = await (this.prisma as any).paymentGatewayConfig.findMany({ where, orderBy: { updatedAt: 'desc' } });
    return { items };
  }

  @Post('upsert')
  async upsert(@Body() body: UpsertGatewayDto, @Req() req: any) {
    const { gateway, mode, publicKey, secretKey, webhookUrl, webhookSecret, currencies, active } = body;
    
    // Validate required fields with better error messages
    if (!gateway) throw new BadRequestException('Missing required field: gateway');
    if (!mode) throw new BadRequestException('Missing required field: mode');
    if (!publicKey || publicKey.trim().length === 0) throw new BadRequestException('Missing required field: publicKey');
    if (!secretKey || secretKey.trim().length === 0) throw new BadRequestException('Missing required field: secretKey');
    
    // Validate gateway and mode enum values
    if (!['paystack', 'stripe', 'paypal', 'flutterwave'].includes(gateway)) {
      throw new BadRequestException(`Invalid gateway value: ${gateway}. Must be one of: paystack, stripe, paypal, flutterwave`);
    }
    if (!['test', 'live'].includes(mode)) {
      throw new BadRequestException(`Invalid mode value: ${mode}. Must be one of: test, live`);
    }
    
    const encKey = process.env.CONFIG_ENCRYPTION_KEY;
    if (!encKey) {
      throw new BadRequestException('CONFIG_ENCRYPTION_KEY environment variable is not set. Please configure it in your .env file.');
    }
    if (encKey.length !== 64) {
      throw new BadRequestException(
        `CONFIG_ENCRYPTION_KEY is ${encKey.length} characters long, but it must be exactly 64 characters (32 bytes in hex format). ` +
        'Generate a new key using: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"'
      );
    }
    
    const secretKeyEnc = encryptSecret(secretKey.trim(), encKey);
    const data: any = { gateway, mode, publicKey, secretKey: '', secretKeyEnc, webhookUrl, webhookSecret, currencies, active: active ?? true };
    const prev = await (this.prisma as any).paymentGatewayConfig.findUnique({ where: { gateway_mode: { gateway, mode } } });
    const cfg = await (this.prisma as any).paymentGatewayConfig.upsert({
      where: { gateway_mode: { gateway, mode } },
      update: { ...data },
      create: { ...data },
    });
    // Do NOT deactivate other gateways - each gateway is managed independently.
    // Previously we incorrectly set active:false on all other gateways, causing only
    // the last-updated gateway to be available to users.
    const admin = (req.user as any)?.sub as string | undefined;
    if (admin) {
      await (this.prisma as any).adminActionAudit.create({ data: { adminId: admin, action: 'GATEWAY_CONFIG_UPSERT', details: { gateway, mode, prev, next: cfg } } });
    }
    return { ok: true, config: cfg };
  }

  @Post('activate')
  async activate(@Body() body: { gateway: UpsertGatewayDto['gateway']; mode: UpsertGatewayDto['mode'] }) {
    const { gateway, mode } = body;
    if (!gateway || !mode) throw new BadRequestException('gateway and mode are required');
    const cfg = await (this.prisma as any).paymentGatewayConfig.findUnique({
      where: { gateway_mode: { gateway, mode } },
    });
    if (!cfg) throw new BadRequestException('Config not found');
    await (this.prisma as any).paymentGatewayConfig.update({
      where: { gateway_mode: { gateway, mode } },
      data: { active: true },
    });
    return { ok: true, message: `${gateway} (${mode}) activated` };
  }

  @Post('deactivate')
  async deactivate(@Body() body: { gateway: UpsertGatewayDto['gateway']; mode: UpsertGatewayDto['mode'] }) {
    const { gateway, mode } = body;
    if (!gateway || !mode) throw new BadRequestException('gateway and mode are required');
    const cfg = await (this.prisma as any).paymentGatewayConfig.findUnique({
      where: { gateway_mode: { gateway, mode } },
    });
    if (!cfg) throw new BadRequestException('Config not found');
    await (this.prisma as any).paymentGatewayConfig.update({
      where: { gateway_mode: { gateway, mode } },
      data: { active: false },
    });
    return { ok: true, message: `${gateway} (${mode}) deactivated` };
  }

  @Post('ping-webhook')
  async pingWebhook(@Body() body: { gateway: UpsertGatewayDto['gateway']; mode: UpsertGatewayDto['mode'] }) {
    const cfg = await (this.prisma as any).paymentGatewayConfig.findUnique({
      where: { gateway_mode: { gateway: body.gateway, mode: body.mode } },
    });
    if (!cfg?.webhookUrl) {
      return { ok: false, error: 'Webhook URL not set for this config' };
    }
    try {
      const res = await fetch(cfg.webhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(cfg.webhookSecret ? { 'X-Webhook-Secret': cfg.webhookSecret } : {}),
        },
        body: JSON.stringify({ type: 'ping', gateway: cfg.gateway, mode: cfg.mode, timestamp: new Date().toISOString() }),
      });
      return { ok: res.ok, status: res.status };
    } catch (e: any) {
      return { ok: false, error: e?.message ?? 'Ping failed' };
    }
  }

  @Post('verify')
  async verifyKeys(@Body() body: UpsertGatewayDto) {
    const { gateway, publicKey, secretKey } = body;
    if (!gateway || !publicKey || !secretKey) throw new BadRequestException('Missing required fields');
    try {
      if (gateway === 'stripe') {
        const res = await fetch('https://api.stripe.com/v1/account', { headers: { Authorization: `Bearer ${secretKey}` } });
        return { ok: res.ok, status: res.status };
      }
      if (gateway === 'paystack') {
        const res = await fetch('https://api.paystack.co/plan', { headers: { Authorization: `Bearer ${secretKey}` } });
        return { ok: res.ok, status: res.status };
      }
      if (gateway === 'paypal') {
        const basic = Buffer.from(`${publicKey}:${secretKey}`).toString('base64');
        const res = await fetch('https://api-m.sandbox.paypal.com/v1/oauth2/token', { method: 'POST', headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=client_credentials' });
        return { ok: res.ok, status: res.status };
      }
      if (gateway === 'flutterwave') {
        const res = await fetch('https://api.flutterwave.com/v3/banks/NG', { headers: { Authorization: `Bearer ${secretKey}` } });
        return { ok: res.ok, status: res.status };
      }
      return { ok: false, error: 'Unsupported gateway' };
    } catch (e: any) {
      return { ok: false, error: e?.message ?? 'Verification failed' };
    }
  }
}
