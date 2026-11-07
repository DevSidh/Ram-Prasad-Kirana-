import { createClient } from '@libsql/client';

const database = createClient({
  url: 'file:C:/FastStore-private-backups/faststore-turso-staging-20261107.db',
  intMode: 'bigint',
});
try {
  const integrity = await database.execute('PRAGMA integrity_check');
  const foreignKeys = await database.execute('PRAGMA foreign_key_check');
  const tables = await database.execute("SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
  const records = await database.execute('SELECT COUNT(*) AS count FROM "_FaststoreStagingImport"');
  console.log(JSON.stringify({
    integrity: integrity.rows[0].integrity_check,
    foreignKeyViolations: foreignKeys.rows.length,
    tables: String(tables.rows[0].count),
    importMarkers: String(records.rows[0].count),
  }));
} finally {
  database.close();
}
