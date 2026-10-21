import nodemailer from 'nodemailer';

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

export function getSmtpConfiguration(
  env: NodeJS.ProcessEnv = process.env,
): SmtpConfiguration | null {
  const host = env.SMTP_HOST?.trim();
  const configuredPort = env.SMTP_PORT?.trim();
  const port = configuredPort ? Number(configuredPort) : 587;
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

export function createSmtpEmailSender(): SendStoreEmail | null {
  const config = getSmtpConfiguration();
  if (!config) return null;

  const transport = nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.secure,
    auth: { user: config.user, pass: config.password },
    connectionTimeout: 15_000,
    greetingTimeout: 15_000,
    socketTimeout: 15_000,
  });

  return async (email) => {
    await transport.sendMail({ from: config.from, ...email });
  };
}
