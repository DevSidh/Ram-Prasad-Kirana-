import { cert, getApps, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { PrismaClient } from '@prisma/client';

let firebaseAppName: string | undefined;

export function splitIntoBatches<T>(items: T[], size: number): T[][] {
  if (!Number.isInteger(size) || size < 1) {
    throw new Error('Batch size must be a positive integer.');
  }
  const batches: T[][] = [];
  for (let offset = 0; offset < items.length; offset += size) {
    batches.push(items.slice(offset, offset + size));
  }
  return batches;
}

export function isPushConfigured(): boolean {
  return Boolean(process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim());
}

function messagingClient() {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (!serviceAccountJson) return null;

  const appName = 'freshharvest-push';
  let app = getApps().find((candidate) => candidate.name === appName);
  if (!app) {
    let serviceAccount: ServiceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson) as ServiceAccount;
    } catch (error) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON must contain valid Firebase service-account JSON.', { cause: error });
    }
    app = initializeApp({ credential: cert(serviceAccount) }, appName);
  }
  firebaseAppName = app.name;
  return getMessaging(app);
}

export async function sendPushToUser(
  prisma: PrismaClient,
  userId: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  const messaging = messagingClient();
  if (!messaging || !firebaseAppName) return;

  const tokens = await prisma.deviceToken.findMany({
    where: { userId },
    select: { token: true },
  });
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens: tokens.map(({ token }) => token),
    notification: { title, body },
    data,
  });
  if (response.failureCount > 0) {
    const expiredTokens = response.responses
      .map((result, index) => ({ result, token: tokens[index].token }))
      .filter(({ result }) =>
        result.error?.code === 'messaging/registration-token-not-registered' ||
        result.error?.code === 'messaging/invalid-registration-token',
      )
      .map(({ token }) => token);
    if (expiredTokens.length > 0) {
      await prisma.deviceToken.deleteMany({
        where: { token: { in: expiredTokens } },
      });
    }
    console.error(`Push delivery failed for ${response.failureCount} device(s) for user ${userId}.`);
  }
}

export async function sendPushToUsers(
  prisma: PrismaClient,
  userIds: string[],
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<{ available: boolean; sent: number; failed: number }> {
  const messaging = messagingClient();
  if (!messaging || !firebaseAppName) {
    return { available: false, sent: 0, failed: 0 };
  }
  if (userIds.length === 0) {
    return { available: true, sent: 0, failed: 0 };
  }

  let sent = 0;
  let failed = 0;
  for (const users of splitIntoBatches(userIds, 500)) {
    const tokens = await prisma.deviceToken.findMany({
      where: { userId: { in: users } },
      select: { token: true },
    });
    for (const batch of splitIntoBatches(tokens, 500)) {
      const response = await messaging.sendEachForMulticast({
        tokens: batch.map(({ token }) => token),
        notification: { title, body },
        data,
      });
      sent += response.successCount;
      failed += response.failureCount;

      if (response.failureCount > 0) {
        const expiredTokens = response.responses
          .map((result, index) => ({ result, token: batch[index].token }))
          .filter(({ result }) =>
            result.error?.code === 'messaging/registration-token-not-registered' ||
            result.error?.code === 'messaging/invalid-registration-token',
          )
          .map(({ token }) => token);
        if (expiredTokens.length > 0) {
          await prisma.deviceToken.deleteMany({
            where: { token: { in: expiredTokens } },
          });
        }
      }
    }
  }
  return { available: true, sent, failed };
}
