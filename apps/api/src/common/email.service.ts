import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import { PrismaService } from './prisma.service';
import { EmailEventName } from '../email/email-events';
import { EMAIL_TEMPLATE_REGISTRY } from '../email/email-template-registry';
import { EmailDispatchInput, EmailTemplateVariables } from '../email/email.types';
import { renderEmailHtml } from '../email/email-template.util';
import { decryptSecret } from './crypto.util';
import { join } from 'path';
import { readFile } from 'fs/promises';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  constructor(private prisma: PrismaService) {}

  private readonly providerEnv = process.env.EMAIL_PROVIDER || 'console';
  private readonly resendApiKeyEnv = process.env.RESEND_API_KEY;
  private readonly sendGridApiKeyEnv = process.env.SENDGRID_API_KEY;
  private readonly fromEnv = process.env.EMAIL_FROM || 'no-reply@bybata.local';
  private readonly queue = new InMemoryEmailQueue();

  private async getSetting(key: string) {
    return this.prisma.appSetting.findUnique({ where: { key } });
  }

  private async getActiveProvider(): Promise<EmailProvider> {
    const setting = await this.getSetting('EMAIL_PROVIDER_ACTIVE');
    return (setting?.value as EmailProvider) || (this.providerEnv as EmailProvider);
  }

  private async getProviderConfig() {
    const encKey = process.env.CONFIG_ENCRYPTION_KEY;
    const readConfig = async (key: string) => {
      const setting = await this.getSetting(key);
      if (!setting?.value) return null;
      try {
        return JSON.parse(setting.value) as Record<string, any>;
      } catch {
        return null;
      }
    };
    const resend = await readConfig('EMAIL_PROVIDER_RESEND');
    const smtp = await readConfig('EMAIL_PROVIDER_SMTP');
    const sendgrid = await readConfig('EMAIL_PROVIDER_SENDGRID');

    const decryptIfNeeded = (value?: string) => {
      if (!value) return undefined;
      if (!encKey) return value;
      try {
        return decryptSecret(value, encKey);
      } catch {
        return value;
      }
    };

    return {
      resend: {
        apiKey: decryptIfNeeded(resend?.apiKeyEnc) || this.resendApiKeyEnv,
        from: resend?.from || this.fromEnv,
        useTemplateApi: Boolean(resend?.useTemplateApi),
        templateMap: resend?.templateMap || {},
      },
      smtp: {
        host: smtp?.host || process.env.SMTP_HOST,
        port: Number(smtp?.port || process.env.SMTP_PORT || 465),
        secure: String(smtp?.secure ?? process.env.SMTP_SECURE ?? 'true') === 'true',
        user: smtp?.user || process.env.SMTP_USER,
        pass: decryptIfNeeded(smtp?.passEnc) || process.env.SMTP_PASS,
        from: smtp?.from || this.fromEnv,
      },
      sendgrid: {
        apiKey: decryptIfNeeded(sendgrid?.apiKeyEnc) || this.sendGridApiKeyEnv,
        from: sendgrid?.from || this.fromEnv,
        templateMap: sendgrid?.templateMap || {},
      },
    };
  }

  private smtpTransport(smtp: { host?: string; port: number; secure: boolean; user?: string; pass?: string }) {
    const { host, port, secure, user, pass } = smtp;
    if (!host || !user || !pass) return null;
    return nodemailer.createTransport({ host, port, secure, auth: { user, pass } });
  }

  async dispatch(input: EmailDispatchInput) {
    const template = EMAIL_TEMPLATE_REGISTRY[input.eventName];

    // Always inject common template variables that many designs rely on.
    // These do not need to be listed in requiredVars but will be available
    // in every HTML template.
    const mergedVars: EmailTemplateVariables = {
      ...input.vars,
      current_year: new Date().getFullYear(),
    };

    this.assertRequiredVars(input.eventName, mergedVars, template.requiredVars);

    const provider = await this.getActiveProvider();
    const configs = await this.getProviderConfig();
    const subject = input.subject ?? this.defaultSubject(input.eventName);
    const category = input.category ?? 'transactional';

    if (!(await this.shouldSend(input.recipient.userId, category))) {
      await this.createLog({
        eventName: input.eventName,
        recipientEmail: input.recipient.email,
        recipientUserId: input.recipient.userId,
        category,
        templateId: template.templateId,
        provider,
        status: 'SKIPPED',
        error: 'Preference opt-out',
      });
      return { ok: true, provider, skipped: true };
    }

    // Render just the event-specific HTML template. Each template is now
    // responsible for its own layout / styling, so we no longer inject a
    // global wrapper like emailler.html.
    const html = await this.renderTemplate(template.templateId, mergedVars);
    const log = await this.createLog({
      eventName: input.eventName,
      recipientEmail: input.recipient.email,
      recipientUserId: input.recipient.userId,
      category,
      templateId: template.templateId,
      provider,
      status: 'QUEUED',
      metadata: {
        ...(input.metadata || {}),
        // store a preview of the rendered HTML so admins can inspect the exact body that was sent
        htmlPreview: html,
      },
    });

    try {
      const result = await this.queue.enqueue(async () => {
        if (provider === 'smtp') {
          const transporter = this.smtpTransport(configs.smtp);
          if (transporter) {
            await transporter.sendMail({
              from: configs.smtp.from,
              to: input.recipient.email,
              subject,
              html,
            });
            return { ok: true, provider };
          }
        }

        if (provider === 'resend' && configs.resend.apiKey) {
          // Always send our rendered HTML directly so that the redesigned
          // templates in apps/api/src/email/templates are used. We
          // intentionally ignore any remote/template API mapping here.
          const payload: any = {
            from: configs.resend.from,
            to: input.recipient.email,
            subject,
            html,
          };
          await this.resendFetchWithRetry(configs.resend.apiKey, payload);
          return { ok: true, provider };
        }

        if (provider === 'sendgrid' && configs.sendgrid.apiKey) {
          // Same for SendGrid: send the rendered HTML directly instead of
          // relying on a remote template_id mapping.
          const payload: any = {
            personalizations: [
              {
                to: [{ email: input.recipient.email }],
              },
            ],
            from: { email: configs.sendgrid.from },
            subject,
            content: [{ type: 'text/html', value: html }],
          };
          const resp = await fetch('https://api.sendgrid.com/v3/mail/send', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${configs.sendgrid.apiKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload),
          });
          if (!resp.ok) throw new Error(`SendGrid error ${resp.status}`);
          return { ok: true, provider };
        }

        this.logger.log(`[Email console] ${input.recipient.email}: ${subject}\n${html}`);
        return { ok: true, provider: 'console' };
      });
      await this.markLogSent(log.id);
      return result;
    } catch (error: any) {
      await this.markLogFailed(log.id, error?.message ?? 'Email send failed');
      throw error;
    }
  }

  /**
   * Queue email delivery without blocking HTTP handlers.
   * Prefer this for user-facing mutations (profile, trades, gifts, donations).
   */
  dispatchInBackground(input: EmailDispatchInput): void {
    void this.dispatch(input).catch((error) => {
      this.logger.warn(
        `Background email failed [${input.eventName} → ${input.recipient.email}]: ${
          error instanceof Error ? error.message : error
        }`,
      );
    });
  }

  async send(to: string, subject: string, html: string, text?: string) {
    await this.sendRaw({
      to,
      subject,
      html,
      text,
    });
  }

  private async sendRaw(input: {
    to: string;
    subject: string;
    html: string;
    text?: string;
  }) {
    try {
      const provider = await this.getActiveProvider();
      const configs = await this.getProviderConfig();

      if (provider === 'smtp') {
        const transporter = this.smtpTransport(configs.smtp);
        if (transporter) {
          await transporter.sendMail({
            from: configs.smtp.from,
            to: input.to,
            subject: input.subject,
            html: input.html,
            text: input.text,
          });
          return;
        }
      }

      if (provider === 'resend' && configs.resend.apiKey) {
        const payload = {
          from: configs.resend.from,
          to: input.to,
          subject: input.subject,
          html: input.html,
          text: input.text,
        };
        await this.resendFetchWithRetry(configs.resend.apiKey, payload);
        return;
      }

      if (provider === 'sendgrid' && configs.sendgrid.apiKey) {
        const resp = await fetch('https://api.sendgrid.com/v3/mail/send', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${configs.sendgrid.apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            personalizations: [
              {
                to: [{ email: input.to }],
              },
            ],
            from: { email: configs.sendgrid.from },
            subject: input.subject,
            content: [{ type: 'text/html', value: input.html }],
          }),
        });
        if (!resp.ok) throw new Error(`SendGrid error ${resp.status}`);
        return;
      }

      this.logger.log(`[Email console] ${input.to}: ${input.subject}\n${input.text ?? input.html}`);
    } catch (e) {
      this.logger.warn(`Email send failed: ${e}`);
    }
  }

  /**
   * Resend API call with retry on 429 (rate limit) and 5xx.
   * Uses Retry-After header when present, otherwise exponential backoff.
   */
  private async resendFetchWithRetry(apiKey: string, payload: Record<string, unknown>, attempt = 1): Promise<void> {
    const maxAttempts = 4;
    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (resp.ok) return;

    if (attempt >= maxAttempts) {
      throw new Error(`Resend error ${resp.status}`);
    }

    const is429 = resp.status === 429;
    const is5xx = resp.status >= 500 && resp.status < 600;

    if (is429 || is5xx) {
      let delayMs = 60_000; // default 60s for 429
      const retryAfter = resp.headers.get('retry-after');
      if (retryAfter) {
        const parsed = parseInt(retryAfter, 10);
        delayMs = Number.isFinite(parsed) ? parsed * 1000 : 60_000;
      } else if (is5xx) {
        delayMs = Math.min(1000 * Math.pow(2, attempt), 60_000); // exponential backoff, cap 60s
      }

      this.logger.warn(
        `Resend ${resp.status} (attempt ${attempt}/${maxAttempts}), retrying in ${delayMs}ms`,
      );
      await new Promise((r) => setTimeout(r, delayMs));
      return this.resendFetchWithRetry(apiKey, payload, attempt + 1);
    }

    throw new Error(`Resend error ${resp.status}`);
  }

  private assertRequiredVars(
    eventName: EmailEventName,
    vars: EmailTemplateVariables,
    requiredVars: string[],
  ) {
    const missing = requiredVars.filter(
      (key) => vars[key] === undefined || vars[key] === null,
    );
    if (missing.length > 0) {
      throw new Error(`Missing vars for ${eventName}: ${missing.join(', ')}`);
    }
  }

  private defaultSubject(eventName: EmailEventName) {
    return `bYbata: ${eventName.replace(/\./g, ' ')}`;
  }

  private async renderTemplate(templateId: string, vars: EmailTemplateVariables) {
    // In development, the process cwd is the monorepo root
    //   /.../bybataRailway
    // and templates live under apps/api/src/email/templates.
    // In production on Railway, the app is built into /app and the
    // sources are at /app/src/email/templates (no apps/api prefix).
    // To support both, we try both base paths.
    const candidates = [
      join(process.cwd(), 'apps', 'api', 'src', 'email', 'templates'),
      join(process.cwd(), 'src', 'email', 'templates'),
    ];

    for (const basePath of candidates) {
      const templatePath = join(basePath, `${templateId}.html`);
      try {
        const raw = await readFile(templatePath, 'utf8');
        return renderEmailHtml(raw, vars);
      } catch {
        // Try next candidate path
      }
    }

    // Absolute fallback: return the vars as pretty-printed JSON so we
    // never completely fail to send an email, but it will be obvious in
    // the inbox that something is misconfigured.
    return `<pre>${JSON.stringify(vars, null, 2)}</pre>`;
  }

