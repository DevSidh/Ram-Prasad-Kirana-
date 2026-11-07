import assert from 'node:assert/strict';
import express from 'express';
import {databaseAvailabilityFailure, sendDatabaseUnavailable} from '../src/services/database-availability.js';

async function main() {
  const quota = new Error('Too many database connections opened: ERROR: This cluster has reached its Request Unit limit for the month and is now disabled. HINT: the maximum number of allowed connections is 0');
  assert.equal(databaseAvailabilityFailure(quota)?.code, 'DATABASE_USAGE_LIMIT');
  for (const code of ['P1000', 'P1001', 'P1002', 'P1008', 'P1017', 'P2024', 'P2037']) {
    assert.equal(databaseAvailabilityFailure({code, message: 'postgresql://secret:private@host/db'})?.code, 'DATABASE_UNAVAILABLE');
    assert(!JSON.stringify(databaseAvailabilityFailure({code})).includes('private'));
  }
  assert.equal(databaseAvailabilityFailure(new Error('Invalid email or password')), null);
  assert.equal(databaseAvailabilityFailure({code: 'P2002'}), null);
  assert.equal(databaseAvailabilityFailure(null), null);
  const app = express();
  app.post('/login', (_req, res) => {sendDatabaseUnavailable(quota, res);});
  const server = app.listen(0);
  try {
    await new Promise<void>(resolve => server.once('listening', resolve));
    const address = server.address(); assert(address && typeof address !== 'string');
    const response = await fetch(`http://127.0.0.1:${address.port}/login`, {method: 'POST'});
    assert.equal(response.status, 503);
    assert.equal(response.headers.get('retry-after'), '300');
    const body = await response.json() as {code: string; error: string};
    assert.equal(body.code, 'DATABASE_USAGE_LIMIT');
    assert(body.error.includes('store owner'));
    assert(!JSON.stringify(body).includes('connections'));
    console.log('Database availability: quota outage, connection failures, safe 503 response and credential distinction passed.');
  } finally {await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));}
}
main().catch(error => {console.error(error); process.exitCode = 1;});
