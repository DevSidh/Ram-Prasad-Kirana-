import { z } from 'zod';

export const STORE_TIME_ZONE = 'Asia/Kathmandu';

export const storeHoursSchema = z.array(z.object({
  day: z.number().int().min(1).max(7),
  isOpen: z.boolean(),
  openTime: z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/),
  closeTime: z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/),
}).strict()).length(7).superRefine((hours, context) => {
  const days = new Set(hours.map(({ day }) => day));
  if (days.size !== 7) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Store hours must contain exactly one entry for each weekday.',
    });
  }

  hours.forEach(({ day, isOpen, openTime, closeTime }, index) => {
    if (isOpen && openTime >= closeTime) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: [index, 'closeTime'],
        message: 'Closing time must be later than opening time.',
      });
    }
  });
});

export type StoreHoursDay = z.infer<typeof storeHoursSchema>[number];

export const DEFAULT_WEEKLY_HOURS: StoreHoursDay[] = Array.from(
  { length: 7 },
  (_, index) => ({
    day: index + 1,
    isOpen: true,
    openTime: '00:00',
    closeTime: '23:59',
  }),
);

export function getStoreAvailability(
  isOrderingEnabled: boolean,
  weeklyHours: unknown,
  now: Date = new Date(),
) {
  const parsedHours = storeHoursSchema.safeParse(weeklyHours);
  if (!parsedHours.success) {
    throw new Error('Stored store hours are invalid.');
  }

  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: STORE_TIME_ZONE,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  const weekdayByName: Record<string, number> = {
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
    Sun: 7,
  };
  const day = weekdayByName[values.weekday];
  const currentTime = `${values.hour}:${values.minute}`;
  const today = parsedHours.data.find((entry) => entry.day === day);
  const withinHours = today?.isOpen === true &&
    currentTime >= today.openTime &&
    currentTime < today.closeTime;
  const isAcceptingOrders = isOrderingEnabled && withinHours;

  return {
    isOrderingEnabled,
    isAcceptingOrders,
    weeklyHours: parsedHours.data,
    timeZone: STORE_TIME_ZONE,
    statusMessage: isAcceptingOrders
      ? 'The store is open and accepting orders.'
      : isOrderingEnabled
        ? 'The store is currently closed. Please check the opening hours before ordering.'
        : 'Online ordering is temporarily paused by the store.',
  };
}
