import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  SupportChatSessionStatus,
  SupportTicketPriority,
  SupportTicketStatus,
  SupportTicketType,
} from '@prisma/client';
import { PrismaService } from '../common/prisma.service';

const BOT_NAME = 'BYBATA Assistant';
const ADMIN_ESCALATION_PHRASES = [
  'talk to human',
  'talk to admin',
  'speak to admin',
  'real person',
  'human agent',
  'live agent',
  'admin help',
  'need admin',
];

@Injectable()
export class SupportService {
  constructor(private prisma: PrismaService) {}

  listFaqs() {
    return { items: this.getStaticFaqs() };
  }

  async listTickets(userId: string, type?: SupportTicketType) {
    const where: any = { userId };
    if (type) where.type = type;
    const items = await this.prisma.supportTicket.findMany({
      where,
      orderBy: { updatedAt: 'desc' },
      include: {
        messages: { orderBy: { createdAt: 'asc' }, take: 1 },
      },
    });
    return { items: items.map((t) => this.serializeTicket(t)) };
  }

  async getTicket(userId: string, ticketId: string) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
      include: {
        messages: { orderBy: { createdAt: 'asc' } },
        user: { include: { profile: true } },
      },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.userId !== userId) throw new ForbiddenException('Not your ticket');
    return this.serializeTicket(ticket, true);
  }

  async createTicket(
    userId: string,
    body: {
      subject: string;
      description: string;
      category: string;
      type?: SupportTicketType;
      priority?: SupportTicketPriority;
      metadata?: Record<string, unknown>;
    },
  ) {
    const subject = body.subject?.trim();
    const description = body.description?.trim();
    const category = body.category?.trim();
    if (!subject || !description || !category) {
      throw new BadRequestException('subject, description, and category are required');
    }

    const ticket = await this.prisma.supportTicket.create({
      data: {
        userId,
        subject,
        description,
        category,
        type: body.type ?? SupportTicketType.SUPPORT,
        priority: body.priority ?? SupportTicketPriority.MEDIUM,
        metadata: body.metadata
          ? (JSON.parse(JSON.stringify(body.metadata)) as Prisma.InputJsonValue)
          : undefined,
        messages: {
          create: {
            senderId: userId,
            content: description,
            isFromUser: true,
            senderName: 'You',
          },
        },
      },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });

    return this.serializeTicket(ticket, true);
  }

  async addTicketMessage(userId: string, ticketId: string, content: string) {
    const text = content?.trim();
    if (!text) throw new BadRequestException('Message content is required');
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id: ticketId } });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.userId !== userId) throw new ForbiddenException('Not your ticket');

    const message = await this.prisma.$transaction(async (tx) => {
      const msg = await tx.supportTicketMessage.create({
        data: {
          ticketId,
          senderId: userId,
          content: text,
          isFromUser: true,
          senderName: 'You',
        },
      });
      await tx.supportTicket.update({
        where: { id: ticketId },
        data: {
          updatedAt: new Date(),
          status:
            ticket.status === SupportTicketStatus.RESOLVED ||
            ticket.status === SupportTicketStatus.CLOSED
              ? SupportTicketStatus.OPEN
              : ticket.status,
        },
      });
      return msg;
    });

    return { message: this.serializeTicketMessage(message) };
  }

  async getOrCreateChatSession(userId: string) {
    let session = await this.prisma.supportChatSession.findFirst({
      where: {
        userId,
        status: { not: SupportChatSessionStatus.CLOSED },
      },
      orderBy: { updatedAt: 'desc' },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });

    if (!session) {
      session = await this.prisma.supportChatSession.create({
        data: {
          userId,
          messages: {
            create: {
              content:
                'Hi! I\'m the BYBATA assistant. I can help with trades, gifts, donations, wallet, and account questions. Type your question, or say "talk to admin" when you need a human.',
              isFromUser: false,
              isBot: true,
              senderName: BOT_NAME,
            },
          },
        },
        include: { messages: { orderBy: { createdAt: 'asc' } } },
      });
    }

    return this.serializeChatSession(session);
  }

  async sendChatMessage(userId: string, content: string) {
    const text = content?.trim();
    if (!text) throw new BadRequestException('Message content is required');

    const session = await this.prisma.supportChatSession.findFirst({
      where: {
        userId,
        status: { not: SupportChatSessionStatus.CLOSED },
      },
      orderBy: { updatedAt: 'desc' },
    });
    if (!session) throw new NotFoundException('No active chat session');

    const userMessage = await this.prisma.supportChatMessage.create({
      data: {
        sessionId: session.id,
        senderId: userId,
        content: text,
        isFromUser: true,
        senderName: 'You',
      },
    });

    await this.prisma.supportChatSession.update({
      where: { id: session.id },
      data: { updatedAt: new Date() },
    });

    const wantsAdmin = this.userWantsAdmin(text);
    let botReply: Awaited<ReturnType<typeof this.prisma.supportChatMessage.create>> | null = null;

    if (session.status === SupportChatSessionStatus.BOT) {
      if (wantsAdmin) {
        await this.prisma.supportChatSession.update({
          where: { id: session.id },
          data: { status: SupportChatSessionStatus.AWAITING_ADMIN },
        });
        botReply = await this.prisma.supportChatMessage.create({
          data: {
            sessionId: session.id,
            content:
              'Got it — I\'ve notified our support team. A human agent will join this chat shortly. You can keep describing your issue here.',
            isFromUser: false,
            isBot: true,
            senderName: BOT_NAME,
          },
        });
      } else {
        botReply = await this.prisma.supportChatMessage.create({
          data: {
            sessionId: session.id,
            content: this.generateBotReply(text),
            isFromUser: false,
            isBot: true,
            senderName: BOT_NAME,
          },
        });
      }
    } else if (session.status === SupportChatSessionStatus.AWAITING_ADMIN && wantsAdmin) {
      botReply = await this.prisma.supportChatMessage.create({
        data: {
          sessionId: session.id,
          content: 'Your request is in the queue. An admin will respond here as soon as possible.',
          isFromUser: false,
          isBot: true,
          senderName: BOT_NAME,
        },
      });
    }

    const refreshed = await this.prisma.supportChatSession.findUnique({
      where: { id: session.id },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });

    return {
      userMessage: this.serializeChatMessage(userMessage),
      botMessage: botReply ? this.serializeChatMessage(botReply) : null,
      session: this.serializeChatSession(refreshed!),
    };
  }

  async requestAdminChat(userId: string) {
    const session = await this.prisma.supportChatSession.findFirst({
      where: {
        userId,
        status: { not: SupportChatSessionStatus.CLOSED },
      },
      orderBy: { updatedAt: 'desc' },
    });
    if (!session) throw new NotFoundException('No active chat session');

    if (
      session.status === SupportChatSessionStatus.AWAITING_ADMIN ||
      session.status === SupportChatSessionStatus.ADMIN_ACTIVE
    ) {
      return this.getOrCreateChatSession(userId);
    }

    await this.prisma.supportChatSession.update({
      where: { id: session.id },
      data: { status: SupportChatSessionStatus.AWAITING_ADMIN },
    });

    await this.prisma.supportChatMessage.create({
      data: {
        sessionId: session.id,
        content: 'Connecting you with a support agent. Please hold — someone from our team will reply here.',
        isFromUser: false,
        isBot: true,
        senderName: BOT_NAME,
      },
    });

    return this.getOrCreateChatSession(userId);
  }

  // ── Admin ─────────────────────────────────────────────────────────────

  async adminListTickets(query: {
    status?: SupportTicketStatus;
    type?: SupportTicketType;
    page?: number;
    size?: number;
  }) {
    const page = Math.max(query.page ?? 1, 1);
    const size = Math.min(Math.max(query.size ?? 20, 1), 100);
    const where: any = {};
    if (query.status) where.status = query.status;
    if (query.type) where.type = query.type;

    const [total, items] = await Promise.all([
      this.prisma.supportTicket.count({ where }),
      this.prisma.supportTicket.findMany({
        where,
        include: {
          user: { include: { profile: true } },
          assignedAdmin: { include: { profile: true } },
        },
        orderBy: { updatedAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);

    return {
      items: items.map((t) => this.serializeTicket(t)),
      page,
      size,
      total,
    };
  }

  async adminGetTicket(id: string) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id },
      include: {
        messages: { orderBy: { createdAt: 'asc' } },
        user: { include: { profile: true } },
        assignedAdmin: { include: { profile: true } },
      },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    return this.serializeTicket(ticket, true);
  }

  async adminUpdateTicket(
    adminId: string,
    id: string,
    body: {
      status?: SupportTicketStatus;
      priority?: SupportTicketPriority;
      assignedAdminId?: string | null;
      reply?: string;
    },
  ) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Ticket not found');

    const updated = await this.prisma.$transaction(async (tx) => {
      const data: any = { updatedAt: new Date() };
      if (body.status) data.status = body.status;
      if (body.priority) data.priority = body.priority;
      if (body.assignedAdminId !== undefined) {
        data.assignedAdminId = body.assignedAdminId;
      } else if (body.reply) {
        data.assignedAdminId = adminId;
        if (!body.status) data.status = SupportTicketStatus.IN_PROGRESS;
      }

      const row = await tx.supportTicket.update({ where: { id }, data });

      if (body.reply?.trim()) {
        await tx.supportTicketMessage.create({
          data: {
            ticketId: id,
            senderId: adminId,
            content: body.reply.trim(),
            isFromUser: false,
            senderName: 'Support Team',
          },
        });
      }

      return row;
    });

    return this.adminGetTicket(updated.id);
  }

  async adminListChatSessions(status?: SupportChatSessionStatus) {
    const where: any = {};
    if (status) where.status = status;
    else {
      where.status = {
        in: [SupportChatSessionStatus.AWAITING_ADMIN, SupportChatSessionStatus.ADMIN_ACTIVE],
      };
    }

    const items = await this.prisma.supportChatSession.findMany({
      where,
      include: {
        user: { include: { profile: true } },
        assignedAdmin: { include: { profile: true } },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return { items: items.map((s) => this.serializeChatSession(s)) };
  }

  async adminGetChatSession(id: string) {
    const session = await this.prisma.supportChatSession.findUnique({
      where: { id },
      include: {
        user: { include: { profile: true } },
        assignedAdmin: { include: { profile: true } },
        messages: { orderBy: { createdAt: 'asc' } },
      },
    });
    if (!session) throw new NotFoundException('Chat session not found');
    return this.serializeChatSession(session);
  }

  async adminClaimChat(adminId: string, id: string) {
    const session = await this.prisma.supportChatSession.findUnique({ where: { id } });
    if (!session) throw new NotFoundException('Chat session not found');

    await this.prisma.supportChatSession.update({
      where: { id },
      data: {
        status: SupportChatSessionStatus.ADMIN_ACTIVE,
        assignedAdminId: adminId,
        updatedAt: new Date(),
      },
    });

    await this.prisma.supportChatMessage.create({
      data: {
        sessionId: id,
        senderId: adminId,
        content: 'Hi! A support agent is now here to help you.',
        isFromUser: false,
        isBot: false,
        senderName: 'Support Team',
      },
    });

    return this.adminGetChatSession(id);
  }

  async adminSendChatMessage(adminId: string, sessionId: string, content: string) {
    const text = content?.trim();
    if (!text) throw new BadRequestException('Message content is required');
    const session = await this.prisma.supportChatSession.findUnique({ where: { id: sessionId } });
    if (!session) throw new NotFoundException('Chat session not found');

    await this.prisma.supportChatMessage.create({
      data: {
        sessionId,
        senderId: adminId,
        content: text,
        isFromUser: false,
        isBot: false,
        senderName: 'Support Team',
      },
    });

    await this.prisma.supportChatSession.update({
      where: { id: sessionId },
      data: {
        status: SupportChatSessionStatus.ADMIN_ACTIVE,
        assignedAdminId: session.assignedAdminId ?? adminId,
        updatedAt: new Date(),
      },
    });

    return this.adminGetChatSession(sessionId);
  }

  async adminCloseChat(sessionId: string) {
    await this.prisma.supportChatSession.update({
      where: { id: sessionId },
      data: { status: SupportChatSessionStatus.CLOSED, updatedAt: new Date() },
    });
    return { ok: true };
  }

  private userWantsAdmin(text: string) {
    const lower = text.toLowerCase();
    return ADMIN_ESCALATION_PHRASES.some((p) => lower.includes(p));
  }

  private generateBotReply(text: string) {
    const lower = text.toLowerCase();
    if (lower.includes('trade') || lower.includes('barter')) {
      return 'For trades: open Trade Center, browse listings, or create a trade from the + menu. Need a person? Say "talk to admin".';
    }
    if (lower.includes('gift')) {
      return 'Gifts are free items you offer to the community. Go to Gift Hub → Create Gift. Say "talk to admin" for account-specific help.';
    }
    if (lower.includes('donat') || lower.includes('campaign')) {
      return 'Browse campaigns in Donations, or create one from your profile. Wallet BYC can fund boosts. Say "talk to admin" for payment issues.';
    }
    if (lower.includes('wallet') || lower.includes('byc') || lower.includes('pay')) {
      return 'Open Wallet to fund, transfer BYC, or view history. If a payment failed, say "talk to admin" with your reference number.';
    }
    if (lower.includes('verify') || lower.includes('account')) {
      return 'Verification is under Profile → Verification. It usually takes 24–48 hours. Say "talk to admin" if it\'s been longer.';
    }
    if (lower.includes('password') || lower.includes('login')) {
      return 'Use Forgot Password on the login screen, or check Settings → Security. Say "talk to admin" if you\'re locked out.';
    }
    return 'Thanks for your message! I\'m an automated assistant. For account-specific help, type "talk to admin" and a team member will join this chat.';
  }

  private serializeTicket(ticket: any, includeMessages = false) {
    return {
      id: ticket.id,
      userId: ticket.userId,
      type: ticket.type,
      subject: ticket.subject,
      description: ticket.description,
      category: ticket.category,
      status: ticket.status,
      priority: ticket.priority,
      assignedAdminId: ticket.assignedAdminId,
      assignedAgent: ticket.assignedAdmin?.profile?.displayName ?? ticket.assignedAdmin?.email ?? null,
      metadata: ticket.metadata ?? {},
      createdAt: ticket.createdAt,
      lastUpdated: ticket.updatedAt,
      updatedAt: ticket.updatedAt,
      user: ticket.user
        ? {
            id: ticket.user.id,
            email: ticket.user.email,
            displayName: ticket.user.profile?.displayName ?? ticket.user.email,
          }
        : undefined,
      messages: includeMessages
        ? (ticket.messages ?? []).map((m: any) => this.serializeTicketMessage(m))
        : undefined,
    };
  }

  private serializeTicketMessage(m: any) {
    return {
      id: m.id,
      content: m.content,
      isFromUser: m.isFromUser,
      timestamp: m.createdAt,
      authorName: m.senderName,
    };
  }

  private serializeChatSession(session: any) {
    return {
      id: session.id,
      userId: session.userId,
      status: session.status,
      assignedAdminId: session.assignedAdminId,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      user: session.user
        ? {
            id: session.user.id,
            email: session.user.email,
            displayName: session.user.profile?.displayName ?? session.user.email,
          }
        : undefined,
      messages: (session.messages ?? []).map((m: any) => this.serializeChatMessage(m)),
    };
  }

  private serializeChatMessage(m: any) {
    return {
      id: m.id,
      content: m.content,
      isFromUser: m.isFromUser,
      isBot: m.isBot,
      timestamp: m.createdAt,
      senderName: m.senderName,
    };
  }

  private getStaticFaqs() {
    return [
      // ── Account ───────────────────────────────────────────────────────
      {
        id: 'acc-1',
        category: 'Account',
        question: 'How do I create a BYBATA account?',
        answer:
          'Tap Sign Up on the welcome screen. You can register with email and password, or use Google or Apple sign-in. Choose your preferred currency during signup — it is used for wallet top-ups and listing prices. New members receive starter KARMA points to begin exploring the community.',
        tags: ['signup', 'registration', 'google', 'apple'],
      },
      {
        id: 'acc-2',
        category: 'Account',
        question: 'Why do I need to verify my email?',
        answer:
          'Email verification keeps your account secure and unlocks full access to trading, gifting, donations, and wallet features. After signing up, check your inbox for a verification link. If you did not receive it, open the verification screen from the app and request a new email.',
        tags: ['email', 'verification'],
      },
      {
        id: 'acc-3',
        category: 'Account',
        question: 'How do I get verified on BYBATA?',
        answer:
          'Go to Profile → Verification. Upload a clear photo of your government ID and take a selfie for identity matching. Our team typically reviews submissions within 24–48 hours. Verified accounts earn a trust badge, bonus KARMA, and higher credibility when trading or gifting.',
        tags: ['kyc', 'identity', 'badge'],
      },
      {
        id: 'acc-4',
        category: 'Account',
        question: 'I forgot my password — what should I do?',
        answer:
          'On the login screen, tap Forgot Password and enter your registered email. You will receive a reset link. Choose a strong password with at least 8 characters, including upper and lowercase letters and a number. If you are still locked out, contact support at info@bybata.com.',
        tags: ['password', 'login', 'reset'],
      },
      {
        id: 'acc-5',
        category: 'Account',
        question: 'Can I browse BYBATA without signing in?',
        answer:
          'Yes. Guests can browse trades, gifts, and donation campaigns from the home screen. To create listings, make offers, claim gifts, donate, chat, or use your wallet, sign in or create a free account.',
        tags: ['guest', 'browse', 'public'],
      },
      {
        id: 'acc-6',
        category: 'Account',
        question: 'How do referral codes work?',
        answer:
          'When you sign up, you can enter a friend\'s referral code (optional). Referrers earn KARMA when invited friends join and become active on the platform. Find your own invite code in Profile or the Learn & Earn section to share with others.',
        tags: ['referral', 'invite'],
      },

      // ── Trading ───────────────────────────────────────────────────────
      {
        id: 'trade-1',
        category: 'Trading',
        question: 'How does trade-by-barter work on BYBATA?',
        answer:
          'BYBATA is a barter marketplace — you swap items directly with other members, no cash required. List what you have under Trade Center → Create Trade, browse listings, and send an offer on items you want. The owner can accept, reject, or negotiate until you both agree on the exchange.',
        tags: ['barter', 'trade', 'how-to'],
      },
      {
        id: 'trade-2',
        category: 'Trading',
        question: 'How do I make or respond to a trade offer?',
        answer:
          'Open a trade listing and tap to propose your item(s) in return. The listing owner sees all offers under Trade Offers. You can chat and negotiate in the negotiation thread linked to the trade. When an offer is accepted, the trade moves toward completion — coordinate pickup, delivery, or shipping as agreed.',
        tags: ['offer', 'negotiation'],
      },
      {
        id: 'trade-3',
        category: 'Trading',
        question: 'What if the other person does not send their item?',
        answer:
          'Check the member\'s KARMA score, verification badge, and reviews before trading. Meet in safe public places when exchanging in person. If something goes wrong, use in-app chat to resolve it first. Report the user from their profile or open a support ticket — include trade ID and screenshots.',
        tags: ['dispute', 'safety', 'scam'],
      },
      {
        id: 'trade-4',
        category: 'Trading',
        question: 'Can I save a trade as a draft?',
        answer:
          'Yes. When creating a trade you can save it as a draft and publish later when photos and details are ready. Drafts appear in My Trades. Add clear photos, a category, location, and whether you allow pickup, delivery, or shipping so buyers know what to expect.',
        tags: ['draft', 'create', 'listing'],
      },

      // ── Gifts ─────────────────────────────────────────────────────────
      {
        id: 'gift-1',
        category: 'Gifts',
        question: 'How do I give a gift on BYBATA?',
        answer:
          'Go to Gift Hub → Create Gift. Add photos, a title, description, and optional eligibility rules. Publish the gift so others can discover and claim it. Giving freely builds community trust and earns KARMA. You can manage active and past gifts under My Gifts.',
        tags: ['create', 'give'],
      },
      {
        id: 'gift-2',
        category: 'Gifts',
        question: 'How do I claim a gift?',
        answer:
          'Browse gifts in Gift Hub, open one that interests you, and tap Claim. The giver may approve or decline depending on how the gift was set up. Once approved, coordinate collection or delivery through chat. You cannot claim your own gift.',
        tags: ['claim', 'receive'],
      },
      {
        id: 'gift-3',
        category: 'Gifts',
        question: 'What happens when a gift expires?',
        answer:
          'Gifts can have an expiry date set by the creator. After expiry, the listing is no longer available to claim. Check Gift History for past gifts you gave or received. If you need help with a stuck claim, contact support with the gift ID.',
        tags: ['expiry', 'status'],
      },

      // ── Donations ─────────────────────────────────────────────────────
      {
        id: 'don-1',
        category: 'Donations',
        question: 'How do donation campaigns work?',
        answer:
          'Anyone can create a campaign under Donations → Create Campaign with a goal, story, and photos. Supporters contribute BYC from their wallet toward the goal. Campaign owners post updates and manage the campaign from My Campaigns. Completed or paused campaigns show their status on the listing.',
        tags: ['campaign', 'fundraising'],
      },
      {
        id: 'don-2',
        category: 'Donations',
        question: 'How do I donate to a campaign?',
        answer:
          'Open a campaign, tap Donate, and choose an amount in BYC. Your wallet balance is checked before the donation is processed. You can donate anonymously in some flows. View your giving history under Donation History in the Donations hub.',
        tags: ['donate', 'byc'],
      },
      {
        id: 'don-3',
        category: 'Donations',
        question: 'Can I browse campaigns without an account?',
        answer:
          'Yes. Active campaigns are visible to guests on the home and Donations tabs. Sign in is required to donate, follow a campaign, or chat with the organizer.',
        tags: ['guest', 'browse'],
      },

      // ── Wallet ────────────────────────────────────────────────────────
      {
        id: 'wallet-1',
        category: 'Wallet',
        question: 'What is BYC (BYBATA Coin)?',
        answer:
          'BYC is BYBATA\'s in-app community currency. Use it to fund your wallet, send BYC to other members, donate to campaigns, and pay for boosts or promotions. BYC is not cash and cannot be withdrawn as fiat — it powers community features inside the app.',
        tags: ['byc', 'currency'],
      },
      {
        id: 'wallet-2',
        category: 'Wallet',
        question: 'How do I add money to my wallet?',
        answer:
          'Open Wallet → Fund Wallet. Supported gateways include Paystack (NGN and other African currencies), Flutterwave, Stripe, and PayPal depending on your region. After payment succeeds, BYC is credited using the current conversion rate shown before you confirm.',
        tags: ['fund', 'paystack', 'top-up'],
      },
      {
        id: 'wallet-3',
        category: 'Wallet',
        question: 'How do I send BYC to another user?',
        answer:
          'Go to Wallet → Send BYC, enter the recipient (username or scanned details), amount, and optional note. You may need your wallet PIN or biometrics to confirm. Both parties see the transfer in Transaction History. Never share your PIN with anyone.',
        tags: ['transfer', 'send', 'p2p'],
      },
      {
        id: 'wallet-4',
        category: 'Wallet',
        question: 'My payment succeeded but BYC did not arrive — what now?',
        answer:
          'Funding can take a short moment while the payment gateway confirms. Pull to refresh your wallet balance. If it still has not credited after 30 minutes, open Help & Support → Create Ticket with your payment reference, gateway name (Paystack/Stripe/etc.), and amount. Email info@bybata.com for urgent wallet issues.',
        tags: ['payment', 'failed', 'missing'],
      },
      {
        id: 'wallet-5',
        category: 'Wallet',
        question: 'What are boosts and promotions?',
        answer:
          'Boosts increase visibility for your trades, gifts, or campaigns for a set period using BYC from your wallet. Open Promotion Center from Wallet or listing screens to see boost types and pricing. Boosted items may appear higher in browse and search results.',
        tags: ['boost', 'promotion', 'ads'],
      },

      // ── KARMA ─────────────────────────────────────────────────────────
      {
        id: 'karma-1',
        category: 'Karma',
        question: 'What is KARMA and why does it matter?',
        answer:
          'KARMA is your community reputation score. Earn it by trading fairly, gifting, donating, verifying your identity, referring friends, and helping others. Higher KARMA unlocks trust tiers (Bronze → Legend), premium features like priority support, and signals reliability to other members.',
        tags: ['karma', 'reputation', 'trust'],
      },
      {
        id: 'karma-2',
        category: 'Karma',
        question: 'How can I earn more KARMA?',
        answer:
          'Open Learn & Earn from the KARMA hub or side menu. Common ways to earn: complete trades, give gifts, donate to campaigns, verify your ID, enable security settings, invite friends, and participate in communities. Some actions award bonus points once; others reward ongoing activity.',
        tags: ['earn', 'points'],
      },
      {
        id: 'karma-3',
        category: 'Karma',
        question: 'What are KARMA trust tiers?',
        answer:
          'Tiers progress from Newcomer through Bronze, Silver, Gold, Platinum, Diamond, and Legend based on total KARMA points. Higher tiers unlock filters, community creation, bulk trading limits, and priority support. View your current tier and progress under Profile → Trust Level or the KARMA screen.',
        tags: ['tier', 'badge', 'level'],
      },

      // ── Community ─────────────────────────────────────────────────────
      {
        id: 'comm-1',
        category: 'Community',
        question: 'What are BYBATA communities?',
        answer:
          'Communities are groups around shared interests — local swap meets, charity drives, hobby groups, and more. Browse Community Hub to discover groups, read posts, join events, and participate in discussions. Creating a community may require minimum KARMA.',
        tags: ['community', 'groups'],
      },
      {
        id: 'comm-2',
        category: 'Community',
        question: 'How do I join or leave a community?',
        answer:
          'Open a community profile and tap Join. Some communities are open; others require approval from admins. To leave, open the community settings or your membership list and tap Leave. You can still browse public posts from communities you have left.',
        tags: ['join', 'member'],
      },

      // ── Chat ──────────────────────────────────────────────────────────
      {
        id: 'chat-1',
        category: 'Chat',
        question: 'How do I message another member?',
        answer:
          'Tap Message or Chat on a trade, gift, campaign, or user profile to start a conversation. All your chats live under the Chat tab. You can send text, images, and voice notes where supported. Block or report users from chat settings if needed.',
        tags: ['message', 'inbox'],
      },
      {
        id: 'chat-2',
        category: 'Chat',
        question: 'Can I chat about a specific trade or gift?',
        answer:
          'Yes. Trade and gift listings open a dedicated chat thread tied to that item so context is never lost. Negotiation messages for trades also appear in the trade flow. Campaign organizers can chat with supporters from the campaign details screen.',
        tags: ['trade-chat', 'context'],
      },

      // ── Support ───────────────────────────────────────────────────────
      {
        id: 'sup-1',
        category: 'Support',
        question: 'How do I contact BYBATA support?',
        answer:
          'Open Settings → Help & legal → Contact support, or go to the Help & Support screen. Options include Live Chat (with an automated assistant that can connect you to a human), email at info@bybata.com, phone at 08036954577 (Mon–Fri, 9 AM–6 PM WAT), or create a support ticket under the Tickets tab.',
        tags: ['contact', 'help'],
      },
      {
        id: 'sup-2',
        category: 'Support',
        question: 'How do support tickets work?',
        answer:
          'Tap New Ticket, choose a category and priority, and describe your issue. You receive a ticket ID and can track status (Open, In Progress, Resolved) in the Tickets tab. Our team replies in the ticket thread. For bugs, use Report Bug on the Contact tab — those go to the same system flagged for engineering.',
        tags: ['ticket', 'status'],
      },
      {
        id: 'sup-3',
        category: 'Support',
        question: 'When should I use Emergency Support?',
        answer:
          'Use Emergency Support for urgent security issues: account takeover, fraud, harassment, or safety concerns. It creates a high-priority ticket immediately. You can also call 08036954577 during business hours. For general questions, Live Chat or a normal ticket is faster.',
        tags: ['emergency', 'urgent'],
      },

      // ── Security ──────────────────────────────────────────────────────
      {
        id: 'sec-1',
        category: 'Security',
        question: 'How do I protect my wallet?',
        answer:
          'Set a wallet PIN under Settings → Security and enable biometric unlock (Face ID / fingerprint) where available. BYC transfers require PIN or biometrics. Never share your PIN, password, or verification codes. BYBATA staff will never ask for your password.',
        tags: ['wallet-pin', 'biometric'],
      },
      {
        id: 'sec-2',
        category: 'Security',
        question: 'How do I report a user or content?',
        answer:
          'From a user profile, tap Report and choose a reason. For community posts, use the report option on the post. Serious cases can also be escalated via Help & Support → Create Ticket. Blocked users cannot message you or interact with your listings.',
        tags: ['report', 'block', 'abuse'],
      },
      {
        id: 'sec-3',
        category: 'Security',
        question: 'How do I delete my account?',
        answer:
          'Go to Settings → Account → Delete account (or the danger zone in profile settings). You must confirm by typing DELETE. This permanently removes your profile, listings, and messages. Wallet balance and KARMA cannot be recovered after deletion. Contact info@bybata.com if you need help before deleting.',
        tags: ['delete', 'gdpr', 'privacy'],
      },

      // ── Technical ─────────────────────────────────────────────────────
      {
        id: 'tech-1',
        category: 'Technical',
        question: 'The app is slow or crashing — what should I try?',
        answer:
          'First, fully close and reopen the app. Ensure you are on the latest version from the App Store or Play Store. Check your internet connection. Clear cache by logging out and back in. If the problem persists, use Report Bug in Help & Support and describe what you were doing when it happened.',
        tags: ['crash', 'bug', 'performance'],
      },
      {
        id: 'tech-2',
        category: 'Technical',
        question: 'Why am I not receiving push notifications?',
        answer:
          'Enable notifications for BYBATA in your phone Settings. Inside the app, open Settings → Notifications and turn on the categories you want (trades, gifts, chat, wallet). On Android 13+, grant the notification permission when prompted. Logged-out devices stop receiving personal alerts.',
        tags: ['notifications', 'push'],
      },
      {
        id: 'tech-3',
        category: 'Technical',
        question: 'My photos will not upload — how do I fix it?',
        answer:
          'Allow camera and photo library access when the app asks. Use JPG or PNG under 10 MB where possible. On iOS, check Settings → BYBATA → Photos. If uploads fail repeatedly, try Wi-Fi instead of mobile data and report the issue with your device model via Report Bug.',
        tags: ['upload', 'photos', 'permissions'],
      },
    ];
  }
}
