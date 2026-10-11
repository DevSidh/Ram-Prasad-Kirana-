import assert from 'node:assert/strict';
import { normalizeEmail, normalizePhone } from '../src/services/user-identity.js';

assert.equal(normalizeEmail('  Shopper@Example.COM '), 'shopper@example.com');
assert.equal(normalizePhone('+1 (202) 555-0147'), '12025550147');
assert.equal(normalizePhone('   '), null);

console.log('User identity normalization tests passed.');
