import assert from 'node:assert/strict';
import { recoveryPlan, recoverRoomMigration, migrationName } from '../scripts/lib/room-migration-recovery.mjs';

const plan = recoveryPlan();
const udt = { STRING: 'varchar', INT4: 'int4', BOOL: 'bool', 'TIMESTAMP(3)': 'timestamp', JSONB: 'jsonb' };
function fixture(prefix = 1) {
  const tables = new Set(); const indexes = new Set(); const unlocked = new Set(); const writes = [];
  const rows = [{ id: 'KEEP-EXISTING-ROOM', name: 'Do not delete me' }];
  let resolved = false, failed = true, logs = 'Database error 57000: this schema change is disallowed because table "InventoryRoom" is locked; schema_locked';
  let failOn, failRelock, wrongIndex, wrongColumn;
  const initialize = (statement) => {
    const table = /^CREATE TABLE "(\w+)"/.exec(statement);
    if (table) tables.add(table[1]);
    else indexes.add(/INDEX "(\w+)"/.exec(statement)[1]);
  };
  plan.statements.slice(0, prefix).forEach(initialize);
  const db = {
    $queryRawUnsafe: async (sql) => {
      if (sql.includes('_prisma_migrations')) return failed ? [{ migration_name: migrationName, logs }] : [];
      if (sql.includes('information_schema.columns')) return [...tables].flatMap((name) => plan.tables.get(name).columns.map((c) => ({
        table_name: name, column_name: c.name, udt_name: wrongColumn === `${name}.${c.name}` ? 'int8' : udt[c.type],
        is_nullable: c.nullable ? 'YES' : 'NO', character_maximum_length: null, datetime_precision: c.type === 'TIMESTAMP(3)' ? 3n : null,
        column_default: c.defaultValue === 'CURRENT_TIMESTAMP' ? 'now()' : c.defaultValue,
      })));
      const name = /FROM "(\w+)"/.exec(sql)?.[1];
      if (sql.startsWith('SHOW CONSTRAINTS')) return [
        { constraint_type: 'PRIMARY KEY', validated: true, details: `PRIMARY KEY (${plan.tables.get(name).primary.map((c) => `"${c}" ASC`).join(', ')})` },
        ...(['InventoryRoomStock', 'InventoryRoomMovement'].includes(name) ? [{ constraint_type: 'CHECK', validated: true, details: `CHECK (quantity ${name === 'InventoryRoomStock' ? '>=' : '>'} 0:::INT8)` }] : []),
        ...(name === 'InventoryRoomStock' ? [{ constraint_type: 'FOREIGN KEY', validated: true, details: 'FOREIGN KEY ("roomId") REFERENCES public."InventoryRoom"(id) ON UPDATE CASCADE ON DELETE RESTRICT' }] : []),
      ];
      if (sql.startsWith('SHOW INDEXES')) return plan.indexes.filter((i) => i.table === name && indexes.has(i.name)).flatMap((i) => i.columns.map((c, n) => ({ index_name: i.name, non_unique: wrongIndex === i.name ? i.unique : !i.unique, seq_in_index: BigInt(n + 1), column_name: c, direction: 'ASC', storing: false, implicit: false })));
      throw new Error(`Unexpected read: ${sql}`);
    },
    $executeRawUnsafe: async (sql) => {
      writes.push(sql);
      if (failOn && sql.includes(failOn)) throw new Error('Injected schema failure');
      const table = /^CREATE TABLE IF NOT EXISTS "(\w+)"/.exec(sql);
      if (table) {
        if (table[1] === 'InventoryRoomStock') assert(unlocked.has('InventoryRoom'), 'parent must stay unlocked while adding child FK');
        tables.add(table[1]); return;
      }
      const lock = /^ALTER TABLE "(\w+)" SET \(schema_locked = (true|false)\)$/.exec(sql);
      if (lock) {
        if (lock[2] === 'true' && failRelock === lock[1]) throw new Error('Injected relock failure');
        if (lock[2] === 'true') unlocked.delete(lock[1]); else unlocked.add(lock[1]);
        return;
      }
      const index = /^CREATE (?:UNIQUE )?INDEX IF NOT EXISTS "(\w+)"/.exec(sql);
      if (index) {
        assert(unlocked.has(plan.indexes.find((i) => i.name === index[1]).table), 'index owner must be unlocked');
        indexes.add(index[1]); return;
      }
      throw new Error(`Unexpected write: ${sql}`);
    },
  };
  const resolve = async (name) => {
    assert.equal(name, migrationName); assert.equal(tables.size, 5); assert.equal(indexes.size, 5);
    assert.equal(unlocked.size, 0); assert.equal(rows[0].id, 'KEEP-EXISTING-ROOM');
    resolved = true; failed = false;
  };
  return { db, resolve, writes, unlocked, get resolved() { return resolved; }, set logs(v) { logs = v; }, set failOn(v) { failOn = v; }, set failRelock(v) { failRelock = v; }, set wrongIndex(v) { wrongIndex = v; }, set wrongColumn(v) { wrongColumn = v; }, set failed(v) { failed = v; } };
}
for (let prefix = 1; prefix <= 10; prefix++) {
  const f = fixture(prefix);
  assert.equal(await recoverRoomMigration(f.db, f.resolve, () => {}), true);
  assert(f.resolved);
  assert(f.writes.every((sql) => !/^\s*(DROP|DELETE|TRUNCATE|UPDATE|INSERT)\b/.test(sql)));
  const writeCount = f.writes.length;
  assert.equal(await recoverRoomMigration(f.db, f.resolve, () => {}), false);
  assert.equal(f.writes.length, writeCount);
}
for (const setting of ['wrongColumn', 'wrongIndex', 'logs']) {
  const f = fixture(2);
  f[setting] = setting === 'wrongColumn' ? 'InventoryRoom.id' : setting === 'wrongIndex' ? 'InventoryRoom_number_key' : 'Duplicate key violation';
  await assert.rejects(recoverRoomMigration(f.db, f.resolve, () => {}));
  assert(!f.resolved); assert.equal(f.writes.length, 0);
}
const interrupted = fixture(1);
interrupted.failOn = 'InventoryRoomMovement_requestId_key';
await assert.rejects(recoverRoomMigration(interrupted.db, interrupted.resolve, () => {}));
assert(!interrupted.resolved); assert.equal(interrupted.unlocked.size, 0);
interrupted.failOn = null;
assert.equal(await recoverRoomMigration(interrupted.db, interrupted.resolve, () => {}), true);
const relock = fixture(10); relock.failRelock = 'InventoryRoomMovement';
await assert.rejects(recoverRoomMigration(relock.db, relock.resolve, () => {}), AggregateError);
assert(!relock.resolved); assert.deepEqual([...relock.unlocked], ['InventoryRoomMovement']);
const absent = fixture(0);
await assert.rejects(recoverRoomMigration(absent.db, absent.resolve, () => {}));
assert.equal(absent.writes.length, 0);
assert.throws(() => recoveryPlan('DROP TABLE "InventoryRoom";'));
assert.equal(await recoverRoomMigration({ $queryRawUnsafe: async () => { throw { code: 'P2010', meta: { code: '42P01' } }; } }, () => assert.fail('No failed migration to resolve')), false);
await assert.rejects(recoverRoomMigration({ $queryRawUnsafe: async () => { throw new Error('Permission denied'); } }, () => assert.fail('Must not resolve')), /Permission denied/);
console.log('Room migration recovery: 10 partial states, replay/no-op, incompatible schema/index guards, unrelated failure guard, interruption retry, data preservation and relocking checks passed.');
