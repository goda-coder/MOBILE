import { TRANSFER_LIMITS } from '../config.js';

/**
 * Pure-business-logic service for transfer limit validation and computation.
 *
 * This service is stateless — it operates on limit records provided by
 * the caller (typically the store). This keeps the validation logic
 * testable without any data-store dependency.
 */

/**
 * Returns a fresh limit-info object for a user given their current
 * daily/monthly usage records.
 *
 * @param {{ dailyUsed: number, monthlyUsed: number, dailyResetAt: string, monthlyResetAt: string }} record
 * @returns {{ dailyLimit, dailyUsed, dailyRemaining, dailyResetAt, monthlyLimit, monthlyUsed, monthlyRemaining, monthlyResetAt }}
 */
export function computeLimits(record) {
  const dailyRemaining = Math.max(
    0,
    TRANSFER_LIMITS.DAILY_LIMIT_MINOR - record.dailyUsed,
  );
  const monthlyRemaining = Math.max(
    0,
    TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR - record.monthlyUsed,
  );

  return {
    dailyLimit: TRANSFER_LIMITS.DAILY_LIMIT_MINOR,
    dailyUsed: record.dailyUsed,
    dailyRemaining,
    dailyResetAt: record.dailyResetAt,

    monthlyLimit: TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR,
    monthlyUsed: record.monthlyUsed,
    monthlyRemaining,
    monthlyResetAt: record.monthlyResetAt,
  };
}

/**
 * Checks whether a transfer of `amountMinor` is allowed under the current
 * daily and monthly limits.
 *
 * @param {{ dailyUsed: number, monthlyUsed: number }} record
 * @param {number} amountMinor
 * @returns {{ allowed: true } | { allowed: false, limitType: 'daily'|'monthly', remaining: number, limit: number, used: number, resetAt: string }}
 */
export function checkTransferLimits(record, amountMinor) {
  const dailyRemaining = Math.max(
    0,
    TRANSFER_LIMITS.DAILY_LIMIT_MINOR - record.dailyUsed,
  );
  if (dailyRemaining < amountMinor) {
    return {
      allowed: false,
      limitType: 'daily',
      remaining: dailyRemaining,
      limit: TRANSFER_LIMITS.DAILY_LIMIT_MINOR,
      used: record.dailyUsed,
      resetAt: record.dailyResetAt,
    };
  }

  const monthlyRemaining = Math.max(
    0,
    TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR - record.monthlyUsed,
  );
  if (monthlyRemaining < amountMinor) {
    return {
      allowed: false,
      limitType: 'monthly',
      remaining: monthlyRemaining,
      limit: TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR,
      used: record.monthlyUsed,
      resetAt: record.monthlyResetAt,
    };
  }

  return { allowed: true };
}