// NOTE: Templates are rendered directly by renderTemplate(). If you
  // later decide to reintroduce a global wrapper, add a helper similar to
  // renderWrappedTemplate here and call it from dispatch().

  private async shouldSend(userId: string | undefined, category: string) {
    if (!userId) return true;
    if (category !== 'marketing' && category !== 'digest') return true;
    const pref = await (this.prisma as any).emailPreference.findUnique({ where: { userId } });
    if (!pref) return true;
    if (category === 'marketing') return pref.marketing;
    return pref.digest;
  }

  private async createLog(input: {
    eventName: EmailEventName;
    recipientEmail: string;
    recipientUserId?: string;
    category?: string;
    templateId?: string;
    provider?: string;
    status: string;
    error?: string;
    metadata?: Record<string, string | number | boolean | null>;
  }) {
    return (this.prisma as any).emailLog.create({
      data: {
        eventName: input.eventName,
        recipientEmail: input.recipientEmail,
        recipientUserId: input.recipientUserId,
        category: input.category,
        templateId: input.templateId,
        provider: input.provider,
        status: input.status,
        error: input.error,
        metadata: input.metadata,
      },
    });
  }

  private async markLogSent(id: string) {
    await (this.prisma as any).emailLog.update({
      where: { id },
      data: { status: 'SENT', sentAt: new Date() },
    });
  }

  private async markLogFailed(id: string, error: string) {
    await (this.prisma as any).emailLog.update({
      where: { id },
      data: { status: 'FAILED', error },
    });
  }
}

