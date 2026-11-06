import { readFileSync } from 'node:fs';

export const migrationName = '20261201000000_inventory_rooms';
const migrationUrl = new URL('../../prisma/migrations/20261201000000_inventory_rooms/migration.sql', import.meta.url);
const allowedTables = ['InventoryRoom', 'InventoryRoomStock', 'InventoryRoomMovement', 'InventoryRoomCheckout', 'InventoryLocalStockReceipt'];
const quote = (name) => `"${name}"`;
const names = (source) => [...source.matchAll(/"([^"]+)"/g)].map((match) => match[1]);

// Replay the committed migration, rather than editing its checksum or dropping
// partially created tables. Only the ten known CREATE statements are allowed.
export function recoveryPlan(sql = readFileSync(migrationUrl, 'utf8')) {
  const statements = sql.split(';').map((s) => s.trim()).filter(Boolean);
  const tables = new Map();
  const indexes = [];
  for (const statement of statements) {
    const table = /^CREATE TABLE "(\w+)" \(([\s\S]+)\)$/.exec(statement);
    if (table && allowedTables.includes(table[1])) {
      const columns = [...table[2].matchAll(/"(\w+)"\s+(TIMESTAMP\(3\)|STRING|INT4|BOOL|JSONB)(?=\s|,|$)([^,\n]*)/g)]
        .map((m) => ({ name: m[1], type: m[2], nullable: !/NOT NULL/.test(m[3]), defaultValue: /DEFAULT (true|0|CURRENT_TIMESTAMP)/.exec(m[3])?.[1] ?? null }));
      const primary = /PRIMARY KEY \(([^)]+)\)/.exec(table[2]);
      if (!primary || !columns.length || tables.has(table[1])) throw new Error('Unexpected room table definition.');
      tables.set(table[1], { name: table[1], columns, primary: names(primary[1]), statement });
      continue;
    }
    const index = /^CREATE (UNIQUE )?INDEX "(\w+)" ON "(\w+)"\(([^)]+)\)$/.exec(statement);
    if (!index || !allowedTables.includes(index[3])) throw new Error('Refusing unexpected room migration SQL.');
    indexes.push({ unique: !!index[1], name: index[2], table: index[3], columns: names(index[4]), statement });
  }
  if (tables.size !== 5 || indexes.length !== 5 || statements.length !== 10) throw new Error('Unexpected room migration shape.');
  return { tables, indexes, statements };
}

const udts = { STRING: ['varchar', 'text', 'string'], INT4: ['int4'], BOOL: ['bool'], 'TIMESTAMP(3)': ['timestamp'], JSONB: ['jsonb'] };
const normalize = (s) => s.replace(/"/g, '').replace(/\s+/g, ' ').replace(/\s*([(),])\s*/g, '$1').trim();
const constraintColumns = (details) => normalize(details).match(/\(([^)]+)\)/)?.[1].split(',').map((s) => s.replace(/ ASC$/i, '')) ?? [];

