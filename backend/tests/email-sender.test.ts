import assert from 'node:assert/strict';
import {
  createStoreEmailSender,
  getEmailDeliveryConfigurationStatus,
  getEmailDeliveryFailureDetails,
  getGmailApiConfiguration,
  StoreEmailDeliveryError,
} from '../src/services/email-sender.js';

const gmailEnvironment: NodeJS.ProcessEnv = {
  GMAIL_OAUTH_CLIENT_ID: 'client-id',
  GMAIL_OAUTH_CLIENT_SECRET: 'client-secret',
  GMAIL_REFRESH_TOKEN: 'refresh-token',
  GMAIL_USER: 'store@example.com',
  GMAIL_FROM: 'Ram Prasad General Store <store@example.com>',
};

assert.deepEqual(getGmailApiConfiguration(gmailEnvironment), {
  clientId: 'client-id',
  clientSecret: 'client-secret',
  refreshToken: 'refresh-token',
  user: 'store@example.com',
  from: 'Ram Prasad General Store <store@example.com>',
});
assert.deepEqual(
  getEmailDeliveryConfigurationStatus(gmailEnvironment),
  { configured: true, provider: 'gmail-api' },
);
assert.deepEqual(
  getEmailDeliveryConfigurationStatus({}),
  { configured: false, provider: 'unconfigured' },
);
assert.equal(
  getGmailApiConfiguration({
    ...gmailEnvironment,
    GMAIL_REFRESH_TOKEN: '',
  }),
  null,
);
assert.ok(createStoreEmailSender(gmailEnvironment));
assert.equal(createStoreEmailSender({}), null);

async function run(): Promise<void> {
  const requests: Array<{ url: string; init?: RequestInit }> = [];
  const fakeFetch: typeof fetch = async (input, init) => {
    const url = typeof input === 'string' ? input : input.toString();
    requests.push({ url, init });
    if (url === 'https://oauth2.googleapis.com/token') {
      return new Response(JSON.stringify({
        access_token: 'test-access-token',
        expires_in: 3600,
      }), { status: 200 });
    }
    return new Response(JSON.stringify({ id: 'sent-message-id' }), {
      status: 200,
    });
  };
  const sendEmail = createStoreEmailSender(gmailEnvironment, fakeFetch);
  assert.ok(sendEmail);
  await sendEmail({
    to: 'customer@example.com',
    subject: 'Verify your email',
    text: 'Your code is 123456.',
  });
  await sendEmail({
    to: 'customer@example.com',
    subject: 'Reset your password',
    text: 'Your code is 654321.',
  });

  assert.equal(requests.length, 3, 'access token is reused until expiry');
  const tokenRequest = requests[0];
  assert.equal(tokenRequest.url, 'https://oauth2.googleapis.com/token');
  assert.equal(tokenRequest.init?.method, 'POST');
  assert.match(String(tokenRequest.init?.body), /grant_type=refresh_token/);

  const sendRequest = requests[1];
  assert.equal(
    sendRequest.url,
    'https://gmail.googleapis.com/gmail/v1/users/store%40example.com/messages/send',
  );
  assert.equal(sendRequest.init?.method, 'POST');
  assert.equal(
    new Headers(sendRequest.init?.headers).get('authorization'),
    'Bearer test-access-token',
  );
  const body = JSON.parse(String(sendRequest.init?.body)) as { raw: string };
  const rawEmail = Buffer.from(body.raw, 'base64url').toString('utf8');
  assert.match(rawEmail, /To: customer@example\.com/);
  assert.match(rawEmail, /Subject: Verify your email/);
  const encodedBody = rawEmail.split('\r\n\r\n')[1];
  assert.ok(encodedBody);
  assert.equal(
    Buffer.from(encodedBody, 'base64').toString('utf8'),
    'Your code is 123456.',
  );

  const authFailure = getEmailDeliveryFailureDetails(
    new StoreEmailDeliveryError('EAUTH', 401),
  );
  assert.equal(authFailure.statusCode, 503);
  assert.match(authFailure.message, /OAuth client, refresh token/);
  assert.deepEqual(authFailure.diagnostic, {
    provider: 'gmail-api',
    code: 'EAUTH',
    responseCode: 401,
  });

  const timeoutFailure = getEmailDeliveryFailureDetails(
    new StoreEmailDeliveryError('ETIMEDOUT'),
  );
  assert.match(timeoutFailure.message, /Gmail API over HTTPS/);
  assert.deepEqual(timeoutFailure.diagnostic, {
    provider: 'gmail-api',
    code: 'ETIMEDOUT',
  });

  const failedFetch: typeof fetch = async () => {
    throw Object.assign(new Error('Request timed out.'), {
      code: 'ETIMEDOUT',
    });
  };
  const failingSender = createStoreEmailSender(gmailEnvironment, failedFetch);
  assert.ok(failingSender);
  await assert.rejects(
    failingSender({
      to: 'customer@example.com',
      subject: 'Verify your email',
      text: 'Your code is 123456.',
    }),
    (error: unknown) => {
      assert.ok(error instanceof StoreEmailDeliveryError);
      assert.equal(error.code, 'ETIMEDOUT');
      return true;
    },
  );

  console.log('Gmail API configuration and delivery tests passed.');
}

void run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
