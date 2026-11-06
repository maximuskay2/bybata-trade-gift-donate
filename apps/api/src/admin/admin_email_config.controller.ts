import { Body, Controller, Get, Post, UseGuards, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { encryptSecret } from '../common/crypto.util';

type EmailProvider = 'resend' | 'smtp' | 'sendgrid';

type EmailProviderConfigDto = {
  provider: EmailProvider;
  active?: boolean;
  resend?: {
    apiKey?: string;
    from?: string;
    useTemplateApi?: boolean;
    templateMap?: Record<string, string>;
  };
  smtp?: {
    host?: string;
    port?: number;
    secure?: boolean;
    user?: string;
    pass?: string;
    from?: string;
  };
  sendgrid?: {
    apiKey?: string;
    from?: string;
    templateMap?: Record<string, string>;
  };
};

@Controller('v1/admin/settings/email')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminEmailConfigController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async getConfig() {
    const active = await this.prisma.appSetting.findUnique({ where: { key: 'EMAIL_PROVIDER_ACTIVE' } });
    const resend = await this.getSettingJson('EMAIL_PROVIDER_RESEND');
    const smtp = await this.getSettingJson('EMAIL_PROVIDER_SMTP');
    const sendgrid = await this.getSettingJson('EMAIL_PROVIDER_SENDGRID');

    const mask = (value?: string) => (value ? `****${value.slice(-4)}` : '');
    const encKey = process.env.CONFIG_ENCRYPTION_KEY;
    const encryptionStatus = encKey && encKey.length === 64 ? 'encrypted' : 'plaintext';

    return {
      activeProvider: (active?.value as EmailProvider) || 'resend',
      encryptionStatus,
      resend: resend
        ? { ...resend, apiKeyEnc: undefined, apiKeyMasked: mask(resend.apiKeyEnc) }
        : null,
      smtp: smtp
        ? { ...smtp, passEnc: undefined, passMasked: mask(smtp.passEnc) }
        : null,
      sendgrid: sendgrid
        ? { ...sendgrid, apiKeyEnc: undefined, apiKeyMasked: mask(sendgrid.apiKeyEnc) }
        : null,
    };
  }

  @Post('set-active')
  async setActiveProvider(@Body() body: { provider: EmailProvider }) {
    if (!body?.provider) throw new BadRequestException('provider is required');
    if (!['resend', 'smtp', 'sendgrid'].includes(body.provider)) {
      throw new BadRequestException('Invalid provider');
    }
    await this.upsertSetting('EMAIL_PROVIDER_ACTIVE', body.provider);
    return { ok: true };
  }

  @Post('upsert')
  async upsert(@Body() body: EmailProviderConfigDto) {
    const encKey = process.env.CONFIG_ENCRYPTION_KEY;
    const canEncrypt = Boolean(encKey && encKey.length === 64);
    if (encKey && encKey.length !== 64) {
      console.warn('CONFIG_ENCRYPTION_KEY invalid length; storing email secrets unencrypted.');
    }

    if (!body?.provider) throw new BadRequestException('provider is required');
    if (!['resend', 'smtp', 'sendgrid'].includes(body.provider)) {
      throw new BadRequestException('Invalid provider');
    }

    if (body.resend) {
      const payload: any = {
        from: body.resend.from,
        useTemplateApi: Boolean(body.resend.useTemplateApi),
        templateMap: body.resend.templateMap || {},
      };
      if (body.resend.apiKey) {
        payload.apiKeyEnc = canEncrypt ? encryptSecret(body.resend.apiKey, encKey as string) : body.resend.apiKey;
        if (!canEncrypt) console.warn('CONFIG_ENCRYPTION_KEY missing; storing Resend key without encryption.');
      }
      await this.upsertSetting('EMAIL_PROVIDER_RESEND', JSON.stringify(payload));
    }

    if (body.smtp) {
      const payload: any = {
        host: body.smtp.host,
        port: body.smtp.port,
        secure: body.smtp.secure,
        user: body.smtp.user,
        from: body.smtp.from,
      };
      if (body.smtp.pass) {
        payload.passEnc = canEncrypt ? encryptSecret(body.smtp.pass, encKey as string) : body.smtp.pass;
        if (!canEncrypt) console.warn('CONFIG_ENCRYPTION_KEY missing; storing SMTP password without encryption.');
      }
      await this.upsertSetting('EMAIL_PROVIDER_SMTP', JSON.stringify(payload));
    }

    if (body.sendgrid) {
      const payload: any = {
        from: body.sendgrid.from,
        templateMap: body.sendgrid.templateMap || {},
      };
      if (body.sendgrid.apiKey) {
        payload.apiKeyEnc = canEncrypt ? encryptSecret(body.sendgrid.apiKey, encKey as string) : body.sendgrid.apiKey;
        if (!canEncrypt) console.warn('CONFIG_ENCRYPTION_KEY missing; storing SendGrid key without encryption.');
      }
      await this.upsertSetting('EMAIL_PROVIDER_SENDGRID', JSON.stringify(payload));
    }

    if (body.active) {
      await this.upsertSetting('EMAIL_PROVIDER_ACTIVE', body.provider);
    }

    return { ok: true };
  }

  private async getSettingJson(key: string) {
    const setting = await this.prisma.appSetting.findUnique({ where: { key } });
    if (!setting?.value) return null;
    try {
      return JSON.parse(setting.value);
    } catch {
      return null;
    }
  }

  private async upsertSetting(key: string, value: string) {
    await this.prisma.appSetting.upsert({
      where: { key },
      update: { value },
      create: { key, value },
    });
  }
}
