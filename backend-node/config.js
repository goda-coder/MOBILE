/**
 * Centralized application configuration.
 *
 * All transfer limit values live here so that changing them requires
 * updating exactly one file. Both the Backend validation and the
 * Frontend API response will automatically reflect the new values.
 */

export const TRANSFER_LIMITS = {
  /**
   * Maximum amount a user may transfer in a single rolling day.
   * Value is in minor units (1 EGP = 100 minor units).
   */
  DAILY_LIMIT_MINOR: 50_000, // 500 EGP

  /**
   * Maximum amount a user may transfer in a single rolling month.
   * Value is in minor units (1 EGP = 100 minor units).
   */
  MONTHLY_LIMIT_MINOR: 200_000, // 2 000 EGP
};

/**
 * Converts an amount from major units (EGP) to minor units (piastres).
 */
export const toMinor = (egp) => Math.round(egp * 100);
