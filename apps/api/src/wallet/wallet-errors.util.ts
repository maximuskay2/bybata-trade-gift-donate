import { BadRequestException, NotFoundException } from '@nestjs/common';

/**
 * Maps internal/Prisma errors to safe messages for mobile clients.
 */
export function mapWalletUserError(
  error: unknown,
  fallback = 'Payment could not be completed. Please try again.',
): BadRequestException | NotFoundException {
  if (error instanceof BadRequestException || error instanceof NotFoundException) {
    return error;
  }

  const msg = error instanceof Error ? error.message : String(error);
  const lower = msg.toLowerCase();

  if (
    lower.includes('transaction already closed') ||
    lower.includes('expired transaction') ||
    (lower.includes('interactive transaction') && lower.includes('timeout')) ||
    lower.includes('unable to start a transaction') ||
    msg.includes('P2028')
  ) {
    return new BadRequestException(
      'Your payment took too long to process. Please wait a moment and try again. If your balance was not deducted, you can safely retry.',
    );
  }

  if (lower.includes('insufficient funds')) {
    return new BadRequestException(msg);
  }

  if (
    lower.includes('prisma') ||
    lower.includes('invocation') ||
    lower.includes('$transaction')
  ) {
    return new BadRequestException(fallback);
  }

  if (lower.startsWith('advert purchase failed:') || lower.startsWith('promotion purchase failed:')) {
    const stripped = msg.replace(/^[^:]+:\s*/i, '').trim();
    if (stripped.length > 0 && stripped.length < 200 && !stripped.toLowerCase().includes('prisma')) {
      return new BadRequestException(stripped);
    }
    return new BadRequestException(fallback);
  }

  return new BadRequestException(fallback);
}
