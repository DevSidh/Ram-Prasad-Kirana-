import { readFile, lstat } from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';
import { resolve, basename } from 'node:path';
import { createHash } from 'node:crypto';
import { manifest, sha256, stagingSql, quote } from './schema.mjs';
import { encodeValue } from './values.mjs';
import { checkConnection } from './connection.mjs';

async function* rows(path) {
  const lines = createInterface({input:createReadStream(path),crlfDelay:Infinity});
  try { for await (const line of lines) { if (line.length) yield JSON.parse(line); } }
  finally { lines.close(); }
}

function normalize(model, row) {
  const keys = Object.keys(row);
  if (keys.length !== model.fields.length || keys.some((key) => !model.fields.some((f)=>f.name===key))) {
    throw new Error(`Source columns do not match model ${model.name}; explicit mapping is required.`);
  }
  return model.fields.map((field)=>{
    try { return encodeValue(field,row[field.name]); }
    catch (error) {
      throw new Error(`Invalid ${model.name}.${field.name}: ${error instanceof Error ? error.message : 'value'}`);
    }
  });
}

function hashRow(digest, model, values) {
  // Include names/types to avoid ambiguous concatenation, and canonicalize
  // every typed value. Hashing whole records verifies password/JSON/blob data
  // without ever logging them. Buffer is serialized as base64.
  digest.update(JSON.stringify(model.fields.map((field,index)=>{
    const value=values[index];
    return [field.name,field.type,value===null?null:Buffer.isBuffer(value)?value.toString('base64'):String(value)];
  }))+'\n');
}

export async function validateSnapshot(directory) {
  directory=resolve(directory);
  const raw=await readFile(resolve(directory,'manifest.json'));
  const snapshot=JSON.parse(raw);
  const metadata=manifest();
  if (![1,2].includes(snapshot.format) || snapshot.complete!==true || !Array.isArray(snapshot.tables)) throw new Error('Incomplete or unsupported snapshot');
  if (snapshot.sourceSchemaSha256!==metadata.sourceSchemaSha256) throw new Error('Snapshot belongs to a different schema revision. Review a mapping first.');
  const absent = new Map((snapshot.absentKnownModels ?? []).map((entry) => [entry.name,entry]));
  for (const entry of absent.values()) {
    if (!metadata.models.some((model)=>model.name===entry.name) || entry.count!==0 || entry.reason!=='not-present-in-source-schema') {
      throw new Error('Invalid absent-model declaration.');
    }
  }
  if (snapshot.format===1 && snapshot.missingModels?.length) throw new Error('Source is missing models. Review historical migrations before importing. No records were invented.');
  const unknown=snapshot.tables.filter((t)=>t.name!=='_prisma_migrations' && !metadata.models.some((m)=>m.name===t.name));
  if (unknown.length) throw new Error('Additional source tables need an explicit mapping; import refused.');
  const names=new Set();
  for(const table of snapshot.tables){
    if(names.has(table.name)) throw new Error('Duplicate table in snapshot');
    names.add(table.name);
    if(typeof table.file!=='string' || basename(table.file)!==table.file || !/^table-\d+\.jsonl$/.test(table.file)) throw new Error('Unsafe snapshot filename');
    const path=resolve(directory,table.file);
    const stats=await lstat(path);
    if(!stats.isFile() || stats.isSymbolicLink()) throw new Error('Snapshot must contain regular files');
    const digest=createHash('sha256');
    for await (const chunk of createReadStream(path)) digest.update(chunk);
    if(digest.digest('hex')!==table.sha256) throw new Error(`Checksum mismatch for ${table.name}`);
    const model=metadata.models.find((m)=>m.name===table.name);
    let count=0;
    for await (const row of rows(path)) { if(model) normalize(model,row); count++; }
    if(!Number.isSafeInteger(table.count) || count!==table.count) throw new Error(`Count mismatch for ${table.name}`);
  }
  for(const model of metadata.models) {
    if(!names.has(model.name) && !absent.has(model.name)) throw new Error(`Source table is missing: ${model.name}`);
  }
  return {metadata,snapshot,directory,snapshotId:sha256(raw)};
}

