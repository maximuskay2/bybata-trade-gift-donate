import { Test, TestingModule } from '@nestjs/testing';
import { QRCodeService } from './qr-code.service';
import { PrismaService } from '../common/prisma.service';
import * as crypto from 'crypto';

describe('QRCodeService', () => {
  let service: QRCodeService;
  let prisma: PrismaService;

  const canonicalJson = (obj: Record<string, unknown>) =>
    JSON.stringify(
      Object.keys(obj)
        .sort()
        .reduce<Record<string, unknown>>((acc, k) => {
          acc[k] = obj[k];
          return acc;
        }, {}),
    );

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QRCodeService,
        {
          provide: PrismaService,
          useValue: {
            webhookEvent: {
              create: jest.fn(),
              findUnique: jest.fn(),
              upsert: jest.fn(),
              update: jest.fn(),
            },
          },
        },
      ],
    }).compile();

    service = module.get<QRCodeService>(QRCodeService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('generateReceiveQR', () => {
    const encryptionKey = crypto.randomBytes(32).toString('hex');

    beforeEach(() => {
      process.env.CONFIG_ENCRYPTION_KEY = encryptionKey;
    });

    it('should generate QR code successfully', async () => {
      const userId = 'user123';
      const amount = 100;
      const memo = 'Test payment';

      (prisma.webhookEvent.findUnique as jest.Mock).mockResolvedValue(null);
      (prisma.webhookEvent.upsert as jest.Mock).mockResolvedValue({});

      const result = await service.generateReceiveQR(userId, amount, memo);

      expect(result.qrCode).toBeDefined();
      expect(result.expiresAt).toBeInstanceOf(Date);
      expect(result.expiresAt.getTime()).toBeGreaterThan(Date.now());
      expect(prisma.webhookEvent.upsert).toHaveBeenCalled();
    });

    it('should generate QR code without amount and memo', async () => {
      const userId = 'user123';

      (prisma.webhookEvent.findUnique as jest.Mock).mockResolvedValue(null);
      (prisma.webhookEvent.upsert as jest.Mock).mockResolvedValue({});

      const result = await service.generateReceiveQR(userId);

      expect(result.qrCode).toBeDefined();
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('should return the same QR code for the same user on repeat calls', async () => {
      const userId = 'user123';
      const expiresAt = new Date(Date.now() + 100 * 365 * 24 * 60 * 60 * 1000);

      (prisma.webhookEvent.findUnique as jest.Mock)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          rawPayload: { userId, expiresAt: expiresAt.toISOString() },
        });
      (prisma.webhookEvent.upsert as jest.Mock).mockResolvedValue({});

      const first = await service.generateReceiveQR(userId);
      const second = await service.generateReceiveQR(userId);

      expect(second.qrCode).toBe(first.qrCode);
    });
  });

  describe('validateQR', () => {
    it('should validate correct QR code', async () => {
      const encryptionKey = crypto.randomBytes(32).toString('hex');
      process.env.CONFIG_ENCRYPTION_KEY = encryptionKey;

      const payload = {
        id: 'test-ref',
        uid: 'user123',
        amount: 100,
        note: 'Test',
        exp: Date.now() + 600000,
      };

      const signature = crypto
        .createHmac('sha256', Buffer.from(encryptionKey, 'hex'))
        .update(canonicalJson(payload))
        .digest('hex');

      const signedPayload = { ...payload, s: signature };
      const qrCode = Buffer.from(JSON.stringify(signedPayload)).toString('base64');

      (prisma.webhookEvent.findUnique as jest.Mock).mockResolvedValue({
        id: 'event-id',
        processed: false,
      });

      (prisma.webhookEvent.update as jest.Mock).mockResolvedValue({});

      const result = await service.validateQR(qrCode);

      expect(result.valid).toBe(true);
      expect(result.userId).toBe('user123');
      expect(result.amount).toBe(100);
    });

    it('should reject invalid signature', async () => {
      const qrCode = Buffer.from(JSON.stringify({
        id: 'test-ref',
        uid: 'user123',
        s: 'invalid-signature',
      })).toString('base64');

      const result = await service.validateQR(qrCode);

      expect(result.valid).toBe(false);
    });

    it('should reject expired QR code', async () => {
      const encryptionKey = crypto.randomBytes(32).toString('hex');
      process.env.CONFIG_ENCRYPTION_KEY = encryptionKey;

      const payload = {
        id: 'test-ref',
        uid: 'user123',
        exp: Date.now() - 1000, // Expired
      };

      const signature = crypto
        .createHmac('sha256', Buffer.from(encryptionKey, 'hex'))
        .update(canonicalJson(payload))
        .digest('hex');

      const signedPayload = { ...payload, s: signature };
      const qrCode = Buffer.from(JSON.stringify(signedPayload)).toString('base64');

      const result = await service.validateQR(qrCode);

      expect(result.valid).toBe(false);
    });
  });
});