async function inspect(db, plan, complete) {
  const columns = await db.$queryRawUnsafe(`SELECT table_name, column_name, udt_name, is_nullable, character_maximum_length, datetime_precision, column_default
    FROM information_schema.columns WHERE table_schema = current_schema()
      AND table_name IN (${allowedTables.map((t) => `'${t}'`).join(',')})`);
  const present = new Set(columns.map((c) => c.table_name));
  for (const table of plan.tables.values()) {
    if (!present.has(table.name)) {
      if (complete) throw new Error(`Recovery incomplete: missing ${table.name}.`);
      continue;
    }
    const actual = columns.filter((c) => c.table_name === table.name);
    if (actual.length !== table.columns.length) throw new Error(`Refusing unexpected columns on ${table.name}.`);
    for (const expected of table.columns) {
      const column = actual.find((c) => c.column_name === expected.name);
      if (!column || !udts[expected.type].includes(column.udt_name) ||
          (column.is_nullable === 'YES') !== expected.nullable ||
          (expected.type === 'STRING' && column.character_maximum_length != null) ||
          (expected.type === 'TIMESTAMP(3)' && Number(column.datetime_precision) !== 3)) {
        throw new Error(`Refusing unexpected definition of ${table.name}.${expected.name}.`);
      }
      const actualDefault = column.column_default?.replace(/:::{0,1}[\w ]+(?:\(\d+\))?/g, '').trim();
      const defaultMatches = expected.defaultValue === 'CURRENT_TIMESTAMP'
        ? /^(?:current_timestamp(?:\(\))?|now\(\))$/i.test(actualDefault ?? '')
        : expected.defaultValue == null ? column.column_default == null : actualDefault?.toLowerCase() === expected.defaultValue;
      if (!defaultMatches) throw new Error(`Unexpected default on ${table.name}.${expected.name}.`);
    }
    const constraints = await db.$queryRawUnsafe(`SHOW CONSTRAINTS FROM ${quote(table.name)}`);
    const primary = constraints.find((c) => c.constraint_type === 'PRIMARY KEY' && c.validated === true);
    if (!primary || JSON.stringify(constraintColumns(primary.details)) !== JSON.stringify(table.primary)) throw new Error(`Unexpected primary key on ${table.name}.`);
    if (['InventoryRoomStock', 'InventoryRoomMovement'].includes(table.name)) {
      const operator = table.name === 'InventoryRoomStock' ? '>=' : '>';
      if (!constraints.some((c) => c.constraint_type === 'CHECK' && c.validated === true &&
        new RegExp(`\\bquantity\\s*${operator}\\s*0(?:\\b|:::)`).test(normalize(c.details)))) {
        throw new Error(`Missing validated quantity constraint on ${table.name}.`);
      }
    }
    if (table.name === 'InventoryRoomStock' && !constraints.some((c) => c.constraint_type === 'FOREIGN KEY' && c.validated === true &&
      /FOREIGN KEY\(roomId\)\s*REFERENCES (?:[\w]+\.){0,2}InventoryRoom\(id\)/.test(normalize(c.details)) &&
      /ON DELETE RESTRICT/.test(c.details) && /ON UPDATE CASCADE/.test(c.details))) {
      throw new Error('Unexpected InventoryRoomStock room foreign key.');
    }
    const indexRows = await db.$queryRawUnsafe(`SHOW INDEXES FROM ${quote(table.name)}`);
    for (const expected of plan.indexes.filter((index) => index.table === table.name)) {
      const rows = indexRows.filter((row) => row.index_name === expected.name);
      if (!rows.length && !complete) continue;
      const keys = rows.filter((row) => row.storing === false && row.implicit === false)
        .sort((a, b) => Number(a.seq_in_index) - Number(b.seq_in_index));
      if (!keys.length || keys.some((row) => row.non_unique !== !expected.unique || row.direction !== 'ASC') ||
          JSON.stringify(keys.map((row) => row.column_name)) !== JSON.stringify(expected.columns)) {
        throw new Error(`Unexpected or missing index ${expected.name}.`);
      }
    }
  }
  return present;
}

export async function recoverRoomMigration(db, resolveApplied, log = console.log) {
  let failed;
  try {
    failed = await db.$queryRawUnsafe(`SELECT migration_name, logs FROM "_prisma_migrations"
      WHERE migration_name = '${migrationName}' AND finished_at IS NULL AND rolled_back_at IS NULL
      ORDER BY started_at DESC LIMIT 1`);
  } catch (error) {
    // An uninitialized database has no history to repair; let migrate deploy
    // create its own history table. Other connection/permission errors surface.
    if (error?.code === 'P2021' || error?.meta?.code === '42P01' || error?.code === '42P01') return false;
    throw error;
  }
  if (!failed.length) {
    log(`No failed ${migrationName} migration needs recovery.`);
    return false;
  }
  // Never act on a running migration (logs null) or an unrelated failure.
  if (!/57000|E57000/.test(failed[0].logs ?? '') || !/schema_locked|schema change is disallowed.*locked/s.test(failed[0].logs ?? '')) {
    throw new Error(`Refusing automatic recovery of ${migrationName}: not a recorded schema-lock failure.`);
  }
  const plan = recoveryPlan();
  const present = await inspect(db, plan, false);
  if (!present.has('InventoryRoom')) throw new Error('Expected partially created InventoryRoom table is missing. Review the migration manually.');
  const touched = new Set(present);
  let failure;
  try {
    for (const statement of plan.statements) {
      const table = /^CREATE TABLE "(\w+)"/.exec(statement);
      if (table) {
        // InventoryRoom remains unlocked while the child FK is being created.
        if (!touched.has(table[1])) await db.$executeRawUnsafe(statement.replace('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS '));
        touched.add(table[1]);
        await db.$executeRawUnsafe(`ALTER TABLE ${quote(table[1])} SET (schema_locked = false)`);
      } else {
        await db.$executeRawUnsafe(statement.replace(/CREATE (UNIQUE )?INDEX /, 'CREATE $1INDEX IF NOT EXISTS '));
      }
    }
    await inspect(db, plan, true);
  } catch (error) { failure = error; }
  finally {
    const errors = [];
    for (const table of [...touched].reverse()) {
      try { await db.$executeRawUnsafe(`ALTER TABLE ${quote(table)} SET (schema_locked = true)`); }
      catch (error) { errors.push(error); }
    }
    if (errors.length) failure = new AggregateError([...(failure ? [failure] : []), ...errors], 'Room migration recovery could not restore all schema locks.');
  }
  if (failure) throw failure;
  // The full original schema must exist and all locks be restored before this.
  await resolveApplied(migrationName);
  log(`Recovered ${migrationName}; room data preserved and schema locks restored.`);
  return true;
}
