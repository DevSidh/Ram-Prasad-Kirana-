import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import express from 'express';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';
import { createAuthMiddleware } from '../src/middleware/auth.js';
import { createAdminRouter } from '../src/routes/admin.js';

// A disposable HTTP server and in-memory records only. No Prisma connection.
const secret = 'isolated-admin-audit-secret-with-at-least-32-characters';
const users = new Map([
  ['admin', { id: 'admin', role: 'ADMIN', isActive: true, tokenVersion: 0 }],
  ['customer', { id: 'customer', role: 'CUSTOMER', isActive: true, tokenVersion: 0 }],
  ['rider', { id: 'rider', role: 'DELIVERY_PERSON', isActive: true, tokenVersion: 0 }],
  ['billing', { id: 'billing', role: 'BILLING_STAFF', isActive: true, tokenVersion: 0 }],
]);
let writes = 0;
const prisma = {
  user: {
    findUnique: async ({ where }: any) => users.get(where.id),
    findFirst: async ({ where }: any) => {
      const user = users.get(where.id);
      return user?.role === where.role ? user : null;
    },
    update: async ({ where, data, select }: any) => {
      writes++;
      const user = users.get(where.id)!;
      user.isActive = data.isActive ?? user.isActive;
      user.tokenVersion += data.tokenVersion?.increment ?? 0;
      const record: Record<string, unknown> = { ...user, name: where.id, email: `${where.id}@example.test`, phone: null, userNumber: 1n, isAvailable: false };
      return Object.fromEntries(Object.keys(select).map(key => [key, record[key]]));
    },
  },
  delivery: { count: async () => 0 },
} as unknown as PrismaClient;
const auth = createAuthMiddleware(prisma, secret);
const app = express();
app.use(express.json());
app.use('/admin', createAdminRouter(prisma, auth.authenticateToken, auth.requireAdmin, auth.requireBillingStaff));
app.get('/authenticated', auth.authenticateToken, (_req, res) => res.sendStatus(204));

async function main() {
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>(resolve => server.once('listening', resolve));
  const address = server.address();
  assert(address && typeof address !== 'string');
  const base = `http://127.0.0.1:${address.port}`;
  const token = (id: string) => jwt.sign({ id, tokenVersion: users.get(id)!.tokenVersion }, secret);
  try {
    // Derive the matrix from actual router declarations so new routes are covered.
    const routes = [
      ['admin.ts', ''], ['admin-billing.ts', '/billing'],
    ].flatMap(([file, prefix]) => {
      const source = readFileSync(new URL(`../src/routes/${file}`, import.meta.url), 'utf8');
      return [...source.matchAll(/router\.(get|post|put|patch|delete)\('([^']+)'/g)]
        .map(match => ({
          method: match[1].toUpperCase(),
          path: `${prefix}${match[2]}`.replace(/:[a-zA-Z]+/g, 'test-id'),
          adminOnly: source.slice(match.index! + match[0].length).trimStart().startsWith(', adminOnly'),
        }));
    });
    assert(routes.length > 70);
    let denied = 0;
    for (const route of routes) {
      for (const id of [null, 'customer', 'rider', ...(route.path.startsWith('/billing/') && !route.adminOnly ? [] : ['billing'])]) {
        const response = await fetch(`${base}/admin${route.path}`, {
          method: route.method,
          headers: { ...(id ? { authorization: `Bearer ${token(id)}` } : {}), 'content-type': 'application/json' },
          ...(route.method === 'GET' ? {} : { body: '{}' }),
        });
        assert.equal(response.status, id === null ? 401 : 403, `${id}: ${route.method} ${route.path}`);
        const body = await response.text();
        assert(!/passwordHash|AUTH_SECRET|DATABASE_URL|stack|tokenVersion/.test(body));
        denied++;
      }
    }
    assert.equal(writes, 0, 'Denied requests must never reach writes');
    for (const [id, path] of [['customer', '/customers/customer'], ['rider', '/delivery/people/rider/active']]) {
      const oldToken = token(id);
      const patch = (isActive: boolean) => fetch(`${base}/admin${path}`, {
        method: 'PATCH', headers: { authorization: `Bearer ${token('admin')}`, 'content-type': 'application/json' },
        body: JSON.stringify({ isActive }),
      });
      const disabled = await patch(false);
      assert.equal(disabled.status, 200);
      const response = await disabled.json() as any;
      if (id === 'customer') {
        assert.equal(response.customer.profileId, 'USR-000001');
        assert.equal(response.customer.userNumber, undefined);
        assert.equal(response.customer.tokenVersion, undefined);
      }
      assert.equal(users.get(id)!.tokenVersion, 1);
      assert.equal((await patch(true)).status, 200);
      assert.equal((await fetch(`${base}/authenticated`, { headers: { authorization: `Bearer ${oldToken}` } })).status, 401);
      assert.equal((await fetch(`${base}/authenticated`, { headers: { authorization: `Bearer ${token(id)}` } })).status, 204);
    }
    console.log(`Admin security audit passed: ${routes.length} routes, ${denied} denied requests; customer/rider token revocation survives reactivation.`);
  } finally {
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
}
void main().catch(error => { console.error(error); process.exitCode = 1; });
