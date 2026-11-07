import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createClient } from '@libsql/client';
import { manifest, sha256, stagingSql } from './schema.mjs';
import { decimalText, encodeValue, timestampText } from './values.mjs';
import { connectTurso } from './connection.mjs';
import { validateSnapshot, importSnapshot, verifySnapshot } from './import-core.mjs';

async function fixture() {
  const directory=await mkdtemp(join(tmpdir(),'faststore-migration-'));
  const metadata=manifest();
  const data=new Map();
  for(const model of metadata.models){
    const row={};
    for(const field of model.fields){
      if(!field.required){row[field.name]=null;continue;}
      if(field.kind==='enum'){row[field.name]=metadata.enums.find((e)=>e.name===field.type).values[0];continue;}
      row[field.name]=({String:`fixture-${model.name}-${field.name}`,Int:'1',BigInt:'9007199254740993',
        Boolean:'true',Float:'1.5',Decimal:'12345678901234567890.1234567890123456789',
        DateTime:'2026-11-07 10:20:30.123456+00:00',Bytes:'AQID',Json:'{"fixture":true}'})[field.type];
    }
    data.set(model.name,row);
  }
  for(let round=0;round<metadata.models.length;round++){
    for(const model of metadata.models){
      for(const relation of model.relations){
        const row=data.get(model.name);
        if(relation.fields.some((field)=>row[field]===null))continue;
        relation.fields.forEach((field,index)=>{row[field]=data.get(relation.target)[relation.references[index]];});
      }
    }
  }
  const tables=[];
  for(const [index,model] of metadata.models.entries()){
    const text=JSON.stringify(data.get(model.name))+'\n';
    const file=`table-${index}.jsonl`;
    await writeFile(join(directory,file),text);
    tables.push({name:model.name,file,count:1,sha256:sha256(text)});
  }
  await writeFile(join(directory,'manifest.json'),JSON.stringify({format:1,complete:true,
    sourceSchemaSha256:metadata.sourceSchemaSha256,tables,absentKnownModels:[]}));
  return {directory,metadata,data,cleanup:()=>rm(directory,{recursive:true,force:true})};
}

test('every actual model, primary key, relation and declared index has staging DDL',()=>{
  const metadata=manifest(),ddl=stagingSql(metadata).join(';\n');
  assert.equal(metadata.models.length,54);
  assert.equal(metadata.enums.length,16);
  assert.equal((ddl.match(/CREATE TABLE /g)||[]).length,54);
  for(const model of metadata.models){
    assert.ok(model.primaryKey.length);
    for(const field of model.fields)assert.ok(ddl.includes('"'+field.name+'"'));
  }
  assert.match(ddl,/DEFERRABLE INITIALLY DEFERRED/);
  assert.match(ddl,/"total" TEXT NOT NULL/);
});

test('decimal, signed integers, binary and UTC timestamps round-trip without currency rounding',()=>{
  assert.equal(decimalText('000123.45000'),'123.45');
  assert.equal(decimalText('1.234567890123456789e20'),'123456789012345678900');
  assert.equal(decimalText('-0.000'),'0');
  assert.equal(decimalText('1e-3'),'0.001');
  assert.equal(encodeValue({type:'BigInt'},'9007199254740993'),9007199254740993n);
  assert.throws(()=>encodeValue({type:'BigInt'},'9223372036854775808'));
  assert.throws(()=>decimalText('NaN'));
  assert.throws(()=>decimalText('Infinity'));
  assert.equal(timestampText('2026-11-07 10:20:30.123456+00:00'),'2026-11-07T10:20:30.123456Z');
  assert.equal(timestampText('2026-11-07 10:20:30.123'),'2026-11-07T10:20:30.123Z');
  assert.throws(()=>timestampText('2026-11-07T10:20:30+05:45'));
});

test('credentials remain server-side and insecure remote connections are rejected',()=>{
  assert.throws(()=>connectTurso({TURSO_DATABASE_URL:'http://example.com',TURSO_AUTH_TOKEN:'fixture'}));
  assert.throws(()=>connectTurso({TURSO_DATABASE_URL:'libsql://example.com'}));
  assert.throws(()=>connectTurso({TURSO_DATABASE_URL:'https://example.com?token=private',TURSO_AUTH_TOKEN:'fixture'}));
  assert.throws(()=>connectTurso({TURSO_DATABASE_URL:'file:fixture.db'}));
});

