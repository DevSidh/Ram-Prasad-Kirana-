import nodemailer from 'nodemailer';

export interface StoreEmail {
  to: string;
  subject: string;
  text: string;
}

export type SendStoreEmail = (email: StoreEmail) => Promise<void>;

export function createSmtpEmailSender(): SendStoreEmail | null {
  const host = process.env.SMTP_HOST?.trim();
  const port = Number(process.env.SMTP_PORT);
  const user = process.env.SMTP_USER?.trim();
  const password = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM?.trim();

  if (!host || !Number.isInteger(port) || port < 1 || port > 65535 ||
      !user || !password || !from) {
    return null;
  }

  const transport = nodemailer.createTransport({
    host,
    port,
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user, pass: password },
    connectionTimeout: 15_000,
    greetingTimeout: 15_000,
    socketTimeout: 15_000,
  });

  return async (email) => {
    await transport.sendMail({ from, ...email });
  };
}
