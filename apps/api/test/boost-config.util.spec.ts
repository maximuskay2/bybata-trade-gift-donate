import { computeBoostCost } from '../src/wallet/boost-config.util';

describe('computeBoostCost', () => {
  it('calculates fixed cost', () => {
    const cost = computeBoostCost({ pricingModel: 'FIXED', baseCostBYC: 25 }, 7);
    expect(cost).toBe(25);
  });

  it('calculates daily cost', () => {
    const cost = computeBoostCost({ pricingModel: 'DAILY', dailyCostBYC: 2.5 }, 4);
    expect(cost).toBe(10);
  });

  it('calculates tiered cost', () => {
    const cost = computeBoostCost({
      pricingModel: 'TIERED',
      tiers: [
        { minDays: 1, maxDays: 3, cost: 5 },
        { minDays: 4, maxDays: 7, cost: 12 },
      ],
    }, 6);
    expect(cost).toBe(12);
  });
});
