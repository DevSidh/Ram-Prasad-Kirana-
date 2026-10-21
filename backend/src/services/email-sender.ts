import nodemailer from 'nodemailer';
import { resolve4 } from 'node:dns/promises';
import { isIP } from 'node:net';

export interface StoreEmail {
  to: string;
  subject: string;
  text: string;
}

export type SendStoreEmail = (email: StoreEmail) => Promise<void>;

export interface SmtpConfiguration {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  password: string;
  from: string;
}

export class StoreEmailDeliveryError extends Error {
  constructor(readonly code?: string, readonly responseCode?: number) {
    super('The Gmail SMTP provider is unavailable.');
    this.name = 'StoreEmailDeliveryError';
  }
}

export type EmailDeliveryConfigurationStatus = {
  configured: boolean;
  provider: 'smtp' | 'unconfigured';
};

type ResolveIpv4 = (hostname: string) => Promise<string[]>;

export async function resolveSmtpIpv4(
  host: string,
  resolveIpv4: ResolveIpv4 = resolve4,
): Promise<string> {
  const addressType = isIP(host);
  if (addressType === 4) return host;
  if (addressType === 6) {
    throw new Error(
      'The SMTP host must be an IPv4 address or an IPv4-resolvable hostname.',
    );
  }

  const addresses = await resolveIpv4(host);
  const address = addresses[0];
  if (!address) {
    throw new Error(`The SMTP host ${host} did not resolve to an IPv4 address.`);
  }
  return address;
}

export function getSmtpConfiguration(
  env: NodeJS.ProcessEnv = process.env,
): SmtpConfiguration | null {
  const host = env.SMTP_HOST?.trim();
  const configuredPort = env.SMTP_PORT?.trim();
  const port = configuredPort ? Number(configuredPort) : 465;
  const user = env.SMTP_USER?.trim();
  const password = env.SMTP_PASS;
  const from = env.SMTP_FROM?.trim();
  const secureSetting = env.SMTP_SECURE?.trim().toLowerCase();

  if (!host || !Number.isInteger(port) || port < 1 || port > 65535 ||
      !user || !password?.trim() || !from ||
      (secureSetting && secureSetting !== 'true' && secureSetting !== 'false')) {
    return null;
  }

  return {
    host,
    port,
    secure: secureSetting ? secureSetting === 'true' : port === 465,
    user,
    password,
    from,
  };
}

export function getEmailDeliveryConfigurationStatus(
  env: NodeJS.ProcessEnv = process.env,
): EmailDeliveryConfigurationStatus {
  return getSmtpConfiguration(env)
    ? { configured: true, provider: 'smtp' }
    : { configured: false, provider: 'unconfigured' };
}

export function getEmailDeliveryFailureDetails(error: StoreEmailDeliveryError): {
  statusCode: 503;
  message: string;
  diagnostic: {
    provider: 'smtp';
    code?: string;
    responseCode?: number;
  };
} {
  const rejectedCredentials = error.code === 'EAUTH' ||
    error.responseCode === 534 || error.responseCode === 535;
  const message = rejectedCredentials
    ? 'Gmail rejected the SMTP credentials. Use a Google App Password and verify the Gmail sender address.'
    : error.code === 'ETIMEDOUT' || error.code === 'ENETUNREACH' ||
        error.code === 'ECONNECTION' || error.code === 'ESOCKET'
      ? 'The app server cannot reach Gmail SMTP. Check outbound SMTP access and port 465 in the hosting service.'
      : 'Gmail SMTP is unavailable. Check the SMTP settings and try again.';

  return {
    statusCode: 503,
    message,
    diagnostic: {
      provider: 'smtp',
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

export function createSmtpEmailSender(
  env: NodeJS.ProcessEnv = process.env,
): SendStoreEmail | null {
  const config = getSmtpConfiguration(env);
  if (!config) return null;

  return async (email) => {
    let transport: ReturnType<typeof nodemailer.createTransport> | undefined;
    try {
      const address = await resolveSmtpIpv4(config.host);
      transport = nodemailer.createTransport({
        host: address,
        port: config.port,
        secure: config.secure,
        auth: { user: config.user, pass: config.password },
        tls: { servername: config.host },
        connectionTimeout: 15_000,
        greetingTimeout: 15_000,
        socketTimeout: 15_000,
      });
      await transport.sendMail({ from: config.from, ...email });
    } catch (error) {
      const code = error && typeof error === 'object' && 'code' in error &&
          typeof error.code === 'string' && /^[A-Z0-9_]+$/.test(error.code)
        ? error.code
        : undefined;
      const responseCode =
        error && typeof error === 'object' && 'responseCode' in error &&
            typeof error.responseCode === 'number' &&
            Number.isInteger(error.responseCode)
          ? error.responseCode
          : undefined;
      throw new StoreEmailDeliveryError(code, responseCode);
    } finally {
      transport?.close();
    }
  };
}

export function createStoreEmailSender(
  env: NodeJS.ProcessEnv = process.env,
): SendStoreEmail | null {
  return createSmtpEmailSender(env);
}
