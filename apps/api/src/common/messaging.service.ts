import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { decryptSecret } from './crypto.util';
import * as crypto from 'crypto';

export type MessagingProviderId = 'ebulksms' | 'twilio';
export type MessagingChannel = 'sms' | 'whatsapp';

export type MessagingChannelsConfig = {
  smsEnabled: boolean;
  whatsappEnabled: boolean;
  smsProvider: MessagingProviderId | null;
  whatsappProvider: MessagingProviderId | null;
};

export type EbulkSmsConfig = {
  enabled: boolean;
  username?: string;
  apiKeyEnc?: string;
  smsSender?: string;
  whatsappSubject?: string;
  dndSender?: boolean;
};

export type TwilioConfig = {
  enabled: boolean;
  accountSid?: string;
  authTokenEnc?: string;
  fromNumber?: string;
  whatsappFrom?: string;
};

export type OtpSendResult = {
  ok: boolean;
  channelsAttempted: MessagingChannel[];
  channelsSent: MessagingChannel[];
  errors: Array<{ channel: MessagingChannel; provider: MessagingProviderId; error: string }>;
};

@Injectable()
export class MessagingService {
  private readonly logger = new Logger(MessagingService.name);

  constructor(private prisma: PrismaService) {}

  async getChannelsConfig(): Promise<MessagingChannelsConfig> {
    const raw = await this.getSettingJson('MESSAGING_OTP_CHANNELS');
    const fromDb: MessagingChannelsConfig = {
      smsEnabled: Boolean(raw?.smsEnabled),
      whatsappEnabled: Boolean(raw?.whatsappEnabled),
      smsProvider: this.asProvider(raw?.smsProvider),
      whatsappProvider: this.asProvider(raw?.whatsappProvider),
    };
    if (fromDb.smsEnabled || fromDb.whatsappEnabled) {
      return fromDb;
    }
    // Bootstrap from env when admin UI has not enabled channels yet.
    return this.envChannelsFallback();
  }

  async getEbulkConfig(): Promise<EbulkSmsConfig | null> {
    const raw = await this.getSettingJson('MESSAGING_PROVIDER_EBULKSMS');
    const username = raw?.username || process.env.EBULKSMS_USERNAME;
    const apiKeyEnc = raw?.apiKeyEnc || process.env.EBULKSMS_API_KEY;
    if (!raw && !username && !apiKeyEnc) return null;
    return {
      enabled: raw ? raw.enabled !== false : Boolean(username && apiKeyEnc),
      username,
      apiKeyEnc,
      smsSender: raw?.smsSender || process.env.EBULKSMS_SMS_SENDER || 'Bybata',
      whatsappSubject:
        raw?.whatsappSubject || process.env.EBULKSMS_WHATSAPP_SUBJECT || 'Bybata OTP',
      dndSender: Boolean(raw?.dndSender ?? process.env.EBULKSMS_DND_SENDER === '1'),
    };
  }

  async getTwilioConfig(): Promise<TwilioConfig | null> {
    const raw = await this.getSettingJson('MESSAGING_PROVIDER_TWILIO');
    const accountSid = raw?.accountSid || process.env.TWILIO_ACCOUNT_SID;
    const authTokenEnc = raw?.authTokenEnc || process.env.TWILIO_AUTH_TOKEN;
    if (!raw && !accountSid && !authTokenEnc) return null;
    return {
      enabled: raw ? raw.enabled !== false : Boolean(accountSid && authTokenEnc),
      accountSid,
      authTokenEnc,
      fromNumber: raw?.fromNumber || process.env.TWILIO_FROM_NUMBER,
      whatsappFrom: raw?.whatsappFrom || process.env.TWILIO_WHATSAPP_FROM,
    };
  }

  /** When AppSetting channels are off, enable SMS if provider credentials exist in env. */
  private envChannelsFallback(): MessagingChannelsConfig {
    const prefer =
      this.asProvider(process.env.MESSAGING_SMS_PROVIDER) ||
      (process.env.EBULKSMS_USERNAME && process.env.EBULKSMS_API_KEY
        ? 'ebulksms'
        : null) ||
      (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN
        ? 'twilio'
        : null);

    const smsForced = process.env.MESSAGING_SMS_ENABLED === 'true';
    const waForced = process.env.MESSAGING_WHATSAPP_ENABLED === 'true';
    const smsProvider =
      this.asProvider(process.env.MESSAGING_SMS_PROVIDER) || prefer;
    const whatsappProvider =
      this.asProvider(process.env.MESSAGING_WHATSAPP_PROVIDER) || prefer;

    return {
      smsEnabled: smsForced || Boolean(prefer),
      whatsappEnabled: waForced,
      smsProvider: smsForced || prefer ? smsProvider : null,
      whatsappProvider: waForced ? whatsappProvider : null,
    };
  }

