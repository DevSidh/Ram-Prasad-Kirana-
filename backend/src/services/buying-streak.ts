import type { Prisma, PrismaClient } from '@prisma/client';
import { getLocalDayRange, getStoreDayKey } from './local-day.js';

function previousDayKey(dayKey: string): string {
  const [year, month, day] = dayKey.split('-').map(Number);
  const previousDay = new Date(Date.UTC(year, month - 1, day - 1));
  return [
    previousDay.getUTCFullYear(),
    String(previousDay.getUTCMonth() + 1).padStart(2, '0'),
    String(previousDay.getUTCDate()).padStart(2, '0'),
  ].join('-');
}

export function calculateCurrentBuyingStreak(
  dayKeys: readonly string[],
  now: Date = new Date(),
): number {
  if (dayKeys.length === 0) return 0;

  const today = getStoreDayKey(now);
  const yesterday = previousDayKey(today);
  const latestDay = dayKeys[0];
  if (latestDay !== today && latestDay !== yesterday) return 0;

  const purchaseDays = new Set(dayKeys);
  let expectedDay = latestDay;
  let currentStreak = 0;
  while (purchaseDays.has(expectedDay)) {
    currentStreak++;
    expectedDay = previousDayKey(expectedDay);
  }
  return currentStreak;
}

export function calculateLongestBuyingStreak(
  dayKeys: readonly string[],
): number {
  const uniqueDays = [...new Set(dayKeys)].sort();
  let longestStreak = 0;
  let currentStreak = 0;
  let previousDay: string | null = null;

  for (const dayKey of uniqueDays) {
    currentStreak =
      previousDay !== null && previousDayKey(dayKey) === previousDay
        ? currentStreak + 1
        : 1;
    longestStreak = Math.max(longestStreak, currentStreak);
    previousDay = dayKey;
  }

  return longestStreak;
}

function countLatestConsecutiveDays(dayKeys: readonly string[]): number {
  if (dayKeys.length === 0) return 0;
  const purchaseDays = new Set(dayKeys);
  let dayKey = dayKeys[0];
  let streak = 0;
  while (purchaseDays.has(dayKey)) {
    streak++;
    dayKey = previousDayKey(dayKey);
  }
  return streak;
}

export async function recordBuyingStreakPurchase(
  transaction: Prisma.TransactionClient,
  userId: string,
  orderCreatedAt: Date,
): Promise<void> {
  const dayKey = getStoreDayKey(orderCreatedAt);
  await transaction.buyingStreakPurchaseDay.upsert({
    where: { userId_dayKey: { userId, dayKey } },
    update: {},
    create: { userId, dayKey },
  });

  const purchaseDays = await transaction.buyingStreakPurchaseDay.findMany({
    where: { userId },
    orderBy: { dayKey: 'desc' },
    select: { dayKey: true },
  });
  const currentStreak = calculateCurrentBuyingStreak(
    purchaseDays.map(({ dayKey: purchaseDay }) => purchaseDay),
    orderCreatedAt,
  );
  if (currentStreak === 0) return;

  const rewards = await transaction.buyingStreakRewardConfig.findMany({
    where: { day: { lte: currentStreak } },
    select: { day: true, title: true, description: true, couponId: true },
  });
  for (const reward of rewards) {
    await transaction.buyingStreakRewardProgress.upsert({
      where: { userId_day: { userId, day: reward.day } },
      update: {},
      create: {
        userId,
        day: reward.day,
        title: reward.title,
        description: reward.description,
        couponTemplateId: reward.couponId,
      },
    });
  }
}

export async function removeCancelledOrderPurchaseDay(
  transaction: Prisma.TransactionClient,
  input: {
    userId: string;
    orderId: string;
    orderCreatedAt: Date;
  },
): Promise<void> {
  const dayKey = getStoreDayKey(input.orderCreatedAt);
  const dayRange = getLocalDayRange(input.orderCreatedAt);
  const remainingOrders = await transaction.order.count({
    where: {
      userId: input.userId,
      id: { not: input.orderId },
      createdAt: { gte: dayRange.start, lt: dayRange.end },
      status: { not: 'CANCELLED' },
    },
  });
  if (remainingOrders === 0) {
    await transaction.buyingStreakPurchaseDay.deleteMany({
      where: { userId: input.userId, dayKey },
    });
  }
}

