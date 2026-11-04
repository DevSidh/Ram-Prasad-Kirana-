/** Account-specific wire protocol belongs here after Fonepay issues its current
 * merchant specification. No URLs, signatures, units or status fields are guessed.
 * Production has NO mock gateway and NO client-supplied verification endpoint. */
export type GatewayEnvironment = 'sandbox' | 'live';
export interface FonepayRequest {
  reference: string; merchantCode: string; invoiceNumber: string;
  currency: 'NPR'; amount: string;
}
export interface FonepayQr {
  payload: string; merchantCode: string; merchantName: string;
  reference: string; currency: string; amount: string; expiresAt: Date;
}
export interface FonepayVerification {
  authenticated: boolean;
  environment: GatewayEnvironment;
  status: 'SUCCESS' | 'PENDING' | 'FAILED' | 'EXPIRED' | 'CANCELLED' | 'UNKNOWN';
  merchantCode: string; reference: string; currency: string; amount: string;
  transactionId?: string;
}
export interface FonepayGateway {
  readonly environment: GatewayEnvironment;
  readonly merchantCode: string;
  /** Set only from the merchant's documented polling limits. No default guess. */
  readonly verificationPollSeconds?: number;
  create(request: FonepayRequest): Promise<FonepayQr>;
  verify(request: FonepayRequest): Promise<FonepayVerification>;
  cancel?(request: FonepayRequest): Promise<void>;
}
export class FonepayError extends Error {
  constructor(readonly code: string, message: string, readonly statusCode = 409) { super(message); }
}
export const unavailableMessage = 'Fonepay Dynamic QR is not activated. Obtain the account-issued API specification, sandbox access and verification contract from Fonepay or your acquiring bank. No payment has been requested.';

export function configuredFonepayGateway(): FonepayGateway {
  // Deliberate release gate. Supplying credentials alone must not enable an
  // unreviewed/unknown protocol. Replace with an audited account profile only.
  throw new FonepayError('FONEPAY_PROFILE_REQUIRED', unavailableMessage, 503);
}

/** Internal canonical NPR decimal representation, NOT an assumed provider unit. */
export function paisa(value: string): bigint {
  if (!/^\d{1,12}(?:\.\d{1,2})?$/.test(value)) throw new FonepayError('INVALID_MONEY', 'Invalid NPR monetary value.');
  const [whole, fraction = ''] = value.split('.');
  return BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
}
export function npr(value: bigint): string {
  if (value < 0n) throw new FonepayError('INVALID_MONEY', 'Negative payment balance.');
  return `${value / 100n}.${(value % 100n).toString().padStart(2, '0')}`;
}