  /** Normalize to digits-only international format (e.g. 2348012345678). */
  normalizePhone(input: string, defaultCountry = '234'): string {
    let phone = (input || '').trim().replace(/[\s\-()]/g, '');
    if (!phone) throw new BadRequestException('Phone number is required');
    if (phone.startsWith('+')) phone = phone.slice(1);
    if (phone.startsWith('00')) phone = phone.slice(2);
    if (phone.startsWith('0') && defaultCountry) {
      phone = defaultCountry + phone.slice(1);
    }
    if (!/^\d{10,15}$/.test(phone)) {
      throw new BadRequestException('Invalid phone number format');
    }
    return phone;
  }

  toE164(phoneDigits: string): string {
    return phoneDigits.startsWith('+') ? phoneDigits : `+${phoneDigits}`;
  }

  buildOtpMessage(code: string, ttlMinutes: number): string {
    return `Your Bybata verification code is ${code}. It expires in ${ttlMinutes} minutes. Do not share this code.`;
  }

  /**
   * Send OTP via admin-configured SMS and/or WhatsApp channels.
   * At least one enabled channel must succeed.
   */
  async sendOtp(params: {
    phoneNumber: string;
    code: string;
    ttlMinutes: number;
  }): Promise<OtpSendResult> {
    const channels = await this.getChannelsConfig();
    const phone = this.normalizePhone(params.phoneNumber);
    const message = this.buildOtpMessage(params.code, params.ttlMinutes);

    const attempted: MessagingChannel[] = [];
    const sent: MessagingChannel[] = [];
    const errors: OtpSendResult['errors'] = [];

    const jobs: Array<{
      channel: MessagingChannel;
      provider: MessagingProviderId;
    }> = [];

    if (channels.smsEnabled && channels.smsProvider) {
      jobs.push({ channel: 'sms', provider: channels.smsProvider });
    }
    if (channels.whatsappEnabled && channels.whatsappProvider) {
      jobs.push({ channel: 'whatsapp', provider: channels.whatsappProvider });
    }

    if (jobs.length === 0) {
      throw new BadRequestException(
        'No OTP channel is enabled. Ask an admin to configure SMS/WhatsApp messaging settings.',
      );
    }

    for (const job of jobs) {
      attempted.push(job.channel);
      try {
        if (job.provider === 'ebulksms') {
          await this.sendViaEbulk(job.channel, phone, message);
        } else {
          await this.sendViaTwilio(job.channel, phone, message);
        }
        sent.push(job.channel);
      } catch (e) {
        const msg = (e as Error)?.message || 'Send failed';
        this.logger.warn(`[${job.provider}/${job.channel}] OTP send failed: ${msg}`);
        errors.push({ channel: job.channel, provider: job.provider, error: msg });
      }
    }

    if (sent.length === 0) {
      throw new BadRequestException(
        `Failed to send verification code: ${errors.map((e) => e.error).join('; ')}`,
      );
    }

    return { ok: true, channelsAttempted: attempted, channelsSent: sent, errors };
  }

