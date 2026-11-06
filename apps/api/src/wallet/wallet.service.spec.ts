import { Test, TestingModule } from '@nestjs/testing';
import { WalletService } from './wallet.service';
import { PrismaService } from '../common/prisma.service';
import { WalletSecurityService } from './wallet-security.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('WalletService', () => {
  let service: WalletService;
  let prisma: PrismaService;
  let security: WalletSecurityService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WalletService,
        {
          provide: PrismaService,
          useValue: {
            account: {
              upsert: jest.fn(async ({ where }) => ({ id: 'acc_'+where.userId, userId: where.userId, balance: 0 })),
              update: jest.fn(async () => ({})),
              findUnique: jest.fn(async () => ({ id: 'acc_1', userId: 'u1', balance: 1000 })),
            },
            walletTransaction: {
              findUnique: jest.fn(async () => null),
              aggregate: jest.fn(async () => ({ _sum: { amount: 0 } })),
              create: jest.fn(async ({ data }) => ({ id: 'tx_'+Date.now(), ...data })),
            },
            $transaction: jest.fn(async (cb: any) => {
              const mockDb = {
                account: {
                  findUnique: jest.fn().mockResolvedValue({ id: 'acc_1', userId: 'u1', balance: 1000 }),
                  update: jest.fn(),
                },
                walletTransaction: {
                  create: jest.fn(),
                },
              };
              return cb(mockDb);
            }),
          },
        },
        {
          provide: WalletSecurityService,
          useValue: {
            checkTransactionLimits: jest.fn().mockResolvedValue(undefined),
            verifyTransactionAuth: jest.fn().mockResolvedValue(true),
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            create: jest.fn().mockResolvedValue({}),
          },
        },
      ],
    }).compile();

    service = module.get<WalletService>(WalletService);
    prisma = module.get<PrismaService>(PrismaService);
    security = module.get<WalletSecurityService>(WalletSecurityService);
  });

  it('should reject self transfers', async () => {
    await expect(service.send('u1', 'u1', 10)).rejects.toThrow(/Cannot send to self/);
  });

  it('should enforce minimum transfer amount when configured', async () => {
    process.env.WALLET_TRANSFER_MIN_BYC = '5';
    await expect(service.send('u1', 'u2', 2)).rejects.toThrow(/Minimum transfer amount/);
    process.env.WALLET_TRANSFER_MIN_BYC = '';
  });
});
