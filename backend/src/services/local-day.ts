import { STORE_TIME_ZONE } from './store-hours.js';

function calendarDate(date: Date, timeZone: string): {
  year: number;
  month: number;
  day: number;
} {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

function offsetAt(date: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  const localTimeAsUtc = Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second),
  );
  return localTimeAsUtc - Math.floor(date.getTime() / 1000) * 1000;
}

function localMidnightUtc(
  year: number,
  month: number,
  day: number,
  timeZone: string,
): Date {
  const wallClockMidnight = Date.UTC(year, month - 1, day);
  const candidate = new Date(wallClockMidnight);
  return new Date(wallClockMidnight - offsetAt(candidate, timeZone));
}

export function getLocalDayRange(
  now: Date = new Date(),
  timeZone: string = STORE_TIME_ZONE,
): { start: Date; end: Date } {
  const { year, month, day } = calendarDate(now, timeZone);
  const nextDay = new Date(Date.UTC(year, month - 1, day + 1));
  return {
    start: localMidnightUtc(year, month, day, timeZone),
    end: localMidnightUtc(
      nextDay.getUTCFullYear(),
      nextDay.getUTCMonth() + 1,
      nextDay.getUTCDate(),
      timeZone,
    ),
  };
}
