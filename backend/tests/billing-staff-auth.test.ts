import assert from 'node:assert/strict';
import express from 'express';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';
import { createAuthMiddleware } from '../src/middleware/auth.js';

async function main(): Promise<void> {
  const roles: Record<string, { role: string; isActive: boolean }> = {
    admin: { role: 'ADMIN', isActive: true },
    cashier: { role: 'BILLING_STAFF', isActive: true },
    customer: { role: 'CUSTOMER', isActive: true },
    inactive: { role: 'BILLING_STAFF', isActive: false },
  };
  const prisma = {
    user: {
      findUnique: async ({ where }: { where: { id: string } }) => {
        const user = roles[where.id];
        if (!user) return null;
        return { ...user, tokenVersion: 0 };
      },
    },
  } as unknown as PrismaClient;
  const secret = 'billing-staff-auth-test-secret';
  const { authenticateToken, requireAdmin, requireBillingStaff } =
    createAuthMiddleware(prisma, secret);
  const app = express();
  app.get('/billing', authenticateToken, requireBillingStaff, (_req, res) => {
    res.sendStatus(204);
  });
  app.get('/admin', authenticateToken, requireAdmin, (_req, res) => {
    res.sendStatus(204);
  });
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const request = async (path: string, userId: string) => fetch(
      `http://127.0.0.1:${address.port}${path}`,
      {
        headers: {
          authorization: `Bearer ${jwt.sign({
            id: userId,
            tokenVersion: 0,
          }, secret)}`,
        },
      },
    );

    assert.equal((await request('/billing', 'cashier')).status, 204);
    assert.equal((await request('/admin', 'cashier')).status, 403);
    assert.equal((await request('/billing', 'customer')).status, 403);
    assert.equal((await request('/billing', 'inactive')).status, 401);
    assert.equal((await request('/billing', 'admin')).status, 204);
    assert.equal((await request('/admin', 'admin')).status, 204);
    console.log('Billing staff role enforcement passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
