import dotenv from 'dotenv';
import { connectTurso } from './connection.mjs';
import { validateSnapshot, importSnapshot, verifySnapshot } from './import-core.mjs';
import { checkConnection } from './connection.mjs';

dotenv.config({path:new URL('../.env',import.meta.url)});
const source=process.argv.find((arg)=>arg.startsWith('--source='))?.slice(9);
if(!source) throw new Error('Provide --source=<private export directory>. Default is validation only.');
let client;
try{
  const validated=await validateSnapshot(source);
  if(process.argv.includes('--verify-remote')){
    if(process.argv.includes('--apply-staging')) throw new Error('Choose verification OR local import.');
    client=connectTurso(process.env);
    await checkConnection(client);
    await verifySnapshot(client,validated);
    console.log(JSON.stringify({remote:'verified',tables:validated.metadata.models.length,targetChanged:false}));
  }else if(!process.argv.includes('--apply-staging')){
    console.log(JSON.stringify({snapshot:'validated',tables:validated.metadata.models.length,targetChanged:false,
      purpose:'lossless-staging-only',next:'Use --apply-staging only with a NEW empty staging database.'}));
  }else{
    if(process.env.TURSO_MIGRATION_TARGET!=='staging') throw new Error('Explicit TURSO_MIGRATION_TARGET=staging is required.');
    // Remote interactive transactions have short time limits. Build and verify
    // locally, then upload the resulting SQLite file using the Turso CLI. Never
    // split an import into partially committed remote writes.
    if(!process.argv.includes('--local') || !process.env.TURSO_DATABASE_URL?.startsWith('file:')) throw new Error('Staging imports require an explicit local file URL and --local.');
    client=connectTurso(process.env,{local:true});
    console.log(JSON.stringify(await importSnapshot(client,validated)));
  }
}catch(error){
  // Never output raw driver messages, constraint values or source records.
  console.error(JSON.stringify({migration:'failed',message:'Validation or staging import failed. No partial import is accepted.',
    errorType:error instanceof TypeError?'INVALID_FORMAT':'VALIDATION_OR_DATABASE_ERROR'}));
  process.exitCode=1;
}finally{client?.close();}
