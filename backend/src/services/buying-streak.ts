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
    select: { day: true, title: true, description: true },
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
      select: { day: true, title: true, description: true },
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
      },
    }),
  ]);

  const progressByDay = new Map(progress.map((item) => [item.day, item]));
  const rewardByDay = new Map<number, {
    day: number;
    title: string;
    description: string;
  }>();
  for (const configuredReward of configuredRewards) {
    rewardByDay.set(configuredReward.day, configuredReward);
  }
  for (const unlockedReward of progress) {
    rewardByDay.set(unlockedReward.day, {
      day: unlockedReward.day,
      title: unlockedReward.title,
      description: unlockedReward.description,
    });
  }

  return {
    currentStreak: calculateCurrentBuyingStreak(
      purchaseDays.map(({ dayKey }) => dayKey),
      now,
    ),
    lastPurchaseDay: purchaseDays[0]?.dayKey ?? null,
    rewards: [...rewardByDay.values()]
      .sort((left, right) => left.day - right.day)
      .map((reward) => {
        const status = progressByDay.get(reward.day);
        return {
          ...reward,
          isUnlocked: status !== undefined,
          unlockedAt: status?.unlockedAt.toISOString() ?? null,
          claimedAt: status?.claimedAt?.toISOString() ?? null,
        };
      }),
  };
}
