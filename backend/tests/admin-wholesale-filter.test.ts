import assert from 'node:assert/strict';
import { productsQuery } from '../src/routes/admin.js';

assert.equal(productsQuery.parse({ wholesale: 'true' }).wholesale, true);
assert.equal(productsQuery.parse({ wholesale: 'false' }).wholesale, false);
assert.equal(productsQuery.parse({}).wholesale, undefined);

console.log('Admin wholesale product filtering tests passed.');
