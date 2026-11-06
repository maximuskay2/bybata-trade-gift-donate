import { Test, TestingModule } from '@nestjs/testing';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../common/prisma.service';
import { WalletService } from '../wallet/wallet.service';
import { EmailService } from '../common/email.service';

describe('PaymentsService', () => {
  let service: PaymentsService;

  const fundingIntent = {
    findFirst: jest.fn(),
    update: jest.fn(),
    create: jest.fn(),
    updateMany: jest.fn(),
  };
  const webhookEvent = {
    upsert: jest.fn(),
    update: jest.fn(),
    findMany: jest.fn(),
  };

  const mockPrisma: any = {
    conversionRate: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    walletTransaction: {
      findUnique: jest.fn(),
      findFirst: jest.fn(),
    },
    fundingIntent,
    webhookEvent,
    user: { findUnique: jest.fn() },
    account: { findUnique: jest.fn() },
    paymentGatewayConfig: { findFirst: jest.fn() },
  };

  const mockWallet = {
    fund: jest.fn(),
    credit: jest.fn(),
  };

  const mockEmail = {
    dispatchInBackground: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: WalletService, useValue: mockWallet },
        { provide: EmailService, useValue: mockEmail },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
    jest.clearAllMocks();
  });

  describe('handleProviderFundingEvent (webhook E2E / idempotency)', () => {
    const intent = {
      id: 'fi_db_1',
      userId: 'user_1',
      provider: 'paystack',
      currency: 'NGN',
      amountMinor: 500000,
      status: 'PENDING',
      intentReference: 'fi_test_ref',
      providerReference: null,
      initPayload: { amountByc: 50 },
    };

    const paystackBody = {
      event: 'charge.success',
      data: {
        reference: 'psk_txn_1',
        amount: 500000,
        currency: 'NGN',
        status: 'success',
        metadata: { intentReference: 'fi_test_ref', userId: 'user_1' },
      },
    };

    it('credits wallet once for a verified Paystack webhook', async () => {
      fundingIntent.findFirst.mockResolvedValue(intent);
      fundingIntent.update.mockResolvedValue({
        ...intent,
        status: 'SUCCEEDED',
        providerReference: 'psk_txn_1',
      });
      mockPrisma.walletTransaction.findFirst.mockResolvedValue(null);
      mockWallet.fund.mockResolvedValue({ id: 'txn_1' });
      mockPrisma.user.findUnique.mockResolvedValue({
        email: 'a@b.com',
        profile: { displayName: 'A' },
      });
      mockPrisma.account.findUnique.mockResolvedValue({ balance: 50 });

      const first = await service.handleProviderFundingEvent(
        'paystack',
        paystackBody,
        true,
      );

      expect(first.ok).toBe(true);
      expect(mockWallet.fund).toHaveBeenCalledTimes(1);
      expect(mockWallet.fund).toHaveBeenCalledWith(
        'user_1',
        50,
        expect.stringContaining('PAYSTACK'),
        'fund:fi_test_ref',
      );
    });

    it('skips duplicate credit when funding intent already credited', async () => {
      fundingIntent.findFirst.mockResolvedValue(intent);
      fundingIntent.update.mockResolvedValue({
        ...intent,
        status: 'SUCCEEDED',
        providerReference: 'psk_txn_1',
      });
      mockPrisma.walletTransaction.findFirst.mockResolvedValue({
        id: 'txn_existing',
        idempotencyKey: 'fund:fi_test_ref',
      });

      const second = await service.handleProviderFundingEvent(
        'paystack',
        paystackBody,
        true,
      );

      expect(second.ok).toBe(true);
      expect(second.skipped).toBe('already_credited');
      expect(mockWallet.fund).not.toHaveBeenCalled();
    });

    it('does not credit when webhook signature is unverified', async () => {
      fundingIntent.findFirst.mockResolvedValue(intent);
      fundingIntent.update.mockResolvedValue({
        ...intent,
        status: 'PENDING',
        providerReference: 'psk_txn_1',
      });

      const result = await service.handleProviderFundingEvent(
        'paystack',
        paystackBody,
        false,
      );

      expect(result.ok).toBe(true);
      expect(mockWallet.fund).not.toHaveBeenCalled();
    });
  });
});
