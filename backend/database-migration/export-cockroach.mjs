import pg from 'pg';
import { mkdir, open, rename, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
import dotenv from 'dotenv';
import { manifest, quote } from './schema.mjs';

dotenv.config({path: new URL('../.env', import.meta.url)});
const check = process.argv.includes('--check');
const destination = process.argv.find((arg) => arg.startsWith('--out='))?.slice(6);
if (!check && !destination) throw new Error('Provide --out=<new private backup directory>. Never store exports in Git.');
const connectionString = process.env.COCKROACH_SOURCE_URL || process.env.DATABASE_URL;
if (!connectionString) throw new Error('Set COCKROACH_SOURCE_URL privately on the backend.');
let parsed;
try { parsed = new URL(connectionString); }
catch { throw new Error('Invalid source database URL. Review the private backend environment.'); }
if (!['postgres:', 'postgresql:'].includes(parsed.protocol) || parsed.searchParams.get('sslmode') !== 'verify-full') {
  throw new Error('Source must use PostgreSQL protocol and sslmode=verify-full. Do not disable certificate validation.');
}
const client = new pg.Client({connectionString, connectionTimeoutMillis:10000,
  query_timeout:30000, application_name:'faststore-readonly-export'});
let directory;
let began = false;
try {
  await client.connect();
  await client.query('BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE READ ONLY');
  began = true;
  await client.query("SET LOCAL TIME ZONE 'UTC'");
  await client.query('SELECT 1');
  if (check) {
    console.log(JSON.stringify({source:'accessible', mode:'read-only', dataExported:false}));
  } else {
    directory = resolve(destination);
    // Exclusive creation: never overwrite any previous export.
    await mkdir(directory, {recursive:false, mode:0o700});
    const metadata = manifest();
    const tables = await client.query(`SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name`);
    const inventory = [];
    for (let tableIndex = 0; tableIndex < tables.rows.length; tableIndex++) {
      const name = tables.rows[tableIndex].table_name;
      const columns = await client.query(`SELECT column_name, data_type FROM information_schema.columns
        WHERE table_schema='public' AND table_name=$1 ORDER BY ordinal_position`, [name]);
      const fields = columns.rows.map((column) => ({name:column.column_name, databaseType:column.data_type}));
      const sourceDdl=await client.query(`SHOW CREATE TABLE public.${quote(name)}`);
      const selection = fields.map((field) => /^(bytea|bytes)$/i.test(field.databaseType)
        ? `encode(${quote(field.name)}, 'base64') AS ${quote(field.name)}`
        : `${quote(field.name)}::TEXT AS ${quote(field.name)}`).join(', ');
      const file = `table-${tableIndex}.jsonl`;
      const output = await open(resolve(directory, file + '.partial'), 'wx', 0o600);
      const digest = createHash('sha256');
      let count = 0;
      try {
        await client.query(`DECLARE export_cursor NO SCROLL CURSOR FOR SELECT ${selection} FROM public.${quote(name)}`);
        while (true) {
          const batch = await client.query('FETCH FORWARD 250 FROM export_cursor');
          if (!batch.rows.length) break;
          for (const row of batch.rows) {
            const line = JSON.stringify(row) + '\n';
            await output.write(line);
            digest.update(line);
            count++;
          }
        }
        await client.query('CLOSE export_cursor');
        await output.sync();
      } finally { await output.close(); }
      await rename(resolve(directory,file+'.partial'), resolve(directory,file));
      inventory.push({name, fields, file, count, sha256:digest.digest('hex'),
        sourceDdl:sourceDdl.rows[0]?.create_statement ?? null,
        knownModel:metadata.models.some((model) => model.name === name)});
    }
    await client.query('COMMIT');
    began = false;
    // A repository can contain an unapplied migration (for example a feature
    // added after CockroachDB became unavailable). Record that state explicitly:
    // the target receives the empty declared table, while we never claim it had
    // source records to recover.
    const absentKnownModels = metadata.models
      .filter((model) => !inventory.some((table) => table.name === model.name))
      .map((model) => ({name:model.name, reason:'not-present-in-source-schema', count:0}));
    const snapshot = {format:2, complete:true, exportedAt:new Date().toISOString(),
      sourceSchemaSha256:metadata.sourceSchemaSha256, tables:inventory, absentKnownModels};
    await writeFile(resolve(directory,'manifest.json'),JSON.stringify(snapshot,null,2)+'\n',{flag:'wx',mode:0o600});
    console.log(JSON.stringify({export:'complete', tables:inventory.length,
      records:inventory.reduce((sum,table)=>sum+table.count,0), absentKnownModels}));
  }
} catch (error) {
  // Driver messages may contain source names or connection details. Keep those
  // out of logs; SQLSTATE is sufficient for an operator to inspect privately.
  console.error(JSON.stringify({source:'unavailable-or-export-failed',
    sqlstate:/^[A-Z0-9]{5}$/.test(error.code ?? '') ? error.code : 'CONNECTION_OR_EXPORT_ERROR',
    complete:false, action:'Check the provider console. A partial directory is NOT a valid backup.'}));
  process.exitCode = 1;
} finally {
  if (began) await client.query('ROLLBACK').catch(()=>{});
  await client.end().catch(()=>{});
}