export async function importSnapshot(client, validated) {
  const {metadata,snapshot,directory,snapshotId}=validated;
  await checkConnection(client);
  const existing=await client.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
  if(existing.rows.length){
    // A completed identical import can be checked again. Any partial/unknown
    // target is refused, never cleared, overwritten or silently merged.
    if(!existing.rows.some((r)=>r.name==='_FaststoreStagingImport')) throw new Error('Target is not empty. No existing data will be changed.');
    const record=await client.execute('SELECT snapshotId FROM "_FaststoreStagingImport"');
    if(record.rows.length!==1 || record.rows[0].snapshotId!==snapshotId) throw new Error('Target contains another import.');
    await verifySnapshot(client,validated);
    return {status:'already-imported',snapshotId};
  }
  const tx=await client.transaction('write');
  try{
    for(const sql of stagingSql(metadata)) await tx.execute(sql);
    // Relations are deferred until commit, including cyclic coupon/reward
    // relationships. Foreign-key validation still runs before commit.
    for(const model of metadata.models){
      const table=snapshot.tables.find((t)=>t.name===model.name);
      const sql=`INSERT INTO ${quote(model.name)} (${model.fields.map((f)=>quote(f.name)).join(',')}) VALUES (${model.fields.map(()=>'?').join(',')})`;
      if (!table) continue; // Explicitly absent source table: preserve empty state.
      for await (const row of rows(resolve(directory,table.file))) {
        await tx.execute({sql,args:normalize(model,row)});
      }
    }
    await verifySnapshot(tx,validated);
    const revalidated=await validateSnapshot(directory);
    if(revalidated.snapshotId!==snapshotId) throw new Error('Snapshot changed during import.');
    await tx.execute('CREATE TABLE "_FaststoreStagingImport" (snapshotId TEXT PRIMARY KEY NOT NULL, completedAt TEXT NOT NULL, purpose TEXT NOT NULL CHECK (purpose = \'lossless-staging-only\'))');
    await tx.execute({sql:'INSERT INTO "_FaststoreStagingImport" VALUES (?, ?, ?)',args:[snapshotId,new Date().toISOString(),'lossless-staging-only']});
    await tx.commit();
    return {status:'imported-and-verified',snapshotId,tables:metadata.models.length};
  }catch(error){ await tx.rollback().catch(()=>{}); throw error; }
  finally{tx.close();}
}

export async function verifySnapshot(client,{metadata,snapshot,directory}) {
  const violations=await client.execute('PRAGMA foreign_key_check');
  if(violations.rows.length) throw new Error('Foreign-key verification failed. No commit permitted.');
  for(const model of metadata.models){
    const table=snapshot.tables.find((t)=>t.name===model.name);
    if (!table) {
      const count=await client.execute(`SELECT COUNT(*) AS count FROM ${quote(model.name)}`);
      if(BigInt(count.rows[0].count)!==0n) throw new Error(`Explicitly absent table is not empty: ${model.name}`);
      continue;
    }
    const count=await client.execute(`SELECT COUNT(*) AS count FROM ${quote(model.name)}`);
    if(BigInt(count.rows[0].count)!==BigInt(table.count)) throw new Error(`Target count differs: ${model.name}`);
    // Read by primary key in export order to avoid DB-specific collation and
    // NULL ordering. These offline checks cost reads, once per migration.
    const expected=createHash('sha256'), actual=createHash('sha256');
    for await(const row of rows(resolve(directory,table.file))){
      const values=normalize(model,row);
      hashRow(expected,model,values);
      const result=await client.execute({
        sql:`SELECT * FROM ${quote(model.name)} WHERE ${model.primaryKey.map((key)=>quote(key)+' = ?').join(' AND ')}`,
        args:model.primaryKey.map((key)=>values[model.fields.findIndex((f)=>f.name===key)]),
      });
      if(result.rows.length!==1) throw new Error(`Target key mismatch: ${model.name}`);
      const typed=model.fields.map((field)=>{
        const value=result.rows[0][field.name];
        return value instanceof ArrayBuffer ? Buffer.from(value) : value instanceof Uint8Array ? Buffer.from(value) : value;
      });
      hashRow(actual,model,typed);
    }
    if(actual.digest('hex')!==expected.digest('hex')) throw new Error(`Target values differ: ${model.name}`);
  }
}
