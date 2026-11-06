import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  UseGuards,
} from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { encryptSecret } from '../common/crypto.util';

type ProviderId = 'ebulksms' | 'twilio';

@Controller('v1/admin/settings/messaging')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminMessagingConfigController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async getConfig() {
    const channels = (await this.getSettingJson('MESSAGING_OTP_CHANNELS')) || {
      smsEnabled: false,
      whatsappEnabled: false,
      smsProvider: null,
      whatsappProvider: null,
    };
    const ebulksms = await this.getSettingJson('MESSAGING_PROVIDER_EBULKSMS');
    const twilio = await this.getSettingJson('MESSAGING_PROVIDER_TWILIO');

    const mask = (value?: string) => (value ? `****${value.slice(-4)}` : '');
    const encKey = process.env.CONFIG_ENCRYPTION_KEY;
    const encryptionStatus =
      encKey && encKey.length === 64 ? 'encrypted' : 'plaintext';

    return {
      encryptionStatus,
      channels: {
        smsEnabled: Boolean(channels.smsEnabled),
        whatsappEnabled: Boolean(channels.whatsappEnabled),
        smsProvider: channels.smsProvider ?? null,
        whatsappProvider: channels.whatsappProvider ?? null,
      },
      ebulksms: ebulksms
        ? {
            enabled: ebulksms.enabled !== false,
            username: ebulksms.username || '',
            smsSender: ebulksms.smsSender || 'Bybata',
            whatsappSubject: ebulksms.whatsappSubject || 'Bybata OTP',
            dndSender: Boolean(ebulksms.dndSender),
            apiKeyMasked: mask(ebulksms.apiKeyEnc),
            hasApiKey: Boolean(ebulksms.apiKeyEnc),
          }
        : {
            enabled: false,
            username: '',
            smsSender: 'Bybata',
            whatsappSubject: 'Bybata OTP',
            dndSender: false,
            apiKeyMasked: '',
            hasApiKey: false,
          },
      twilio: twilio
        ? {
            enabled: twilio.enabled !== false,
            accountSid: twilio.accountSid || '',
            fromNumber: twilio.fromNumber || '',
            whatsappFrom: twilio.whatsappFrom || '',
            authTokenMasked: mask(twilio.authTokenEnc),
            hasAuthToken: Boolean(twilio.authTokenEnc),
          }
        : {
            enabled: false,
            accountSid: '',
            fromNumber: '',
            whatsappFrom: '',
            authTokenMasked: '',
            hasAuthToken: false,
          },
    };
  }

  @Post('upsert')
  async upsert(
    @Body()
    body: {
      channels?: {
        smsEnabled?: boolean;
        whatsappEnabled?: boolean;
        smsProvider?: ProviderId | null;
        whatsappProvider?: ProviderId | null;
      };
      ebulksms?: {
        enabled?: boolean;
        username?: string;
        apiKey?: string;
        smsSender?: string;
        whatsappSubject?: string;
        dndSender?: boolean;
      };
      twilio?: {
        enabled?: boolean;
        accountSid?: string;
        authToken?: string;
        fromNumber?: string;
        whatsappFrom?: string;
      };
    },
  ) {
    const encKey = process.env.CONFIG_ENCRYPTION_KEY;
    const canEncrypt = Boolean(encKey && encKey.length === 64);
    if (encKey && encKey.length !== 64) {
      console.warn(
        'CONFIG_ENCRYPTION_KEY invalid length; storing messaging secrets unencrypted.',
      );
    }

    if (body.channels) {
      const smsProvider = body.channels.smsProvider ?? null;
      const whatsappProvider = body.channels.whatsappProvider ?? null;
      if (smsProvider && !['ebulksms', 'twilio'].includes(smsProvider)) {
        throw new BadRequestException('Invalid SMS provider');
      }
      if (whatsappProvider && !['ebulksms', 'twilio'].includes(whatsappProvider)) {
        throw new BadRequestException('Invalid WhatsApp provider');
      }
      await this.upsertSetting(
        'MESSAGING_OTP_CHANNELS',
        JSON.stringify({
          smsEnabled: Boolean(body.channels.smsEnabled),
          whatsappEnabled: Boolean(body.channels.whatsappEnabled),
          smsProvider,
          whatsappProvider,
        }),
      );
    }

    if (body.ebulksms) {
      const existing =
        (await this.getSettingJson('MESSAGING_PROVIDER_EBULKSMS')) || {};
      const payload: any = {
        enabled: body.ebulksms.enabled !== false,
        username: body.ebulksms.username ?? existing.username ?? '',
        smsSender: body.ebulksms.smsSender ?? existing.smsSender ?? 'Bybata',
        whatsappSubject:
          body.ebulksms.whatsappSubject ??
          existing.whatsappSubject ??
          'Bybata OTP',
        dndSender:
          body.ebulksms.dndSender !== undefined
            ? Boolean(body.ebulksms.dndSender)
            : Boolean(existing.dndSender),
        apiKeyEnc: existing.apiKeyEnc,
      };
      if (body.ebulksms.apiKey?.trim()) {
        payload.apiKeyEnc = canEncrypt
          ? encryptSecret(body.ebulksms.apiKey.trim(), encKey as string)
          : body.ebulksms.apiKey.trim();
      }
      await this.upsertSetting(
        'MESSAGING_PROVIDER_EBULKSMS',
        JSON.stringify(payload),
      );
    }

    if (body.twilio) {
      const existing =
        (await this.getSettingJson('MESSAGING_PROVIDER_TWILIO')) || {};
      const payload: any = {
        enabled: body.twilio.enabled !== false,
        accountSid: body.twilio.accountSid ?? existing.accountSid ?? '',
        fromNumber: body.twilio.fromNumber ?? existing.fromNumber ?? '',
        whatsappFrom: body.twilio.whatsappFrom ?? existing.whatsappFrom ?? '',
        authTokenEnc: existing.authTokenEnc,
      };
      if (body.twilio.authToken?.trim()) {
        payload.authTokenEnc = canEncrypt
          ? encryptSecret(body.twilio.authToken.trim(), encKey as string)
          : body.twilio.authToken.trim();
      }
      await this.upsertSetting(
        'MESSAGING_PROVIDER_TWILIO',
        JSON.stringify(payload),
      );
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
