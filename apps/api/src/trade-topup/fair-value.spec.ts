import { applyAiQuote, fallbackFairValue, sideValueUsd } from './fair-value';

describe('fallbackFairValue', () => {
  const owner = { role: 'owner' as const, title: 'MacBook Pro', category: 'ELECTRONICS', condition: 'good', photos: ['a'] };
  const bidder = { role: 'bidder' as const, title: 'Novel set', category: 'BOOKS', condition: 'good', photos: ['b'] };

  it('asks the owner of the cheaper item to add cash', () => {
    const quote = fallbackFairValue(owner, bidder, 500);
    expect(sideValueUsd(owner)).toBeGreaterThan(sideValueUsd(bidder));
    expect(quote.payerRole).toBe('bidder');
    expect(quote.amount).toBeCloseTo(sideValueUsd(owner) - sideValueUsd(bidder), 2);
    expect(quote.currency).toBe('USD');
    expect(quote.source).toBe('fallback');
    expect(quote.reason).toContain('Novel set');
  });

  it('caps a suggestion and says so', () => {
    const quote = fallbackFairValue(owner, bidder, 20);
    expect(quote.amount).toBe(20);
    expect(quote.capped).toBe(true);
    expect(quote.reason).toContain('capped at $20');
  });

  it('returns zero when the bands match', () => {
    const quote = fallbackFairValue(
      { role: 'owner', title: 'Shirt', category: 'CLOTHING', condition: 'good' },
      { role: 'bidder', title: 'Jacket', category: 'CLOTHING', condition: 'good' },
      500,
    );
    expect(quote.amount).toBe(0);
    expect(quote.reason).toContain('already close');
  });

  it('clamps an AI quote onto the cap and keeps the model reason', () => {
    const baseline = fallbackFairValue(owner, bidder, 40);
    const quote = applyAiQuote(baseline, {
      amountUsd: 900,
      payer: 'owner',
      reason: 'The laptop is newer.',
      confidence: 1.4,
    });
    expect(quote.source).toBe('ai');
    expect(quote.amount).toBe(40);
    expect(quote.capped).toBe(true);
    expect(quote.payerRole).toBe('owner');
    expect(quote.confidence).toBe(1);
    expect(quote.reason).toContain('laptop is newer');
  });

  it('ignores an AI payload that does not match the schema', () => {
    const baseline = fallbackFairValue(owner, bidder, 500);
    expect(applyAiQuote(baseline, { amountUsd: -5 })).toEqual(baseline);
  });
});
