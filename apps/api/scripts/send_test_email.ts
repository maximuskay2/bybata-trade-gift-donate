import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { EmailService } from '../src/common/email.service';

async function bootstrap() {
  // Create a lightweight application context (no HTTP server) so we can
  // resolve EmailService and use the existing provider configuration.
  const appContext = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  try {
    const emailService = appContext.get(EmailService);

    const to = 'info@ideliver.ng';
    const subject = 'bYbata – Test confirmation email';
    const html = `
      <p>Hello from <strong>bYbata</strong>,</p>
      <p>This is a test confirmation email from the development environment to verify that your new master email template and provider configuration are working correctly.</p>
      <p>If you received this, email delivery and templates are wired correctly.</p>
      <p style="margin-top:24px;font-size:12px;color:#8898aa;">Env: <code>${process.env.NODE_ENV || 'development'}</code></p>
    `;

    await emailService.send(to, subject, html);
    // eslint-disable-next-line no-console
    console.log(`Test email dispatched to ${to}`);
  } finally {
    await appContext.close();
  }
}

bootstrap().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to send test email', err);
  process.exit(1);
});
