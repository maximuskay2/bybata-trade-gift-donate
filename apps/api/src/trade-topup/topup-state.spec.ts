import { nextTopUpState, TopUpState } from './topup-state';

function row(overrides: Partial<TopUpState> = {}): TopUpState {
  return {
    payerId: 'payer',
    payeeId: 'payee',
    amount: 25,
    status: 'SUGGESTED',
    payerAccepted: false,
    payeeAccepted: false,
    aiReason: 'The book is worth less.',
    counteredById: null,
    capped: false,
    ...overrides,
  };
}

describe('nextTopUpState', () => {
  it('accepts only when both people agree', () => {
    const once = nextTopUpState(row(), 'payer', 'accept', undefined, 500);
    expect(once.status).toBe('SUGGESTED');
    expect(once.payerAccepted).toBe(true);
    expect(once.payeeAccepted).toBe(false);
    const twice = nextTopUpState(once, 'payee', 'accept', undefined, 500);
    expect(twice.status).toBe('ACCEPTED');
  });

  it('resets both acceptances on a counter and enforces the cap', () => {
    const countered = nextTopUpState(row({ payerAccepted: true }), 'payee', 'counter', 40, 500);
    expect(countered.status).toBe('COUNTERED');
    expect(countered.amount).toBe(40);
    expect(countered.payerAccepted).toBe(false);
    expect(countered.payeeAccepted).toBe(false);
    expect(() => nextTopUpState(row(), 'payer', 'counter', 900, 500)).toThrow(/cannot be more than/);
  });

  it('declines and blocks changes after capture', () => {
    expect(nextTopUpState(row(), 'payer', 'decline', undefined, 500).status).toBe('DECLINED');
    expect(() => nextTopUpState(row({ status: 'CAPTURED' }), 'payer', 'decline', undefined, 500)).toThrow(/no longer be changed/);
    expect(() => nextTopUpState(row({ status: 'ORDER_CREATED' }), 'payer', 'accept', undefined, 500)).toThrow(/checkout already started/);
  });
});