export async function getBuyingStreakSnapshot(
  client: Prisma.TransactionClient | PrismaClient,
  userId: string,
  now: Date = new Date(),
) {
  const [purchaseDays, configuredRewards, progress] = await Promise.all([
    client.buyingStreakPurchaseDay.findMany({
      where: { userId },
      orderBy: { dayKey: 'desc' },
      select: { dayKey: true },
    }),
    client.buyingStreakRewardConfig.findMany({
      orderBy: { day: 'asc' },
      select: {
        day: true,
        title: true,
        description: true,
        couponId: true,
        coupon: { select: { code: true } },
      },
    }),
    client.buyingStreakRewardProgress.findMany({
      where: { userId },
      orderBy: { day: 'asc' },
      select: {
        day: true,
        title: true,
        description: true,
        unlockedAt: true,
        claimedAt: true,
        coupon: { select: { code: true } },
      },
    }),
  ]);

  const progressByDay = new Map(progress.map((item) => [item.day, item]));
  const dayKeys = purchaseDays.map(({ dayKey }) => dayKey);
  const today = getStoreDayKey(now);
  const yesterday = previousDayKey(today);
  const latestDay = dayKeys[0] ?? null;
  const currentStreak = calculateCurrentBuyingStreak(dayKeys, now);
  const latestConsecutiveStreak = countLatestConsecutiveDays(dayKeys);
  const bestStreak = calculateLongestBuyingStreak(dayKeys);
  const rewardByDay = new Map<number, {
    day: number;
    title: string;
    description: string;
    couponCode: string | null;
  }>();
  for (const configuredReward of configuredRewards) {
    rewardByDay.set(configuredReward.day, {
      day: configuredReward.day,
      title: configuredReward.title,
      description: configuredReward.description,
      couponCode: null,
    });
  }
  for (const unlockedReward of progress) {
    rewardByDay.set(unlockedReward.day, {
      day: unlockedReward.day,
      title: unlockedReward.title,
      description: unlockedReward.description,
      couponCode: progressByDay.get(unlockedReward.day)?.coupon?.code ?? null,
    });
  }

  const orderedRewards = [...rewardByDay.values()]
    .sort((left, right) => left.day - right.day);
  const currentMonth = today.slice(0, 7);
  const daysInMonth = new Date(
    Date.UTC(Number(today.slice(0, 4)), Number(today.slice(5, 7)), 0),
  ).getUTCDate();
  const monthStartDayOfWeek = new Date(
    Date.UTC(Number(today.slice(0, 4)), Number(today.slice(5, 7)) - 1, 1),
  ).getUTCDay();
  const completedMilestones = orderedRewards.filter(
    (reward) => reward.day <= bestStreak,
  );
  const nextReward = orderedRewards.find(
    (reward) => reward.day > currentStreak,
  );

  return {
    currentStreak,
    bestStreak,
    totalPurchaseDays: dayKeys.length,
    lastConsecutiveStreak: latestConsecutiveStreak,
    lastPurchaseDay: latestDay,
    hasPurchasedToday: latestDay === today,
    streakAtRisk: currentStreak > 0 && latestDay !== today,
    streakBroken:
      currentStreak === 0 &&
      latestConsecutiveStreak > 0 &&
      latestDay !== today &&
      latestDay !== yesterday,
    calendarMonth: currentMonth,
    daysInMonth,
    monthStartWeekday: (monthStartDayOfWeek + 6) % 7,
    monthPurchaseDays: dayKeys.filter((dayKey) =>
      dayKey.startsWith(`${currentMonth}-`),
    ),
    profileLevel:
      completedMilestones.length === 0
        ? 'New shopper'
        : completedMilestones[completedMilestones.length - 1].title,
    nextRewardDay: nextReward?.day ?? null,
    daysToNextReward:
      nextReward === undefined
        ? null
        : Math.max(nextReward.day - currentStreak, 0),
    rewards: orderedRewards.map((reward) => {
      const status = progressByDay.get(reward.day);
      return {
        ...reward,
        isUnlocked: status !== undefined,
        unlockedAt: status?.unlockedAt.toISOString() ?? null,
        claimedAt: status?.claimedAt?.toISOString() ?? null,
        couponCode: status?.coupon?.code ?? null,
      };
    }),
  };
}
