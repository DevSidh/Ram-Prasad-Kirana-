import { cert, getApps, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { PrismaClient } from '@prisma/client';

let firebaseAppName: string | undefined;

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