type EmailProvider = 'resend' | 'smtp' | 'sendgrid' | 'console';

/**
 * Serial email queue with configurable delay between sends to avoid Resend 429.
 * EMAIL_THROTTLE_DELAY_MS (default 500) = ms to wait between each send.
 */
class InMemoryEmailQueue {
  private readonly delayMs =
    Math.max(0, parseInt(process.env.EMAIL_THROTTLE_DELAY_MS ?? '500', 10)) || 500;
  private lastSentAt = 0;
  private readonly pending: Array<() => Promise<unknown>> = [];
  private processing = false;

  async enqueue<T>(handler: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      this.pending.push(async () => {
        try {
          const result = await handler();
          resolve(result);
          return result;
        } catch (e) {
          reject(e);
          throw e;
        }
      });
      this.process();
    });
  }

  private async process() {
    if (this.processing || this.pending.length === 0) return;
    this.processing = true;
    try {
      const elapsed = Date.now() - this.lastSentAt;
      if (elapsed < this.delayMs) {
        await new Promise((r) => setTimeout(r, this.delayMs - elapsed));
      }
      const next = this.pending.shift();
      if (!next) return;
      this.lastSentAt = Date.now();
      await next();
    } finally {
      this.processing = false;
      if (this.pending.length > 0) {
        setImmediate(() => this.process());
      }
    }
  }
}
