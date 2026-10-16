import assert from 'node:assert/strict';
import {
  DEFAULT_WEEKLY_HOURS,
  getStoreAvailability,
  storeHoursSchema,
} from '../src/services/store-hours.js';

const mondayHours = DEFAULT_WEEKLY_HOURS.map((day) => ({
  ...day,
  isOpen: day.day === 1,
  openTime: '09:00',
  closeTime: '21:00',
}));
const mondayMorning = new Date('2026-01-05T03:15:00.000Z');

assert.equal(
  getStoreAvailability(true, mondayHours, mondayMorning).isAcceptingOrders,
  true,
  'Store should accept orders at 09:00 Nepal time on an open day.',
);
assert.equal(
  getStoreAvailability(
    true,
    mondayHours,
    new Date('2026-01-05T15:15:00.000Z'),
  ).isAcceptingOrders,
  false,
  'Closing time should be exclusive.',
);
assert.equal(
  getStoreAvailability(false, mondayHours, mondayMorning).statusMessage,
  'Online ordering is temporarily paused by the store.',
);
assert.equal(
  getStoreAvailability(
    true,
    mondayHours,
    new Date('2026-01-06T03:15:00.000Z'),
  ).isAcceptingOrders,
  false,
  'Store should not accept orders on a closed weekday.',
);
assert.equal(
  storeHoursSchema.safeParse([
    ...mondayHours.slice(1),
    { ...mondayHours[0], day: 2 },
  ]).success,
  false,
  'Schedule must have one entry per weekday.',
);
assert.equal(
  storeHoursSchema.safeParse([
    ...mondayHours.slice(1),
    { ...mondayHours[0], day: 1, closeTime: '08:00' },
  ]).success,
  false,
  'Open days must close after opening.',
);

console.log('Store hours availability tests passed.');
