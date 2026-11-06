import { WalletService } from '../src/wallet/wallet.service';

describe('WalletService', () => {
  const mockPrisma: any = {
    account: {
      upsert: jest.fn(async ({ where }) => ({ id: 'acc_1', userId: where.userId, balance: 42 }))
    },
    conversionRate: {
      findMany: jest.fn(async () => [
        { id: 'rate1', base: 'BYC', quote: 'USD', rate: 1.25, active: true, createdAt: new Date() },
        { id: 'rate2', base: 'BYC', quote: 'NGN', rate: 1700, active: true, createdAt: new Date() },
      ])
    },
  };

  it('returns wallet balance via ensureAccount', async () => {
    const svc = new WalletService(mockPrisma);
    const res = await svc.getBalance('user_1');
    expect(res).toEqual({ balance: 42 });
    expect(mockPrisma.account.upsert).toHaveBeenCalledTimes(1);
  });

  it('caches active rates and avoids repeated DB calls within TTL', async () => {
    const svc = new WalletService(mockPrisma);
    const first = await svc.listActiveRates();
    expect(first).toHaveLength(2);
    expect(mockPrisma.conversionRate.findMany).toHaveBeenCalledTimes(1);

    const second = await svc.listActiveRates();
    expect(second).toHaveLength(2);
    expect(mockPrisma.conversionRate.findMany).toHaveBeenCalledTimes(1);
  });
});