import assert from 'node:assert/strict';
import express from 'express';
import { Prisma, type PrismaClient } from '@prisma/client';
import { FonepayPayments, publicFonepayRequest } from '../src/services/fonepay-payments.js';
import { createFonepayRouter } from '../src/routes/admin-fonepay.js';
import { npr, paisa, type FonepayGateway, type FonepayRequest, type FonepayVerification } from '../src/services/fonepay-gateway.js';

// Explicit TEST fixtures. No Fonepay server or real database is accessed.
type Row = Record<string, any>;
const actor = { id: 'test-admin', role: 'ADMIN' };
function fixture(environment: 'live' | 'sandbox' = 'live') {
  let sale: Row = { id: 'sale-1', invoiceNumber: 'RPGS-2026-TEST', receiptNumber: 'POS-TEST',
    total: new Prisma.Decimal('113.01'), paidAmount: new Prisma.Decimal('13.00'),
    subtotal: new Prisma.Decimal('113.01'), discount: new Prisma.Decimal('13'),
    vatRate: new Prisma.Decimal('13'), vatAmount: new Prisma.Decimal('13'),
    refundedAmount: new Prisma.Decimal('0'), status: 'COMPLETED', paymentStatus: 'PENDING',
    updatedAt: new Date('2026-01-01'), shift: { cashierId: actor.id } };
  let intents = new Map<string, Row>();
  let collections = new Map<string, Row>();
  let creates = 0;
  let verifies = 0;
  let failCreate = false;
  let failFinalize = false;
  let stockConsumes = 0;
  let change: Partial<FonepayVerification> = {};
  const tx: Row = {
    posSale: {
      findUnique: async ({ where }: Row) => where.id === sale.id ? { ...sale } : null,
      findUniqueOrThrow: async () => ({...sale,items:[{productId:'test-product',quantity:1,weightGrams:null}],paymentCollections:[...collections.values()]}),
      updateMany: async ({ where, data }: Row) => {
        if ((where.status && sale.status !== where.status) ||
          (where.paymentStatus && sale.paymentStatus !== where.paymentStatus) || sale.updatedAt.getTime() !== where.updatedAt.getTime() ||
          (where.paidAmount && sale.paidAmount.toString() !== where.paidAmount.toString()) ||
          (where.total && sale.total.toString() !== where.total.toString())) return { count: 0 };
        sale = { ...sale, ...data, updatedAt: new Date() }; return { count: 1 };
      },
    },
    posFonepayRequest: {
      findUnique: async ({ where }: Row) => [...intents.values()].find((v) =>
        where.id ? v.id === where.id : v.activeKey === where.activeKey) ?? null,
      create: async ({ data }: Row) => {
        assert(![...intents.values()].some((v) => v.activeKey === data.activeKey));
        const value = { state: 'CREATING', qrPayload: null, merchantName: null,
          expiresAt: null, lastCheckedAt: null, providerTransactionId: null,
          failureCode: null, verifiedAt:null,autoPrintClaimedAt:null,...data, amount: new Prisma.Decimal(data.amount) };
        intents.set(data.id, value); return { ...value };
      },
      update: async ({ where, data }: Row) => {
        const value = intents.get(where.id)!;
        if (data.providerTransactionId && [...intents.values()].some((v) =>
          v.id !== where.id && v.providerTransactionId === data.providerTransactionId)) {
          throw new Prisma.PrismaClientKnownRequestError('test duplicate', { code: 'P2002', clientVersion: 'test' });
        }
        const next = { ...value, ...data }; intents.set(where.id, next); return next;
      },
      updateMany: async ({ where, data }: Row) => {
        const value = intents.get(where.id);
        if (!value || (typeof where.state === 'string' && value.state !== where.state) ||
            (where.state?.notIn && where.state.notIn.includes(value.state)) ||
            (where.activeKey && value.activeKey !== where.activeKey) ||
            (where.autoPrintClaimedAt === null && value.autoPrintClaimedAt !== null) ||
            (where.OR && value.lastCheckedAt && value.lastCheckedAt >= where.OR[1].lastCheckedAt.lt)) return { count: 0 };
        intents.set(where.id, { ...value, ...data }); return { count: 1 };
      },
    },
    posPaymentCollection: { create: async ({ data }: Row) => {
      assert(!collections.has(data.id)); collections.set(data.id, data); return data;
    } },
    invoiceSequence:{upsert:async()=>({nextNumber:1})},
  };
  const db = { ...tx, $transaction: async (work: (t: unknown) => Promise<unknown>) => {
    const before = { sale: { ...sale }, intents: new Map([...intents].map(([k,v]) => [k,{...v}])), collections: new Map(collections),stockConsumes };
    try { return await work(tx); } catch (error) {
      sale = before.sale; intents = before.intents; collections = before.collections; stockConsumes=before.stockConsumes; throw error;
    }
  } } as unknown as PrismaClient;
  const gateway: FonepayGateway = { environment, merchantCode: 'FIXTURE-MERCHANT',
    create: async (request: FonepayRequest) => {
      creates++;
      if (failCreate) throw new Error('TEST transport interruption');
      assert.equal(request.amount, npr(paisa(sale.total.toString()) - paisa(sale.paidAmount.toString())));
      return { ...request, merchantName: 'TEST FIXTURE STORE', payload: 'TEST-ONLY-NONPAYABLE-QR', expiresAt: new Date(Date.now() + 60000) };
    },
    verify: async (request) => {
      verifies++;
      return { ...request, environment, authenticated: true, status: 'SUCCESS', transactionId: 'TEST-TRANSACTION', ...change };
    },
    cancel: async () => {},
  };
  return { service: new FonepayPayments(db, gateway,{consumeStockForPosSale:async()=>{
    if(failFinalize) throw new Error('TEST stock unavailable'); stockConsumes++;
  }}), db, gateway,
    get sale() { return sale; }, get collections() { return collections; },
    get creates() { return creates; }, get verifies() { return verifies; },
    get stockConsumes(){return stockConsumes;},
    checkout:()=>{sale.status='CHECKOUT';sale.invoiceNumber=null;sale.paidAmount=new Prisma.Decimal(0);},
    failFinalization:(value:boolean)=>{failFinalize=value;},
    setProof: (value: Partial<FonepayVerification>) => { change = value; },
    fail: () => { failCreate = true; },
    changeBill: () => { sale.total = new Prisma.Decimal('114.01'); sale.updatedAt = new Date(); },
    newBill: () => { sale = { ...sale, id:'sale-2', invoiceNumber:'RPGS-TEST-2',
      paymentStatus:'PENDING', paidAmount:new Prisma.Decimal('13'), updatedAt:new Date() }; },
    expire: (id: string) => { intents.get(id)!.expiresAt = new Date('2020-01-01'); },
  };
}
async function main() {
  assert.equal(paisa('100.01'), 10001n); assert.equal(npr(1n), '0.01');
  assert.throws(() => paisa('1.001')); assert.throws(() => paisa('1e3')); assert.throws(() => paisa('-1'));
  const f = fixture();
  const intent = await f.service.create('sale-1', actor);
  assert.equal(intent.amount.toFixed(2), '100.01');
  assert.equal(intent.state, 'READY'); assert.equal(f.creates, 1);
  assert.equal((await f.service.create('sale-1', actor)).id, intent.id); assert.equal(f.creates, 1);
  assert.equal((await f.service.verify(intent.id, actor)).state, 'PAID');
  assert.equal((await f.service.verify(intent.id, actor)).state, 'PAID');
  assert.equal(f.collections.size, 1); assert.equal(f.verifies, 1);
  assert.equal(f.sale.paidAmount.toFixed(2), '113.01');
  assert.equal(publicFonepayRequest(await f.service.get(intent.id, actor)).qrPayload, null);
  f.newBill();
  const second = await f.service.create('sale-2', actor);
  assert.equal((await f.service.verify(second.id, actor)).state, 'REVIEW');
  assert.equal(f.collections.size, 1);
  assert.equal(f.sale.paymentStatus, 'PENDING');
  assert.equal(f.sale.paidAmount.toFixed(2), '13.00');
  for (const mismatch of [{ amount: '100.02' }, {amount:'1e3'}, { merchantCode: 'WRONG' }, { reference: 'WRONG' },
    { currency: 'USD' }, { environment: 'sandbox' as const }, { authenticated: false }]) {
    const wrong = fixture(); const value = await wrong.service.create('sale-1', actor);
    wrong.setProof(mismatch);
    assert.equal((await wrong.service.verify(value.id, actor)).state, 'REVIEW');
    assert.equal(wrong.collections.size, 0); assert.equal(wrong.sale.paidAmount.toFixed(2), '13.00');
  }
  const sandbox = fixture('sandbox'); const testIntent = await sandbox.service.create('sale-1', actor);
  assert.equal((await sandbox.service.verify(testIntent.id, actor)).state, 'TEST_VERIFIED');
  assert.equal(sandbox.collections.size, 0); assert.equal(sandbox.sale.paymentStatus, 'PENDING');
  const checkout=fixture(); checkout.checkout();
  const checkoutIntent=await checkout.service.create('sale-1',actor);
  assert.equal(checkout.sale.status,'CHECKOUT');assert.equal(checkout.stockConsumes,0);
  assert.equal(checkout.collections.size,0);assert.equal(checkout.sale.invoiceNumber,null);
  assert.equal((await checkout.service.verify(checkoutIntent.id,actor)).state,'VERIFIED');
  assert.equal(checkout.sale.status,'CHECKOUT');assert.equal(checkout.collections.size,0);
  checkout.failFinalization(true);
  await assert.rejects(checkout.service.finalize(checkoutIntent.id,actor),/stock unavailable/);
  assert.equal((await checkout.service.get(checkoutIntent.id,actor)).state,'VERIFIED');
  assert.equal(checkout.sale.invoiceNumber,null);assert.equal(checkout.stockConsumes,0);
  checkout.failFinalization(false);
  const finalBill=await checkout.service.finalize(checkoutIntent.id,actor);
  assert.equal(finalBill.status,'COMPLETED');assert.equal(finalBill.paymentMethod,'FONEPAY');
  assert.equal(finalBill.paidAmount.toFixed(2),'113.01');assert.ok(finalBill.invoiceNumber);
  assert.equal((await checkout.service.finalize(checkoutIntent.id,actor)).id,finalBill.id);
  assert.equal(checkout.collections.size,1);assert.equal(checkout.stockConsumes,1);
  assert.equal(await checkout.service.claimAutoPrint(checkoutIntent.id,actor),true);
  assert.equal(await checkout.service.claimAutoPrint(checkoutIntent.id,actor),false);
  assert.equal(checkout.verifies,1);
  await assert.rejects(sandbox.service.finalize(testIntent.id,actor),/backend-verified live/);
  const expired = fixture(); const expiredIntent = await expired.service.create('sale-1', actor);
  expired.expire(expiredIntent.id);
  assert.equal((await expired.service.get(expiredIntent.id, actor)).state, 'EXPIRED');
  assert.equal((await expired.service.verify(expiredIntent.id, actor)).state, 'REVIEW');
  assert.equal(expired.collections.size, 0);
  const locallyExpired=fixture();const locallyExpiredIntent=await locallyExpired.service.create('sale-1',actor);
  locallyExpired.expire(locallyExpiredIntent.id);locallyExpired.setProof({status:'PENDING'});
  await locallyExpired.service.verify(locallyExpiredIntent.id,actor);
  await assert.rejects(locallyExpired.service.create('sale-1',actor),/previous payment request/);
  const polling = fixture(); const pendingIntent = await polling.service.create('sale-1', actor);
  polling.setProof({status:'PENDING'});
  await polling.service.verify(pendingIntent.id, actor);
  await polling.service.verify(pendingIntent.id, actor);
  assert.equal(polling.verifies, 1);
  const revised = fixture(); const old = await revised.service.create('sale-1', actor);
  revised.changeBill();
  assert.equal((await revised.service.get(old.id, actor)).state, 'STALE');
  await assert.rejects(revised.service.create('sale-1', actor), /previous payment request/);
  assert.equal((await revised.service.verify(old.id, actor)).state, 'REVIEW');
  assert.equal(revised.collections.size, 0);
  const cancelled = fixture(); const cancelIntent = await cancelled.service.create('sale-1', actor);
  assert.equal((await cancelled.service.cancel(cancelIntent.id, actor)).state, 'CANCELLED');
  assert.equal((await cancelled.service.verify(cancelIntent.id, actor)).state, 'REVIEW');
  assert.equal(cancelled.collections.size, 0);
  const unsupported = fixture(); delete unsupported.gateway.cancel;
  const unsupportedIntent = await unsupported.service.create('sale-1', actor);
  await assert.rejects(unsupported.service.cancel(unsupportedIntent.id, actor), /Remote cancellation/);
  assert.equal((await unsupported.service.create('sale-1', actor)).id, unsupportedIntent.id);
  const unknown = fixture(); unknown.fail(); const uncertain = await unknown.service.create('sale-1', actor);
  assert.equal(uncertain.state, 'UNKNOWN');
  assert.equal((await unknown.service.create('sale-1', actor)).id, uncertain.id); assert.equal(unknown.creates, 1);
  const staff = fixture(); await assert.rejects(staff.service.create('sale-1', { id: 'another', role: 'BILLING_STAFF' }), /not accessible/);
  for (const status of ['PENDING', 'FAILED', 'EXPIRED', 'CANCELLED'] as const) {
    const terminal = fixture(); const value = await terminal.service.create('sale-1', actor);
    terminal.setProof({ status });
    assert.equal((await terminal.service.verify(value.id, actor)).state, status);
    assert.equal(terminal.collections.size, 0);
  }
  // Public routes remain fail-closed even if deployment secrets are present.
  const app = express(); app.use(express.json()); app.use((_, res, next) => {
    res.locals.authenticatedUserId = actor.id; res.locals.authenticatedUserRole = 'ADMIN'; next();
  }); app.use('/fonepay', createFonepayRouter({} as PrismaClient));
  const server = app.listen(0); await new Promise<void>(resolve => server.once('listening', resolve));
  try {
    const address = server.address(); assert(address && typeof address !== 'string');
    const base = `http://127.0.0.1:${address.port}/fonepay`;
    assert.equal((await (await fetch(`${base}/config`)).json() as Row).enabled, false);
    assert.equal((await fetch(`${base}/sales/test/requests`, { method:'POST', headers:{'content-type':'application/json'}, body:'{}' })).status, 503);
    assert.equal((await fetch(`${base}/requests/test/verify`, { method:'POST', headers:{'content-type':'application/json'}, body:'{"status":"SUCCESS","amount":"1.00"}' })).status, 400);
  } finally { await new Promise<void>(resolve => server.close(() => resolve())); }
  console.log('Fonepay orchestration TEST FIXTURES passed: exact money, verified fields, once-only collection, stale/cancelled QR, test isolation, unknown retries, ownership and disabled public adapter. NOT Fonepay UAT certification.');
}
main().catch(error => { console.error(error); process.exitCode=1; });
