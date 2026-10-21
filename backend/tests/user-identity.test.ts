import assert from 'node:assert/strict';
import {
  normalizeEmail,
  normalizePhone,
  normalizeSignupPhone,
} from '../src/services/user-identity.js';

assert.equal(normalizeEmail('  Shopper@Example.COM '), 'shopper@example.com');
assert.equal(normalizePhone('+1 (202) 555-0147'), '12025550147');
assert.equal(normalizePhone('   '), null);
assert.equal(normalizeSignupPhone('981-234-5678'), '9812345678');
assert.equal(normalizeSignupPhone('981234567'), null);
assert.equal(normalizeSignupPhone('98123456789'), null);

console.log('User identity normalization tests passed.');
