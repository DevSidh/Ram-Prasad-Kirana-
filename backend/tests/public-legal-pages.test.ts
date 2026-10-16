import assert from 'node:assert/strict';
import express from 'express';
import { createPublicLegalRouter } from '../src/routes/public-legal.js';

async function run(): Promise<void> {
  const app = express();
  app.use(createPublicLegalRouter());
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const baseUrl = `http://127.0.0.1:${address.port}`;

    const privacy = await fetch(`${baseUrl}/privacy-policy`);
    assert.equal(privacy.status, 200);
    assert.match(privacy.headers.get('content-type') ?? '', /text\/html/);
    assert.match(await privacy.text(), /ramprasad\.faststore@gmail\.com/);

    const deletion = await fetch(`${baseUrl}/account-deletion`);
    assert.equal(deletion.status, 200);
    assert.match(await deletion.text(), /Email a deletion request/);

    const stylesheet = await fetch(`${baseUrl}/legal.css`);
    assert.equal(stylesheet.status, 200);
    assert.match(stylesheet.headers.get('content-type') ?? '', /text\/css/);
    console.log('Public privacy and account-deletion pages are served.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
