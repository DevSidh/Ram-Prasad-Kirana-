import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';
import type { InventoryService } from '../src/services/inventory.js';

async function main(): Promise<void> {
  const users = new Map([
    ['customer-1', {
      id: 'customer-1',
      name: 'Ram Staff',
      email: 'ram@example.test',
      role: 'CUSTOMER',
      isActive: true,
      emailVerified: true,
      tokenVersion: 0,
    }],
    ['cashier-1', {
      id: 'cashier-1',
      name: 'Cashier One',
      email: 'cashier@example.test',
      role: 'BILLING_STAFF',
      isActive: true,
      emailVerified: true,
      tokenVersion: 3,
    }],
    ['unverified-1', {
      id: 'unverified-1',
      name: 'Unverified',
      email: 'unverified@example.test',
      role: 'CUSTOMER',
      isActive: true,
      emailVerified: false,
      tokenVersion: 0,
    }],
  ]);
  const prisma = {
    user: {
      findMany: async () => [
        {
          id: 'cashier-1',
          name: 'Cashier One',
          email: 'cashier@example.test',
          role: 'BILLING_STAFF',
          isActive: true,
          emailVerified: true,
        },
      ],
      findUnique: async ({ where }: { where: { id: string } }) => {
        const user = users.get(where.id);
        return user ? { ...user } : null;
      },
      updateMany: async ({ where, data }: {
        where: { id: string; role: string };
        data: { role: string; tokenVersion: { increment: number } };
      }) => {
        const user = users.get(where.id);
        if (!user || user.role !== where.role) return { count: 0 };
        user.role = data.role;
        user.tokenVersion += data.tokenVersion.increment;
        return { count: 1 };
      },
    },
  } as unknown as PrismaClient;
  const adminOnly: RequestHandler = (req, res, next) => {
    if (req.header('x-test-role') !== 'ADMIN') {
      return res.status(403).json({ error: 'Administrator access required.' });
    }
    return next();
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/billing',
    (_req, res, next) => {
      res.locals.authenticatedUserId = 'admin-1';
      next();
    },
    createAdminBillingRouter(
      prisma,
      {} as InventoryService,
      adminOnly,
    ),
  );
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const baseUrl = `http://127.0.0.1:${address.port}/billing/staff`;
    const adminHeaders = {
      'content-type': 'application/json',
      'x-test-role': 'ADMIN',
    };
    const denied = await fetch(baseUrl, {
      headers: { 'x-test-role': 'BILLING_STAFF' },
    });
    assert.equal(denied.status, 403);

    const list = await fetch(baseUrl, { headers: { 'x-test-role': 'ADMIN' } });
    assert.equal(list.status, 200);
    const listed = await list.json() as { staff: Array<{ role: string }> };
    assert.equal(listed.staff[0].role, 'BILLING_STAFF');

    const promoteUnverified = await fetch(`${baseUrl}/unverified-1`, {
      method: 'PATCH',
      headers: adminHeaders,
      body: JSON.stringify({ role: 'BILLING_STAFF' }),
    });
    assert.equal(promoteUnverified.status, 409);

    const promote = await fetch(`${baseUrl}/customer-1`, {
      method: 'PATCH',
      headers: adminHeaders,
      body: JSON.stringify({ role: 'BILLING_STAFF' }),
    });
    assert.equal(promote.status, 200);
    assert.equal(users.get('customer-1')?.role, 'BILLING_STAFF');
    assert.equal(users.get('customer-1')?.tokenVersion, 1);

    const demote = await fetch(`${baseUrl}/cashier-1`, {
      method: 'PATCH',
      headers: adminHeaders,
      body: JSON.stringify({ role: 'CUSTOMER' }),
    });
    assert.equal(demote.status, 200);
    assert.equal(users.get('cashier-1')?.role, 'CUSTOMER');
    assert.equal(users.get('cashier-1')?.tokenVersion, 4);
    console.log('Billing staff account management tests passed.');
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
