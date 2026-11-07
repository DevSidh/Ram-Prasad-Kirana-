import dotenv from 'dotenv';
import { connectTurso, checkConnection } from './connection.mjs';

dotenv.config({path:new URL('../.env',import.meta.url)});
let client;
try {
  client = connectTurso();
  await checkConnection(client);
  const tables = await client.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
  console.log(JSON.stringify({connection:'ok', applicationTables:tables.rows.length}));
} catch (error) {
  const message = error instanceof Error ? error.message : '';
  const category = /unauthori[sz]ed|forbidden|token|auth/i.test(message) ? 'AUTHENTICATION'
    : /fetch failed|ENOTFOUND|ECONN|timeout|network/i.test(message) ? 'NETWORK_OR_URL'
    : error instanceof TypeError ? 'CONFIGURATION_OR_PROTOCOL' : 'DATABASE_CONNECTION';
  const code = typeof error === 'object' && error !== null &&
    typeof error.code === 'string' && /^[A-Z0-9_:-]{1,80}$/.test(error.code)
    ? error.code : undefined;
  const safeMessage = message
    .replace(/(?:libsql|https?):\/\/[^\s"']+/gi, '[REDACTED_URL]')
    .replace(/(?:token|authorization|bearer)\s+[^\s,;]+/gi, '$1 [REDACTED]')
    .slice(0, 200);
  console.log(JSON.stringify({connection:'failed', errorType:category, code, message:safeMessage}));
  process.exitCode=1;
} finally {
  client?.close();
}
