import { PrismaService } from '../src/common/prisma.service';
import { EmailService } from '../src/common/email.service';
import { EmailEventName } from '../src/email/email-events';

async function main() {
  const prisma = new PrismaService();
  await prisma.$connect();
  const email = new EmailService(prisma);

  const recipientEmail = 'info@ideliver.ng';
  const appName = process.env.APP_NAME || 'bYbata';
  const supportEmail = process.env.SUPPORT_EMAIL || 'support@bybata.com';
  const loginUrl = process.env.APP_PUBLIC_URL || 'http://localhost:3001';

  const active = await prisma.appSetting.findUnique({ where: { key: 'EMAIL_PROVIDER_ACTIVE' } });
  if (active?.value !== 'resend') {
    await prisma.appSetting.upsert({
      where: { key: 'EMAIL_PROVIDER_ACTIVE' },
      update: { value: 'resend' },
      create: { key: 'EMAIL_PROVIDER_ACTIVE', value: 'resend' },
    });
  }

  await email.dispatch({
    eventName: EmailEventName.AuthSignupWelcome,
    recipient: { email: recipientEmail },
    vars: {
      firstName: 'there',
      displayName: 'iDeliver Team',
      appName,
      supportEmail,
      loginUrl,
    },
  });

  await prisma.$disconnect();
}

main().catch((error) => {
  console.error('Failed to send welcome email:', error);
  process.exit(1);
});