test('all 54 model records import, preserve exact values and verify; retry creates no duplicates',async()=>{
  const f=await fixture();
  const db=createClient({url:'file::memory:',intMode:'bigint'});
  try{
    const validated=await validateSnapshot(f.directory);
    assert.equal((await importSnapshot(db,validated)).status,'imported-and-verified');
    await verifySnapshot(db,validated);
    assert.equal((await importSnapshot(db,validated)).status,'already-imported');
    const result=await db.execute('SELECT userNumber, passwordHash FROM "User"');
    assert.equal(result.rows[0].userNumber,9007199254740993n);
    assert.equal(result.rows[0].passwordHash,f.data.get('User').passwordHash);
    const price=await db.execute('SELECT price FROM "Product"');
    assert.equal(price.rows[0].price,'12345678901234567890.1234567890123456789');
    const foreignKeys=await db.execute('PRAGMA foreign_key_check');
    assert.equal(foreignKeys.rows.length,0);
    await assert.rejects(db.execute("UPDATE \"User\" SET role='INVALID'"));
    await assert.rejects(db.execute("UPDATE \"User\" SET isActive=2"));
    await assert.rejects(db.execute("UPDATE \"Inventory\" SET productId='missing-product'"));
  }finally{db.close();await f.cleanup();}
});

test('checksum corruption, schema drift and incomplete exports refuse import',async()=>{
  const f=await fixture();
  try{
    await writeFile(join(f.directory,'table-0.jsonl'),'{}\n');
    await assert.rejects(validateSnapshot(f.directory),/Checksum mismatch/);
    const path=join(f.directory,'manifest.json');
    const snapshot=JSON.parse(await readFile(path,'utf8'));
    snapshot.complete=false;
    await writeFile(path,JSON.stringify(snapshot));
    await assert.rejects(validateSnapshot(f.directory),/Incomplete/);
  }finally{await f.cleanup();}
});

test('foreign key error rolls back every table and every imported row',async()=>{
  const f=await fixture();
  const db=createClient({url:'file::memory:',intMode:'bigint'});
  try{
    const path=join(f.directory,'manifest.json');
    const snapshot=JSON.parse(await readFile(path,'utf8'));
    const table=snapshot.tables.find((t)=>t.name==='Inventory');
    const row=f.data.get('Inventory'); row.productId='missing-product';
    const text=JSON.stringify(row)+'\n';table.sha256=sha256(text);
    await writeFile(join(f.directory,table.file),text);
    await writeFile(path,JSON.stringify(snapshot));
    await assert.rejects(importSnapshot(db,await validateSnapshot(f.directory)),/Foreign-key/);
    const remaining=await db.execute("SELECT name FROM sqlite_master WHERE type='table'");
    assert.equal(remaining.rows.length,0);
  }finally{db.close();await f.cleanup();}
});

test('an existing business database is never cleared or overwritten',async()=>{
  const f=await fixture();
  const db=createClient({url:'file::memory:',intMode:'bigint'});
  try{
    await db.execute('CREATE TABLE existing_business_data (id TEXT PRIMARY KEY)');
    await db.execute("INSERT INTO existing_business_data VALUES ('preserve-me')");
    await assert.rejects(importSnapshot(db,await validateSnapshot(f.directory)),/not empty/);
    assert.equal((await db.execute('SELECT id FROM existing_business_data')).rows[0].id,'preserve-me');
  }finally{db.close();await f.cleanup();}
});

test('an explicitly unapplied source migration creates an empty declared target table',async()=>{
  const f=await fixture(); const db=createClient({url:'file::memory:',intMode:'bigint'});
  try{
    const path=join(f.directory,'manifest.json'); const snapshot=JSON.parse(await readFile(path,'utf8'));
    const missing=snapshot.tables.pop();
    snapshot.format=2;
    snapshot.absentKnownModels=[{name:missing.name,reason:'not-present-in-source-schema',count:0}];
    await writeFile(path,JSON.stringify(snapshot));
    const result=await importSnapshot(db,await validateSnapshot(f.directory));
    assert.equal(result.status,'imported-and-verified');
    assert.equal((await db.execute(`SELECT COUNT(*) AS count FROM "${missing.name}"`)).rows[0].count,0n);
  }finally{db.close();await f.cleanup();}
});
