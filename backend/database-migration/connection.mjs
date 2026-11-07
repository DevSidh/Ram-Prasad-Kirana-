import { createClient } from '@libsql/client';

export function connectTurso(env = process.env, {local = false} = {}) {
  const url = env.TURSO_DATABASE_URL;
  if (!url) throw new Error('TURSO_DATABASE_URL must be configured on the backend.');
  let protocol;
  try { protocol = new URL(url).protocol; } catch { throw new Error('Invalid TURSO_DATABASE_URL.'); }
  if (!['libsql:', 'https:'].includes(protocol) && !(local && protocol === 'file:')) {
    throw new Error('Use a secure libsql:// or https:// database URL. Local files require --local.');
  }
  if (protocol !== 'file:' && !env.TURSO_AUTH_TOKEN) throw new Error('TURSO_AUTH_TOKEN is required.');
  const parsed = new URL(url);
  if (parsed.username || parsed.password || parsed.search || parsed.hash) {
    throw new Error('Keep credentials in TURSO_AUTH_TOKEN, never in the database URL.');
  }
  // BigInt is essential: default number decoding can lose existing user numbers.
  // No transparent write retries: a lost response is not proof of rollback.
  const milliseconds=Number(env.TURSO_REQUEST_TIMEOUT_MS ?? 15000);
  if(!Number.isInteger(milliseconds) || milliseconds<1000 || milliseconds>120000) throw new Error('Invalid Turso request timeout.');
  return createClient({url, authToken: env.TURSO_AUTH_TOKEN, intMode:'bigint',
    concurrency:4, timeout:5000,
    fetch:(request,init)=>fetch(request,{...init,
      signal:AbortSignal.any([...(request.signal?[request.signal]:[]),AbortSignal.timeout(milliseconds)])}),
  });
}

export async function checkConnection(client) {
  await client.execute('PRAGMA foreign_keys = ON');
  const result = await client.execute('PRAGMA foreign_keys');
  if (Number(result.rows[0]?.foreign_keys) !== 1) throw new Error('Foreign keys are disabled.');
  await client.execute('SELECT 1');
}
