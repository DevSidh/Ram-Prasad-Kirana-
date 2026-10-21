import assert from 'node:assert/strict';
import {
  createStoreEmailSender,
  getEmailDeliveryConfigurationStatus,
  getEmailDeliveryFailureDetails,
  getSmtpConfiguration,
  resolveSmtpIpv4,
  StoreEmailDeliveryError,
} from '../src/services/email-sender.js';

const gmailEnvironment: NodeJS.ProcessEnv = {
  SMTP_HOST: ' smtp.gmail.com ',
  SMTP_PORT: '465',
  SMTP_SECURE: 'true',
  SMTP_USER: 'store@example.com',
  SMTP_PASS: 'private-app-password',
  SMTP_FROM: 'Ram Prasad General Store <store@example.com>',
};

assert.deepEqual(getSmtpConfiguration(gmailEnvironment), {
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  user: 'store@example.com',
  password: 'private-app-password',
  from: 'Ram Prasad General Store <store@example.com>',
});
assert.deepEqual(
  getEmailDeliveryConfigurationStatus(gmailEnvironment),
  { configured: true, provider: 'smtp' },
);
assert.equal(
  getEmailDeliveryConfigurationStatus({}).configured,
  false,
);
assert.equal(
  getSmtpConfiguration({ ...gmailEnvironment, SMTP_PORT: 'not-a-port' }),
  null,
);
assert.equal(
  getSmtpConfiguration({ ...gmailEnvironment, SMTP_SECURE: 'sometimes' }),
  null,
);
assert.equal(
  getSmtpConfiguration({ SMTP_HOST: 'smtp.gmail.com' }),
  null,
  'username, app password, and sender are required',
);
assert.ok(createStoreEmailSender(gmailEnvironment));
assert.equal(createStoreEmailSender({}), null);

async function run(): Promise<void> {
  assert.equal(
    await resolveSmtpIpv4('smtp.gmail.com', async (host) => {
      assert.equal(host, 'smtp.gmail.com');
      return ['192.0.2.25', '192.0.2.26'];
    }),
    '192.0.2.25',
  );
  assert.equal(await resolveSmtpIpv4('192.0.2.25'), '192.0.2.25');
  await assert.rejects(
    resolveSmtpIpv4('smtp.gmail.com', async () => []),
    /did not resolve to an IPv4 address/,
  );
  await assert.rejects(
    resolveSmtpIpv4('2001:db8::1'),
    /must be an IPv4 address/,
  );

  const authFailure = getEmailDeliveryFailureDetails(
    new StoreEmailDeliveryError('EAUTH', 535),
  );
  assert.equal(authFailure.statusCode, 503);
  assert.match(authFailure.message, /Google App Password/);
  assert.deepEqual(authFailure.diagnostic, {
    provider: 'smtp',
    code: 'EAUTH',
    responseCode: 535,
  });

  const timeoutFailure = getEmailDeliveryFailureDetails(
    new StoreEmailDeliveryError('ETIMEDOUT'),
  );
  assert.match(timeoutFailure.message, /cannot reach Gmail SMTP/);
  assert.deepEqual(timeoutFailure.diagnostic, {
    provider: 'smtp',
    code: 'ETIMEDOUT',
  });

  console.log('Gmail SMTP configuration and failure tests passed.');
}

void run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
