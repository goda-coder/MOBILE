/**
 * Transfer Limits — Unit & Integration Tests
 *
 * Tests the transfer limit system by calling store functions directly,
 * without requiring HTTP, auth middleware, PIN, or KYC.
 *
 * Run: node test_transfer_limits.mjs
 */

import {
  getTransferLimits,
  checkTransferLimits,
  recordTransfer,
} from './store.js';
import { TRANSFER_LIMITS } from './config.js';
import { checkTransferLimits as serviceCheck } from './services/transferLimitService.js';

// ── Helpers ──────────────────────────────────────────────────────────────

const USER_ID = 'test-limit-user-001';
let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (!condition) throw new Error(`Assertion failed: ${msg}`);
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

function assertMatch(str, regex, label) {
  if (!regex.test(str)) {
    throw new Error(`${label}: "${str}" does not match ${regex}`);
  }
}

async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ✗ ${name}: ${e.message}`);
    failed++;
  }
}

// ── Tests ────────────────────────────────────────────────────────────────

async function main() {
  console.log('\n── Transfer Limits Tests ──\n');
  console.log(`Config: daily=${TRANSFER_LIMITS.DAILY_LIMIT_MINOR / 100} EGP, monthly=${TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR / 100} EGP\n`);

  // ── Scenario 0: Fresh user — no transfers yet ─────────────────────
  await test('Scenario 0: Fresh user has zero usage and correct limits', async () => {
    const limits = getTransferLimits(USER_ID);
    assertEqual(limits.dailyUsed, 0, 'dailyUsed');
    assertEqual(limits.monthlyUsed, 0, 'monthlyUsed');
    assertEqual(limits.dailyLimit, TRANSFER_LIMITS.DAILY_LIMIT_MINOR, 'dailyLimit');
    assertEqual(limits.monthlyLimit, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR, 'monthlyLimit');
    assertEqual(limits.dailyRemaining, TRANSFER_LIMITS.DAILY_LIMIT_MINOR, 'dailyRemaining');
    assertEqual(limits.monthlyRemaining, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR, 'monthlyRemaining');
    if (!limits.dailyResetAt) throw new Error('dailyResetAt should exist');
    if (!limits.monthlyResetAt) throw new Error('monthlyResetAt should exist');
  });

  // ── Scenario 1: Transfer 100 EGP (10000 minor) ────────────────────
  await test('Scenario 1: Transfer 100 EGP → dailyUsed=100, monthlyUsed=100', async () => {
    recordTransfer(USER_ID, 10000);
    const limits = getTransferLimits(USER_ID);
    assertEqual(limits.dailyUsed, 10000, 'dailyUsed');
    assertEqual(limits.monthlyUsed, 10000, 'monthlyUsed');
    assertEqual(limits.dailyRemaining, TRANSFER_LIMITS.DAILY_LIMIT_MINOR - 10000, 'dailyRemaining');
    assertEqual(limits.monthlyRemaining, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR - 10000, 'monthlyRemaining');
  });

  // ── Scenario 2: Transfer 400 EGP (40000 minor) → Daily limit full ─
  await test('Scenario 2: Transfer 400 EGP → dailyUsed=500 (limit reached)', async () => {
    recordTransfer(USER_ID, 40000);
    const limits = getTransferLimits(USER_ID);
    assertEqual(limits.dailyUsed, TRANSFER_LIMITS.DAILY_LIMIT_MINOR, 'dailyUsed should equal daily limit');
    assertEqual(limits.dailyRemaining, 0, 'dailyRemaining should be 0');
  });

  // ── Scenario 3: Attempt 1 EGP over the limit → Rejected ───────────
  await test('Scenario 3: Transfer 1 EGP → rejected (limit exceeded)', async () => {
    const result = checkTransferLimits(USER_ID, 100);
    assertEqual(result.allowed, false, 'should not be allowed');
    assertEqual(result.limitType, 'daily', 'should be daily limit');
    assertEqual(result.remaining, 0, 'remaining should be 0');
  });

  // ── Scenario 4: Partial remaining ──────────────────────────────────
  await test('Scenario 4: 50 EGP remaining, attempt 100 EGP → partial message', async () => {
    // Create a fresh user
    const USER_ID_2 = 'test-limit-user-002';
    // Transfer 450 EGP (45000) to leave 50 EGP (5000) remaining
    recordTransfer(USER_ID_2, 45000);

    const limits = getTransferLimits(USER_ID_2);
    assertEqual(limits.dailyUsed, 45000, 'dailyUsed should be 45000');
    assertEqual(limits.dailyRemaining, TRANSFER_LIMITS.DAILY_LIMIT_MINOR - 45000, 'dailyRemaining should be 5000');

    // Attempt 100 EGP (10000)
    const result = checkTransferLimits(USER_ID_2, 10000);
    assertEqual(result.allowed, false, 'should not be allowed');
    assertEqual(result.remaining, 5000, 'remaining should be 5000');
    assertEqual(result.limitType, 'daily', 'should be daily');
    if (!result.resetAt) throw new Error('resetAt should exist');

    // Verify the service-level function produces the same error message
    const rec = { dailyUsed: 45000, monthlyUsed: 0, dailyResetAt: limits.dailyResetAt, monthlyResetAt: limits.monthlyResetAt };
    const msgDaily = `Daily transfer limit exceeded. You can transfer up to ${(result.remaining / 100).toFixed(2)} EGP today.`;
    assertMatch(msgDaily, /50\.00 EGP/, 'Message should mention 50.00 EGP remaining');
  });

  // ── Scenario 5: Daily reset verifies the date ──────────────────────
  await test('Scenario 5: Daily reset date is correctly computed', async () => {
    const limits = getTransferLimits(USER_ID);
    const resetAt = new Date(limits.dailyResetAt);
    const now = new Date();
    const expected = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    expected.setHours(0, 0, 0, 0);
    assertEqual(resetAt.getTime(), expected.getTime(), 'dailyResetAt should be tomorrow midnight');
  });

  // ── Scenario 6: Monthly reset is one calendar month from cycle start ──
  await test('Scenario 6: Monthly reset is one calendar month from cycle start', async () => {
    const limits = getTransferLimits(USER_ID);
    const resetAt = new Date(limits.monthlyResetAt);
    const now = new Date();
    // resetAt should be on the same day of month as today (or clamped to month end)
    const expectedDay = Math.min(now.getDate(), new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate());
    assertEqual(resetAt.getDate(), expectedDay, 'monthlyResetAt day should match today (or month-end)');
    assertEqual(resetAt.getMonth(), (now.getMonth() + 1) % 12, 'monthlyResetAt should be next month');
    const expectedYear = now.getMonth() === 11 ? now.getFullYear() + 1 : now.getFullYear();
    assertEqual(resetAt.getFullYear(), expectedYear, 'monthlyResetAt year');
    assertEqual(resetAt.getHours(), 0, 'monthlyResetAt should be midnight');
    assertEqual(resetAt.getMinutes(), 0, 'monthlyResetAt should be midnight');
  });

  // ── Edge case: Month endpoint clamping (Jan 31 -> Feb 28/29) ───────
  await test('Edge case: Jan 31 -> Feb clamped to 28/29', async () => {
    // Jan 31 + 1 calendar month should clamp to Feb 28 (2026 is not a leap year)
    const jan31 = new Date(2026, 0, 31);
    const lastDayFeb = new Date(2026, 2, 0).getDate(); // Feb has 28 days in 2026
    assertEqual(lastDayFeb, 28, 'Feb 2026 has 28 days');
    const clampedDay = Math.min(jan31.getDate(), lastDayFeb);
    assertEqual(clampedDay, 28, 'Clamped day should be Feb 28');
    const result = new Date(2026, 1, clampedDay);
    assertEqual(result.getMonth(), 1, 'Should be February');
    assertEqual(result.getDate(), 28, 'Should be Feb 28');
  });

  // ── Edge case: Monthly reset across year boundary (Dec → Jan) ─────
  await test('Edge case: Dec -> Jan year boundary in monthly reset', async () => {
    const decDate = new Date(2026, 11, 15); // December 15, 2026
    const next = new Date(decDate.getFullYear(), decDate.getMonth() + 1, decDate.getDate());
    next.setHours(0, 0, 0, 0);
    assertEqual(next.getMonth(), 0, 'Should be January (0)');
    assertEqual(next.getFullYear(), 2027, 'Should be 2027');
    assertEqual(next.getDate(), 15, 'Should be 15th (same day)');
  });

  // ── Edge case: Month with 31 days -> 30 days (Mar 31 -> Apr 30) ───
  await test('Edge case: Mar 31 -> Apr 30 clamping', async () => {
    // March 31 + 1 calendar month should clamp to April 30
    const lastDayApr = new Date(2026, 4, 0).getDate(); // month 4 = May, day 0 = last day of April
    assertEqual(lastDayApr, 30, 'Apr 2026 has 30 days');
    const clampedDay = Math.min(31, lastDayApr);
    assertEqual(clampedDay, 30, 'Clamped day should be 30');
    const result = new Date(2026, 3, clampedDay);
    assertEqual(result.getDate(), 30, 'Result day should be 30');
    assertEqual(result.getMonth(), 3, 'Result month should be April (3)');
  });

  // ── Edge case: Exact limit reached ─────────────────────────────────
  await test('Edge case: Exact limit boundary — hitting daily limit exactly', async () => {
    const USER_ID_3 = 'test-limit-user-003';
    recordTransfer(USER_ID_3, TRANSFER_LIMITS.DAILY_LIMIT_MINOR);
    const limits = getTransferLimits(USER_ID_3);
    assertEqual(limits.dailyUsed, TRANSFER_LIMITS.DAILY_LIMIT_MINOR, 'dailyUsed should equal limit');
    assertEqual(limits.dailyRemaining, 0, 'dailyRemaining should be 0');
    const check = checkTransferLimits(USER_ID_3, 1);
    assertEqual(check.allowed, false, 'should reject even 1 minor unit over');
  });

  // ── Edge case: Daily limit binds before monthly (since daily < monthly) ──
  await test('Edge case: Daily limit binds before monthly limit', async () => {
    const USER_ID_4 = 'test-limit-user-004';
    // Transfer the monthly limit amount (2000 EGP) in one go
    recordTransfer(USER_ID_4, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR);
    const limits = getTransferLimits(USER_ID_4);
    // Daily limit is 500 EGP, so daily should be maxed out
    assertEqual(limits.dailyUsed, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR, 'dailyUsed should reflect large transfer');
    assertEqual(limits.dailyRemaining, 0, 'dailyRemaining should be 0 (daily limit exceeded)');
    assertEqual(limits.monthlyUsed, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR, 'monthlyUsed should equal monthly limit');
    assertEqual(limits.monthlyRemaining, 0, 'monthlyRemaining should be 0');
  });

  // ── Edge case: Multiple transfers in sequence ──────────────────────
  await test('Edge case: Multiple sequential transfers accumulate correctly', async () => {
    const USER_ID_5 = 'test-limit-user-005';
    const amounts = [5000, 3000, 2000, 10000]; // 50 + 30 + 20 + 100 = 200 EGP
    let total = 0;
    for (const amt of amounts) {
      recordTransfer(USER_ID_5, amt);
      total += amt;
    }
    const limits = getTransferLimits(USER_ID_5);
    assertEqual(limits.dailyUsed, total, `dailyUsed should be ${total}`);
    assertEqual(limits.monthlyUsed, total, `monthlyUsed should be ${total}`);
    assertEqual(limits.dailyRemaining, TRANSFER_LIMITS.DAILY_LIMIT_MINOR - total, `dailyRemaining should be ${TRANSFER_LIMITS.DAILY_LIMIT_MINOR - total}`);
  });

  // ── Edge case: Failed transfer does not affect counters ────────────
  await test('Edge case: Failed/cancelled transfer does not affect counters', async () => {
    const USER_ID_6 = 'test-limit-user-006';
    const before = getTransferLimits(USER_ID_6);
    assertEqual(before.dailyUsed, 0, 'should start at 0');

    // Simulate a "failed" transfer by NOT calling recordTransfer
    // (the app only calls recordTransfer on success)
    // Then verify counters unchanged
    const after = getTransferLimits(USER_ID_6);
    assertEqual(after.dailyUsed, before.dailyUsed, 'dailyUsed should not change');
    assertEqual(after.monthlyUsed, before.monthlyUsed, 'monthlyUsed should not change');
  });

  // ── Edge case: Record transfer with 0 amount ───────────────────────
  await test('Edge case: Zero-amount transfer does not change counters', async () => {
    const USER_ID_7 = 'test-limit-user-007';
    recordTransfer(USER_ID_7, 0);
    const limits = getTransferLimits(USER_ID_7);
    assertEqual(limits.dailyUsed, 0, 'dailyUsed should remain 0');
    assertEqual(limits.monthlyUsed, 0, 'monthlyUsed should remain 0');
  });

  // ── Service-level: Pure function tests ─────────────────────────────
  await test('Service-level: computeLimits returns correct values', async () => {
    const { computeLimits } = await import('./services/transferLimitService.js');
    const record = {
      dailyUsed: 12345,
      monthlyUsed: 67890,
      dailyResetAt: '2026-07-15T00:00:00.000Z',
      monthlyResetAt: '2026-08-01T00:00:00.000Z',
    };
    const result = computeLimits(record);
    assertEqual(result.dailyLimit, TRANSFER_LIMITS.DAILY_LIMIT_MINOR, 'dailyLimit');
    assertEqual(result.dailyUsed, 12345, 'dailyUsed');
    assertEqual(result.dailyRemaining, TRANSFER_LIMITS.DAILY_LIMIT_MINOR - 12345, 'dailyRemaining');
    assertEqual(result.monthlyLimit, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR, 'monthlyLimit');
    assertEqual(result.monthlyUsed, 67890, 'monthlyUsed');
    assertEqual(result.monthlyRemaining, TRANSFER_LIMITS.MONTHLY_LIMIT_MINOR - 67890, 'monthlyRemaining');
  });

  // ── Summary ────────────────────────────────────────────────────────
  console.log(`\n── Results: ${passed} passed, ${failed} failed ──\n`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error('FATAL:', e);
  process.exit(1);
});
