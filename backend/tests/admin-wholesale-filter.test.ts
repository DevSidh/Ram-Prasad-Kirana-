import assert from 'node:assert/strict';
import { productsQuery } from '../src/routes/admin.js';

assert.equal(productsQuery.parse({ wholesale: 'true' }).wholesale, true);
assert.equal(productsQuery.parse({ wholesale: 'false' }).wholesale, false);
assert.equal(productsQuery.parse({}).wholesale, undefined);
assert.equal(productsQuery.parse({ vendingDrink: 'true' }).vendingDrink, true);
assert.equal(productsQuery.parse({ vendingDrink: 'false' }).vendingDrink, false);
assert.equal(productsQuery.parse({}).vendingDrink, undefined);

console.log('Admin product catalog filtering tests passed.');
