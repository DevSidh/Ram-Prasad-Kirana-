import assert from 'node:assert/strict';
import {
  getLocalDayRange,
  getLocalDayRangeForKey,
} from '../src/services/local-day.js';

const beforeNepalMidnight = getLocalDayRange(
  new Date('2026-10-21T18:14:59.000Z'),
);
assert.equal(beforeNepalMidnight.start.toISOString(), '2026-10-20T18:15:00.000Z');
assert.equal(beforeNepalMidnight.end.toISOString(), '2026-10-21T18:15:00.000Z');

const atNepalMidnight = getLocalDayRange(
  new Date('2026-10-21T18:15:00.000Z'),
);
assert.equal(atNepalMidnight.start.toISOString(), '2026-10-21T18:15:00.000Z');
assert.equal(atNepalMidnight.end.toISOString(), '2026-10-22T18:15:00.000Z');

const selectedNepalDay = getLocalDayRangeForKey('2026-10-22');
assert.equal(selectedNepalDay.start.toISOString(), '2026-10-21T18:15:00.000Z');
assert.equal(selectedNepalDay.end.toISOString(), '2026-10-22T18:15:00.000Z');
assert.throws(() => getLocalDayRangeForKey('2026-02-30'), RangeError);
assert.throws(() => getLocalDayRangeForKey('2026/10/22'), RangeError);

console.log('Local-day boundary tests passed.');
