export interface StoreEmail {
  to: string;
  subject: string;
  text: string;
}

export type SendStoreEmail = (email: StoreEmail) => Promise<void>;

export interface GmailApiConfiguration {
  clientId: string;
  clientSecret: string;
  refreshToken: string;
  user: string;
  from: string;
}

export class StoreEmailDeliveryError extends Error {
  constructor(readonly code?: string, readonly responseCode?: number) {
    super('The Gmail API provider is unavailable.');
    this.name = 'StoreEmailDeliveryError';
  }
}

export type EmailDeliveryConfigurationStatus = {
  configured: boolean;
  provider: 'gmail-api' | 'unconfigured';
};

type Fetch = typeof fetch;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function getGmailApiConfiguration(
  env: NodeJS.ProcessEnv = process.env,
): GmailApiConfiguration | null {
  const clientId = env.GMAIL_OAUTH_CLIENT_ID?.trim();
  const clientSecret = env.GMAIL_OAUTH_CLIENT_SECRET?.trim();
  const refreshToken = env.GMAIL_REFRESH_TOKEN?.trim();
  const user = env.GMAIL_USER?.trim();
  const from = env.GMAIL_FROM?.trim();

  if (!clientId || !clientSecret || !refreshToken || !user || !from) {
    return null;
  }

  return { clientId, clientSecret, refreshToken, user, from };
}

export function getEmailDeliveryConfigurationStatus(
  env: NodeJS.ProcessEnv = process.env,
): EmailDeliveryConfigurationStatus {
  return getGmailApiConfiguration(env)
    ? { configured: true, provider: 'gmail-api' }
    : { configured: false, provider: 'unconfigured' };
}

export function getEmailDeliveryFailureDetails(error: StoreEmailDeliveryError): {
  statusCode: 503;
  message: string;
  diagnostic: {
    provider: 'gmail-api';
    code?: string;
    responseCode?: number;
  };
} {
  const rejectedCredentials = error.code === 'EAUTH' ||
    error.responseCode === 401 || error.responseCode === 403;
  const message = rejectedCredentials
    ? 'Gmail API authorization failed. Check the OAuth client, refresh token, and Gmail sender account.'
    : error.code === 'ETIMEDOUT' || error.code === 'ENETUNREACH' ||
        error.code === 'ECONNECTION' || error.code === 'ESOCKET' ||
        error.code === 'ECONNRESET' || error.code === 'EAI_AGAIN' ||
        error.code === 'ENOTFOUND'
      ? 'The app server cannot reach the Gmail API over HTTPS. Check outbound HTTPS access in the hosting service.'
      : 'Gmail API email delivery failed. Check the OAuth configuration and try again.';

  return {
    statusCode: 503,
    message,
    diagnostic: {
      provider: 'gmail-api',
      ...(error.code === undefined ? {} : { code: error.code }),
      ...(error.responseCode === undefined
        ? {}
        : { responseCode: error.responseCode }),
    },
  };
}

export function getSafeErrorMetadata(error: unknown): {
  name: string;
  code?: string;
} {
  if (!error || typeof error !== 'object') {
    return { name: 'UnknownError' };
  }
  const name = error instanceof Error ? error.name : 'UnknownError';
  const code = 'code' in error && typeof error.code === 'string' &&
      /^[A-Z0-9_]+$/.test(error.code)
    ? error.code
    : undefined;
  return { name, ...(code ? { code } : {}) };
}

function headerValue(value: string, name: string): string {
  if (/[\r\n]/.test(value)) {
    throw new Error(`Invalid newline in email ${name} header.`);
  }
  return /^[\x00-\x7F]*$/.test(value)
    ? value
    : `=?UTF-8?B?${Buffer.from(value, 'utf8').toString('base64')}?=`;
}

function buildRawMessage(email: StoreEmail, from: string): string {
  const encodedText = Buffer.from(email.text, 'utf8')
    .toString('base64')
    .match(/.{1,76}/g)
    ?.join('\r\n') ?? '';
  const message = [
    `From: ${headerValue(from, 'from')}`,
    `To: ${headerValue(email.to, 'to')}`,
    `Subject: ${headerValue(email.subject, 'subject')}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    encodedText,
  ].join('\r\n');

  return Buffer.from(message, 'utf8').toString('base64url');
}

async function readJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

export function createStoreEmailSender(
  env: NodeJS.ProcessEnv = process.env,
  fetcher: Fetch = fetch,
): SendStoreEmail | null {
  const config = getGmailApiConfiguration(env);
  if (!config) return null;

  let accessToken: string | undefined;
  let accessTokenExpiresAt = 0;

  return async (email) => {
    try {
      if (!accessToken || Date.now() >= accessTokenExpiresAt) {
        const tokenResponse = await fetcher(
          'https://oauth2.googleapis.com/token',
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
              client_id: config.clientId,
              client_secret: config.clientSecret,
              refresh_token: config.refreshToken,
              grant_type: 'refresh_token',
            }),
            signal: AbortSignal.timeout(15_000),
          },
        );
        const tokenBody = await readJson(tokenResponse);
        if (!tokenResponse.ok) {
          throw new StoreEmailDeliveryError(
            tokenResponse.status === 401 || tokenResponse.status === 403
              ? 'EAUTH'
              : 'GMAIL_OAUTH_ERROR',
            tokenResponse.status,
          );
        }
        if (!isRecord(tokenBody) || typeof tokenBody.access_token !== 'string') {
          throw new StoreEmailDeliveryError('GMAIL_OAUTH_RESPONSE_INVALID');
        }

        accessToken = tokenBody.access_token;
        const expiresIn = typeof tokenBody.expires_in === 'number'
          ? tokenBody.expires_in
          : 3600;
        accessTokenExpiresAt = Date.now() + Math.max(0, expiresIn - 60) * 1000;
      }

      const sendResponse = await fetcher(
        `https://gmail.googleapis.com/gmail/v1/users/${encodeURIComponent(config.user)}/messages/send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ raw: buildRawMessage(email, config.from) }),
          signal: AbortSignal.timeout(15_000),
        },
      );
      if (!sendResponse.ok) {
        throw new StoreEmailDeliveryError(
          sendResponse.status === 401 || sendResponse.status === 403
            ? 'EAUTH'
            : 'GMAIL_API_ERROR',
          sendResponse.status,
        );
      }
    } catch (error) {
      if (error instanceof StoreEmailDeliveryError) throw error;

      const code = error && typeof error === 'object' && 'code' in error &&
          typeof error.code === 'string' && /^[A-Z0-9_]+$/.test(error.code)
        ? error.code
        : error instanceof Error &&
            (error.name === 'TimeoutError' || error.name === 'AbortError')
          ? 'ETIMEDOUT'
          : undefined;
      throw new StoreEmailDeliveryError(code);
    }
  };
}
