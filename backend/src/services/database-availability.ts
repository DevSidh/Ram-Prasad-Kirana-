import type {Response} from 'express';

/** Public diagnostics: never expose SQL, connection strings or provider logs. */
export function databaseAvailabilityFailure(error: unknown): {code: string; error: string} | null {
  if (!error || typeof error !== 'object') return null;
  const value = error as {code?: unknown; message?: unknown};
  const message = typeof value.message === 'string' ? value.message : '';
  if (/request unit limit.*(?:month|disabled)|cluster has reached its.*(?:resource|usage).*limit|cluster.*disabled.*(?:request unit|usage limit)/is.test(message)) {
    return {
      code: 'DATABASE_USAGE_LIMIT',
      error: 'The store database has reached its usage limit. The store owner must restore database service before you can sign in. Your password has not been rejected.',
    };
  }
  if (['P1000', 'P1001', 'P1002', 'P1008', 'P1017', 'P2024', 'P2037'].includes(String(value.code))) {
    return {code: 'DATABASE_UNAVAILABLE', error: 'The store database is temporarily unavailable. Please try again after the store owner restores the connection.'};
  }
  return null;
}

export function sendDatabaseUnavailable(error: unknown, res: Response): boolean {
  const failure = databaseAvailabilityFailure(error);
  if (!failure) return false;
  res.setHeader('Retry-After', '300');
  res.status(503).json(failure);
  return true;
}
