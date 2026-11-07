import { roundMoney } from './fair-value';

export type TopUpAction = 'accept' | 'decline' | 'counter';

export interface TopUpState {
  payerId: string;
  payeeId: string;
  amount: number;
  status: string;
  payerAccepted: boolean;
  payeeAccepted: boolean;
  aiReason: string | null;
  counteredById: string | null;
  capped: boolean;
}

const OPEN_FOR_RESPONSE = new Set(['SUGGESTED', 'COUNTERED', 'ACCEPTED', 'ORDER_CREATED']);

export function nextTopUpState(
  row: TopUpState,
  userId: string,
  action: TopUpAction,
  amount: number | undefined,
  capUsd: number,
): TopUpState {
  if (userId !== row.payerId && userId !== row.payeeId) {
    throw new Error('Only the two people in this trade can respond');
  }
  if (!OPEN_FOR_RESPONSE.has(row.status)) {
    throw new Error('This top-up can no longer be changed');
  }
  if (row.status === 'ORDER_CREATED' && action !== 'decline') {
    throw new Error('PayPal checkout already started. Decline it or finish payment.');
  }

  if (action === 'decline') {
    return {
      ...row,
      status: 'DECLINED',
      payerAccepted: false,
      payeeAccepted: false,
    };
  }

  if (action === 'counter') {
    if (amount == null || !Number.isFinite(amount) || amount < 0) {
      throw new Error('Enter a cash amount of zero or more');
    }
    if (amount > capUsd) {
      throw new Error(`Amount cannot be more than $${capUsd}`);
    }
    const next = roundMoney(amount);
    return {
      ...row,
      amount: next,
      status: 'COUNTERED',
      payerAccepted: false,
      payeeAccepted: false,
      counteredById: userId,
      capped: next >= capUsd && next > 0,
      aiReason: `Counter of $${next}. Both people need to accept this amount.`,
    };
  }

  const payerAccepted = row.payerAccepted || userId === row.payerId;
  const payeeAccepted = row.payeeAccepted || userId === row.payeeId;
  return {
    ...row,
    payerAccepted,
    payeeAccepted,
    status: payerAccepted && payeeAccepted ? 'ACCEPTED' : row.status === 'COUNTERED' ? 'COUNTERED' : 'SUGGESTED',
  };
}