  private async sendViaEbulk(
    channel: MessagingChannel,
    phoneDigits: string,
    message: string,
  ) {
    const cfg = await this.getEbulkConfig();
    if (!cfg?.enabled) {
      throw new Error('EbulkSMS provider is disabled');
    }
    const apiKey = this.resolveSecret(cfg.apiKeyEnc, process.env.EBULKSMS_API_KEY);
    const username = cfg.username || process.env.EBULKSMS_USERNAME;
    if (!username || !apiKey) {
      throw new Error('EbulkSMS username/API key not configured');
    }

    if (channel === 'sms') {
      // https://www.ebulksms.com/pages/php-sample-code
      const msgid = `otp_${crypto.randomBytes(8).toString('hex')}`.slice(0, 30);
      const body = {
        SMS: {
          auth: { username, apikey: apiKey },
          message: {
            sender: (cfg.smsSender || 'Bybata').slice(0, 11),
            messagetext: message.slice(0, 612),
            flash: '0',
          },
          recipients: {
            gsm: [{ msidn: phoneDigits, msgid }],
          },
          dndsender: cfg.dndSender ? '1' : '0',
        },
      };
      const res = await fetch('https://api.ebulksms.com/sendsms.json', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const text = await res.text();
      this.assertEbulkSuccess(text, res.status, 'SMS');
      return;
    }

    // WhatsApp: https://www.ebulksms.com/pages/json-whatsapp-api
    const waBody = {
      WA: {
        auth: { username, apikey: apiKey },
        message: {
          subject: (cfg.whatsappSubject || 'Bybata OTP').slice(0, 40),
          messagetext: message.slice(0, 4000),
        },
        recipients: [phoneDigits],
      },
    };
    const res = await fetch('https://api.ebulksms.com/sendwhatsapp.json', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(waBody),
    });
    const text = await res.text();
    this.assertEbulkSuccess(text, res.status, 'WhatsApp');
  }

  private assertEbulkSuccess(raw: string, status: number, label: string) {
    let parsed: any = null;
    try {
      parsed = JSON.parse(raw);
    } catch {
      // HTTP GET style responses may be plain SUCCESS
    }
    const statusStr =
      parsed?.response?.status ||
      parsed?.status ||
      (typeof parsed === 'string' ? parsed : null) ||
      raw;
    const ok =
      status >= 200 &&
      status < 300 &&
      String(statusStr).toUpperCase().includes('SUCCESS');
    if (!ok) {
      throw new Error(`EbulkSMS ${label} failed: ${String(statusStr).slice(0, 200)}`);
    }
  }

  private async sendViaTwilio(
    channel: MessagingChannel,
    phoneDigits: string,
    message: string,
  ) {
    const cfg = await this.getTwilioConfig();
    if (!cfg?.enabled) {
      throw new Error('Twilio provider is disabled');
    }
    const accountSid = cfg.accountSid || process.env.TWILIO_ACCOUNT_SID;
    const authToken = this.resolveSecret(
      cfg.authTokenEnc,
      process.env.TWILIO_AUTH_TOKEN,
    );
    if (!accountSid || !authToken) {
      throw new Error('Twilio Account SID / Auth Token not configured');
    }

    const toE164 = this.toE164(phoneDigits);
    let from: string;
    let to: string;

    if (channel === 'sms') {
      from = cfg.fromNumber || process.env.TWILIO_FROM_NUMBER || '';
      to = toE164;
      if (!from) throw new Error('Twilio SMS From number not configured');
    } else {
      const waFrom =
        cfg.whatsappFrom ||
        process.env.TWILIO_WHATSAPP_FROM ||
        (cfg.fromNumber ? `whatsapp:${cfg.fromNumber}` : '');
      from = waFrom.startsWith('whatsapp:') ? waFrom : `whatsapp:${waFrom}`;
      to = toE164.startsWith('whatsapp:') ? toE164 : `whatsapp:${toE164}`;
      if (!waFrom) throw new Error('Twilio WhatsApp From number not configured');
    }

    const url = `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Messages.json`;
    const body = new URLSearchParams({ To: to, From: from, Body: message });
    const auth = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });
    const json: any = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(
        json?.message || json?.error_message || `Twilio ${channel} failed (${res.status})`,
      );
    }
  }

  private resolveSecret(encOrPlain?: string, envFallback?: string | null): string | null {
    if (!encOrPlain && !envFallback) return null;
    if (!encOrPlain) return envFallback || null;
    const encKey = process.env.CONFIG_ENCRYPTION_KEY;
    if (encKey && encKey.length === 64 && encOrPlain.includes(':')) {
      try {
        return decryptSecret(encOrPlain, encKey);
      } catch {
        this.logger.warn('Failed to decrypt messaging secret; trying raw value');
      }
    }
    return encOrPlain;
  }

  private asProvider(value: unknown): MessagingProviderId | null {
    if (value === 'ebulksms' || value === 'twilio') return value;
    return null;
  }

  private async getSettingJson(key: string): Promise<any | null> {
    const setting = await this.prisma.appSetting.findUnique({ where: { key } });
    if (!setting?.value) return null;
    try {
      return JSON.parse(setting.value);
    } catch {
      return null;
    }
  }
}
