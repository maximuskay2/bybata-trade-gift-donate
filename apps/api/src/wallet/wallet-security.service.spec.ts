import { Test, TestingModule } from '@nestjs/testing';
import { WalletSecurityService } from './wallet-security.service';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { NotificationsService } from '../notifications/notifications.service';
import * as bcrypt from 'bcrypt';

describe('WalletSecurityService', () => {
  let service: WalletSecurityService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WalletSecurityService,
        {
          provide: PrismaService,
          useValue: {
            profile: {
              findUnique: jest.fn(),
              update: jest.fn(),
            },
            walletSecurity: {
              findUnique: jest.fn(),
              upsert: jest.fn(),
              update: jest.fn(),
            },
            suspiciousActivity: {
              create: jest.fn(),
            },
            walletTransaction: {
              count: jest.fn(),
              aggregate: jest.fn(),
            },
          },
        },
        { provide: EmailService, useValue: { dispatch: jest.fn() } },
        {
          provide: NotificationsService,
          useValue: { createNotification: jest.fn() },
        },
      ],
    }).compile();

    service = module.get<WalletSecurityService>(WalletSecurityService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('setPin', () => {
    it('should set PIN successfully', async () => {
      const userId = 'user123';
      const pin = '1234';
      
      (prisma.profile.update as jest.Mock).mockResolvedValue({});

      await service.setPin(userId, pin);

      expect(prisma.profile.update).toHaveBeenCalledWith({
        where: { userId },
        data: {
          walletPinHash: expect.any(String),
          walletPinSetAt: expect.any(Date),
          lastWalletActivity: expect.any(Date),
        },
      });
    });

    it('should reject invalid PIN length', async () => {
      await expect(service.setPin('user123', '12')).rejects.toThrow();
      await expect(service.setPin('user123', '1234567')).rejects.toThrow();
    });

    it('should reject non-numeric PIN', async () => {
      await expect(service.setPin('user123', 'abcd')).rejects.toThrow();
    });
  });

  describe('verifyPin', () => {
    it('should verify correct PIN', async () => {
      const userId = 'user123';
      const pin = '1234';
      const hash = await bcrypt.hash(pin, 10);

      (prisma.profile.findUnique as jest.Mock).mockResolvedValue({
        walletPinHash: hash,
      });

      const result = await service.verifyPin(userId, pin);
      expect(result).toBe(true);
    });

    it('should reject incorrect PIN', async () => {
      const userId = 'user123';
      const pin = '1234';
      const hash = await bcrypt.hash('5678', 10);

      (prisma.profile.findUnique as jest.Mock).mockResolvedValue({
        walletPinHash: hash,
      });

      const result = await service.verifyPin(userId, pin);
      expect(result).toBe(false);
    });
  });

  describe('isWalletLocked', () => {
    it('should return false when wallet is not locked', async () => {
      (prisma.walletSecurity.findUnique as jest.Mock).mockResolvedValue(null);

      const result = await service.isWalletLocked('user123');
      expect(result).toBe(false);
    });

    it('should return true when wallet is locked', async () => {
      (prisma.walletSecurity.findUnique as jest.Mock).mockResolvedValue({
        walletLocked: true,
        lockedAt: new Date(),
      });

      const result = await service.isWalletLocked('user123');
      expect(result).toBe(true);
    });
  });

  describe('checkTransactionLimits', () => {
    it('should pass when within limits', async () => {
      (prisma.walletSecurity.findUnique as jest.Mock).mockResolvedValue(null);
      (prisma.walletTransaction.aggregate as jest.Mock).mockResolvedValue({
        _sum: { amount: 0 },
      });

      await expect(
        service.checkTransactionLimits('user123', 100, 'SEND')
      ).resolves.not.toThrow();
    });

    it('should throw when exceeding per-transaction limit', async () => {
      process.env.WALLET_PER_TRANSACTION_LIMIT_BYC = '50';
      
      (prisma.walletSecurity.findUnique as jest.Mock).mockResolvedValue({
        perTransactionLimit: 50,
      });

      await expect(
        service.checkTransactionLimits('user123', 100, 'SEND')
      ).rejects.toThrow();
    });
  });

  describe('requireTransactionAuth', () => {
    it('skips auth when wallet PIN is not set', async () => {
      (prisma.profile.findUnique as jest.Mock).mockResolvedValue({
        walletPinHash: null,
      });

      await expect(
        service.requireTransactionAuth('user123'),
      ).resolves.toBeUndefined();
    });

    it('requires credentials when PIN is set', async () => {
      (prisma.profile.findUnique as jest.Mock).mockResolvedValue({
        walletPinHash: 'hashed',
      });

      await expect(
        service.requireTransactionAuth('user123'),
      ).rejects.toThrow(/PIN or biometric/);
    });

    it('accepts valid PIN without blocking on idle session', async () => {
      const pin = '1234';
      const hash = await bcrypt.hash(pin, 10);
      (prisma.profile.findUnique as jest.Mock)
        .mockResolvedValueOnce({ walletPinHash: hash }) // isPinSet
        .mockResolvedValueOnce({ walletPinHash: hash }); // verifyPin
      (prisma.walletSecurity.findUnique as jest.Mock).mockResolvedValue(null);
      (prisma.profile.update as jest.Mock).mockResolvedValue({});

      await expect(
        service.requireTransactionAuth('user123', 'PIN', pin),
      ).resolves.toBeUndefined();
      expect(prisma.profile.update).toHaveBeenCalled();
    });
  });
});

