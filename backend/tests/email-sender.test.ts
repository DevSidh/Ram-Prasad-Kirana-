import assert from 'node:assert/strict';
import { getSmtpConfiguration } from '../src/services/email-sender.js';

const baseEnvironment: NodeJS.ProcessEnv = {
  SMTP_HOST: ' smtp.example.com ',
  SMTP_USER: ' sender@example.com ',
  SMTP_PASS: 'app-password',
  SMTP_FROM: ' Store <sender@example.com> ',
};

const defaultConfiguration = getSmtpConfiguration(baseEnvironment);
assert.deepEqual(defaultConfiguration, {
  host: 'smtp.example.com',
  port: 587,
  secure: false,
  user: 'sender@example.com',
  password: 'app-password',
  from: 'Store <sender@example.com>',
});

assert.equal(
  getSmtpConfiguration({ ...baseEnvironment, SMTP_PORT: '465' })?.secure,
  true,
  'implicit TLS is enabled by default on SMTP port 465',
);
assert.equal(
  getSmtpConfiguration({
    ...baseEnvironment,
    SMTP_PORT: '465',
    SMTP_SECURE: 'false',
  })?.secure,
  false,
  'an explicit TLS setting is respected',
);
assert.equal(
  getSmtpConfiguration({ ...baseEnvironment, SMTP_PORT: 'not-a-port' }),
  null,
);
assert.equal(
  getSmtpConfiguration({ ...baseEnvironment, SMTP_SECURE: 'sometimes' }),
  null,
);
assert.equal(
  getSmtpConfiguration({ SMTP_HOST: 'smtp.example.com' }),
  null,
  'credentials and a sender address are required',
);

console.log('SMTP configuration tests passed.');
