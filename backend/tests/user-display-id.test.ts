import assert from 'node:assert/strict';
import { formatUserDisplayId } from '../src/services/user-display-id.js';

assert.equal(formatUserDisplayId(1n), 'USR-000001');
assert.equal(formatUserDisplayId(987654n), 'USR-987654');
assert.equal(formatUserDisplayId(1_000_000n), 'USR-1000000');
assert.throws(() => formatUserDisplayId(0n), RangeError);
assert.throws(() => formatUserDisplayId(-1n), RangeError);

console.log('User display ID tests passed.');
