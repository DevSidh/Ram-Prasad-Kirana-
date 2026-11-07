import assert from 'node:assert/strict';
import type {Prisma} from '@prisma/client';
import {applyPosPriceChanges, priceChangesInput} from '../src/services/pos-price-changes.js';

async function main() {
  const ledger = new Map<string, {cashierId: string; changes: unknown}>();
  const prices = new Map([['bhujiya', 100], ['sack', 500]]);
  let writes = 0;
  const updateMany = async ({where, data}: {where: {id: string; price: number}; data: {price: number}}) => {
    if (prices.get(where.id) !== where.price) return {count: 0};
    writes++; prices.set(where.id, data.price); return {count: 1};
  };
  const tx = {
    product: {updateMany}, wholesaleItem: {updateMany},
    posCataloguePriceChange: {
      findUnique: async ({where}: {where: {requestId: string}}) => ledger.get(where.requestId),
      create: async ({data}: {data: {requestId: string; cashierId: string; changes: unknown}}) => {ledger.set(data.requestId, data); return data;},
    },
  } as unknown as Prisma.TransactionClient;
  const changes = [{productId: 'bhujiya', expectedPrice: 100, price: 110}];
  assert.equal(priceChangesInput.safeParse(changes).success, true);
  assert.equal(priceChangesInput.safeParse([...changes, ...changes]).success, false);
  assert.equal(priceChangesInput.safeParse([{...changes[0], price: 1.001}]).success, false);
  await applyPosPriceChanges(tx, 'bill-1', 'cashier', changes);
  assert.equal(prices.get('bhujiya'), 110);
  assert.equal(10 * prices.get('bhujiya')!, 1100);
  await applyPosPriceChanges(tx, 'bill-1', 'cashier', changes);
  assert.equal(writes, 1, 'Replay must not apply price changes twice.');
  await assert.rejects(applyPosPriceChanges(tx, 'bill-1', 'other', changes), /POS_QUOTE_CHANGED/);
  await assert.rejects(applyPosPriceChanges(tx, 'bill-2', 'cashier', changes), /POS_QUOTE_CHANGED/);
  assert.equal(prices.get('bhujiya'), 110, 'A stale expected price must not overwrite the current price.');
  await applyPosPriceChanges(tx, 'bill-3', 'cashier', [{productId: 'wholesale-sack', expectedPrice: 500, price: 550}]);
  assert.equal(prices.get('sack'), 550);
  console.log('POS price edits: exact cents, catalogue changes, wholesale, stale conflict and duplicate replay passed.');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
