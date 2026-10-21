import assert from 'node:assert/strict';
import { getLocalDayRange } from '../src/services/local-day.js';

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

console.log('Local-day boundary tests passed.');
