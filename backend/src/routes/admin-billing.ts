import { randomInt, randomUUID } from 'node:crypto';
import { Router, type RequestHandler } from 'express';
import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { sendAdminError } from '../middleware/auth.js';
import { InventoryAdjustmentError, InventoryService } from '../services/inventory.js';
import {
  getLocalDayRange,
  getLocalDayRangeForKey,
  getStoreDayKey,
} from '../services/local-day.js';
import { isWeightUnitLabel } from '../services/product-validation.js';
import { runTransactionWithRetry } from '../services/transaction-retry.js';
import { recordBuyingStreakPurchase } from '../services/buying-streak.js';
import { serializeSale } from '../services/pos-sale-serializer.js';
import { manualFonepayNote, manualFonepayReference, manualPaymentProvider } from '../services/manual-fonepay.js';
import { createRoomInventoryRouter } from './admin-rooms.js';
import { RoomInventoryError } from '../services/room-inventory.js';
import { applyPosPriceChanges, priceChangesInput } from '../services/pos-price-changes.js';

const saleItemsInput = z.array(z.object({
  productId: z.string().trim().min(1).max(100),
  quantity: z.number().int().min(1).max(100000),
  weightGrams: z.number().int().min(1).max(1000000).nullable().optional(),
  manualName: z.string().trim().max(180).optional(),
  manualPrice: z.number().finite().positive().max(9999999)
    .refine(v => Math.abs(v * 100 - Math.round(v * 100)) < 0.000001).optional(),
}).strict().superRefine((item, context) => {
  const manual = /^manual-[a-f0-9-]{36}$/i.test(item.productId);
  if (manual ? item.manualPrice == null || item.weightGrams != null : item.manualPrice != null || item.manualName != null) {
    context.addIssue({ code: 'custom', message: 'Manual items require a price and cannot use inventory or weight.' });
  }
})).min(1).max(100);

const saleInput = z.object({
  cataloguePriceChanges: priceChangesInput.optional(),
  items: saleItemsInput,
  roomPicks: z.array(z.object({ productId: z.string().min(1).max(100), roomId: z.string().min(1).max(100).nullable(), quantity: z.number().int().positive().max(2147483647) }).strict()).min(1).max(500).optional(),
  idempotencyKey: z.string().uuid().optional(),
  discount: z.number().finite().min(0).max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100)))
    .default(0),
  vatRate: z.number().finite().min(0).max(100).default(0),
  paymentMethod: z.enum(['CASH', 'DIGITAL', 'PENDING', 'FONEPAY', 'ESEWA']),
  manualVerification: z.object({
    verificationMethod: z.literal('MANUAL'), confirmed: z.literal(true),
    transactionReference: z.string().trim().min(1).max(120),
  }).strict().optional(),
  paidAmount: z.number().finite().min(0).max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100)))
    .optional(),
  paidNowMethod: z.enum(['CASH', 'DIGITAL']).default('CASH'),
  customerName: z.string().trim().max(120).nullable().optional(),
  customerPhone: z.string().trim().regex(/^9[78]\d{8}$/).nullable().optional(),
  customerId: z.string().trim().min(1).max(100).nullable().optional(),
  heldSaleId: z.string().trim().min(1).max(100).nullable().optional(),
  quote: z.object({
    expectedTotal: z.number().finite().nonnegative(),
    unitPrices: z.record(z.string(), z.number().finite().nonnegative()),
  }).strict().optional(),
  offlineSale: z.object({
    invoiceNumber: z.string().regex(/^RPGS-INV-\d{4}-L-[A-F0-9]{32}$/),
    occurredAt: z.string().datetime(),
    expectedTotal: z.number().finite().nonnegative(),
    unitPrices: z.record(z.string(), z.number().finite().nonnegative()),
  }).strict().optional(),
}).strict().superRefine((sale, context) => {
  if (sale.manualVerification && (!['FONEPAY', 'ESEWA'].includes(sale.paymentMethod) || !sale.idempotencyKey || !sale.quote || sale.offlineSale)) {
    context.addIssue({ code: 'custom', path: ['manualVerification'], message: 'Manual Fonepay requires a cashier checkout with an idempotency key and exact quote.' });
  }
  if (sale.paymentMethod === 'ESEWA' && !sale.manualVerification) {
    context.addIssue({ code: 'custom', path: ['manualVerification'], message: 'Confirm payment received before creating an eSewa bill.' });
  }
});

const holdInput = z.object({
  items: z.array(z.object({
    productId: z.string().trim().min(1).max(100),
    quantity: z.number().int().min(1).max(100000),
    weightGrams: z.number().int().min(1).max(1000000).nullable().optional(),
    productName: z.string().trim().min(1).max(180),
    sku: z.string().trim().min(1).max(80),
    price: z.number().finite().nonnegative().max(999999999),
    cataloguePrice: z.number().finite().nonnegative().max(999999999).optional(),
    unitLabel: z.string().trim().max(50),
  }).strict()).min(1).max(100),
  customerName: z.string().trim().max(120).nullable().optional(),
  customerPhone: z.string().trim().regex(/^9[78]\d{8}$/).nullable().optional(),
  customerId: z.string().trim().min(1).max(100).nullable().optional(),
}).strict();

const cashMovementInput = z.object({
  type: z.enum(['CASH_IN', 'CASH_OUT']),
  amount: z.number().finite().positive().max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100))),
  note: z.string().trim().min(1).max(240),
}).strict();

const refundInput = z.object({
  amount: z.number().finite().positive().max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100)) && Math.round(value * 100) >= 1),
  reason: z.string().trim().min(2).max(500),
  restockStock: z.boolean().default(false),
}).strict();

const refundResolutionInput = z.object({
  decision: z.enum(['APPROVE', 'REJECT']),
}).strict();

const paymentInput = z.object({
  paymentMethod: z.enum(['CASH', 'DIGITAL']),
}).strict();
const paymentCollectionInput = z.object({
  idempotencyKey: z.string().uuid().optional(),
  amount: z.number().finite().positive().max(999999999)
    .refine((value) =>
      Number.isSafeInteger(Math.round(value * 100)) &&
      Math.round(value * 100) >= 1),
  paymentMethod: z.enum(['CASH', 'DIGITAL']),
  note: z.string().trim().max(240).nullable().optional(),
}).strict();

const exchangeQuantityFields = {
  quantity: z.number().int().min(1).max(100000).optional(),
  weightGrams: z.number().int().min(1).max(1000000).optional(),
};

const exchangeInput = z.object({
  idempotencyKey: z.string().uuid(),
  returnedItems: z.array(z.object({
    ...exchangeQuantityFields,
    saleItemId: z.string().trim().min(1).max(100),
  }).strict().refine(
    (value) => (value.quantity === undefined) !== (value.weightGrams === undefined),
  )).min(1).max(100),
  replacementItems: z.array(z.object({
    ...exchangeQuantityFields,
    productId: z.string().trim().min(1).max(100),
  }).strict().refine(
    (value) => (value.quantity === undefined) !== (value.weightGrams === undefined),
  )).max(100).default([]),
  paymentMethod: z.enum(['CASH', 'DIGITAL']).optional(),
  restockReturnedItems: z.boolean().default(true),
  reason: z.string().trim().max(500).optional(),
}).strict();

const exchangeResolutionInput = z.object({
  decision: z.enum(['APPROVE', 'REJECT']),
  refundPaymentMethod: z.enum(['CASH', 'DIGITAL']).optional(),
}).strict();

function authenticatedAdminId(res: Parameters<RequestHandler>[1]): string | null {
  const id = res.locals.authenticatedUserId;
  return typeof id === 'string' ? id : null;
}

function authenticatedRole(res: Parameters<RequestHandler>[1]): string | null {
  const role = res.locals.authenticatedUserRole;
  return typeof role === 'string' ? role : null;
}

const offlineStreakPurchaseInput = z.object({
  customerId: z.string().trim().min(1).max(100),
  invoiceNumber: z.string().trim().regex(/^RPGS-INV-\d{4}-\d{6,}$/),
}).strict();

async function findOrCreateOpenShift(
  tx: Prisma.TransactionClient,
  cashierId: string,
) {
  const shift = await tx.posShift.findFirst({
    where: { cashierId, status: 'OPEN' },
    select: { id: true, openingCash: true },
  });

  if (shift) return shift;
  return tx.posShift.create({
    data: { cashierId, openingCash: 0 },
    select: { id: true, openingCash: true },
  });
}

function roundMoney(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}


export function createAdminBillingRouter(
  prisma: PrismaClient,
  inventoryService: InventoryService,
  requireAdmin?: RequestHandler,
): Router {
  const router = Router();
  const adminOnly: RequestHandler = requireAdmin ?? ((_req, res) => {
    res.status(403).json({ error: 'Administrator access required.' });
  });
  router.use('/rooms', createRoomInventoryRouter(prisma, adminOnly));
  router.post('/catalogue-price-changes', adminOnly, async (req, res) => {
    const parsed = z.object({ requestId: z.string().uuid(), changes: priceChangesInput }).strict().safeParse(req.body);
    const cashierId = authenticatedAdminId(res);
    if (!parsed.success || !cashierId) return res.status(400).json({ error: 'Invalid price change.' });
    try {
      await runTransactionWithRetry(prisma, tx => applyPosPriceChanges(tx, parsed.data.requestId, cashierId, parsed.data.changes));
      return res.json({ saved: true });
    } catch (error) {
      if (error instanceof Error && error.message === 'POS_QUOTE_CHANGED') return res.status(409).json({ error: 'The catalogue price has changed. Review this price update before retrying.' });
      return sendAdminError(error, res);
    }
  });

  router.post('/scanner-sessions', adminOnly, async (req, res) => {
    const ownerId = authenticatedAdminId(res);
    if (!ownerId) return res.status(401).json({ error: 'Sign in again to pair a camera.' });
    try {
      await prisma.barcodeScannerSession.deleteMany({
        where: { expiresAt: { lte: new Date() } },
      });
      let code = '';
      for (let attempt = 0; attempt < 5; attempt += 1) {
        code = String(randomInt(0, 100_000_000)).padStart(8, '0');
        try {
          await prisma.barcodeScannerSession.create({
            data: {
              code,
              ownerId,
              // Pairing remains active until explicitly disconnected. Keep a
              // far-future expiry so existing expiry filters and cleanup work.
              expiresAt: new Date('9999-12-31T23:59:59.999Z'),
            },
          });
          return res.status(201).json({ code, expiresInSeconds: null });
        } catch (error) {
          if (!(error instanceof Prisma.PrismaClientKnownRequestError) ||
            error.code !== 'P2002') throw error;
        }
      }
      return res.status(503).json({ error: 'Could not create a unique pairing code. Try again.' });
    } catch (error) {
      sendAdminError(error, res);
      return undefined;
    }
  });

  router.delete('/scanner-sessions/:code', adminOnly, async (req, res) => {
    const ownerId = authenticatedAdminId(res);
    const code = String(req.params.code ?? '');
    if (!ownerId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      await prisma.barcodeScannerSession.deleteMany({ where: { code, ownerId } });
      return res.json({ disconnected: true });
    } catch (error) {
      sendAdminError(error, res);
      return undefined;
    }
  });

  router.get('/scanner-sessions/:code/next', adminOnly, async (req, res) => {
    const ownerId = authenticatedAdminId(res);
    const code = String(req.params.code ?? '');
    if (!ownerId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const session = await prisma.barcodeScannerSession.findFirst({
        where: { code, ownerId, expiresAt: { gt: new Date() } },
      });
      if (!session) return res.status(410).json({ error: 'Camera pairing expired. Create a new code.' });
      if (!session.barcode) return res.json({ barcode: null });
      const barcode = session.barcode;
      const consumed = await prisma.barcodeScannerSession.updateMany({
        where: { code, ownerId, barcode },
        data: { barcode: null },
      });
      return res.json({ barcode: consumed.count ? barcode : null });
    } catch (error) {
      sendAdminError(error, res);
      return undefined;
    }
  });

  router.post('/scanner-sessions/:code/join', adminOnly, async (req, res) => {
    const ownerId = authenticatedAdminId(res);
    const code = String(req.params.code ?? '');
    if (!ownerId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const result = await prisma.barcodeScannerSession.updateMany({
        where: {
          code,
          ownerId,
          expiresAt: { gt: new Date() },
        },
        data: { connectedAt: new Date() },
      });
      if (!result.count) return res.status(410).json({ error: 'Pairing code is invalid or expired.' });
      return res.json({ connected: true });
    } catch (error) {
      sendAdminError(error, res);
      return undefined;
    }
  });

  router.post('/scanner-sessions/:code/scan', adminOnly, async (req, res) => {
    const parsed = z.object({
      barcode: z.string().trim().min(1).max(128),
    }).strict().safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Enter a valid barcode.' });
    const ownerId = authenticatedAdminId(res);
    const code = String(req.params.code ?? '');
    if (!ownerId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const result = await prisma.barcodeScannerSession.updateMany({
        where: {
          code,
          ownerId,
          connectedAt: { not: null },
          expiresAt: { gt: new Date() },
        },
        data: { barcode: parsed.data.barcode },
      });
      if (!result.count) return res.status(410).json({ error: 'Pairing code is invalid or expired.' });
      return res.status(202).json({ accepted: true });
    } catch (error) {
      sendAdminError(error, res);
      return undefined;
    }
  });

  router.get('/staff', adminOnly, async (req, res) => {
    const parsed = z.string().trim().max(100).safeParse(req.query.query ?? '');
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid staff search.' });
    }
    const query = parsed.data;
    if (query.length === 1) {
      return res.status(400).json({ error: 'Search with at least two characters.' });
    }
    try {
      const users = await prisma.user.findMany({
        where: {
          emailVerified: true,
          role: query
            ? { in: ['CUSTOMER', 'BILLING_STAFF'] }
            : 'BILLING_STAFF',
          ...(query
            ? {
              OR: [
                { name: { contains: query } },
                { email: { contains: query } },
              ],
            }
            : {}),
        },
        orderBy: { name: 'asc' },
        take: 30,
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          isActive: true,
          emailVerified: true,
        },
      });
      return res.json({ staff: users });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.patch('/staff/:id', adminOnly, async (req, res) => {
    const parsed = z.object({
      role: z.enum(['CUSTOMER', 'BILLING_STAFF']),
    }).strict().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose a valid billing staff role.' });
    }
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.params.id },
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          isActive: true,
          emailVerified: true,
        },
      });
      if (!user || (user.role !== 'CUSTOMER' && user.role !== 'BILLING_STAFF')) {
        return res.status(404).json({ error: 'Eligible staff account not found.' });
      }
      if (parsed.data.role === 'BILLING_STAFF' &&
        (!user.isActive || !user.emailVerified)) {
        return res.status(409).json({
          error: 'Only active, verified accounts can be billing staff.',
        });
      }
      const updated = await prisma.user.updateMany({
        where: {
          id: user.id,
          role: user.role,
          ...(parsed.data.role === 'BILLING_STAFF'
            ? { isActive: true, emailVerified: true }
            : {}),
        },
        data: {
          role: parsed.data.role,
          tokenVersion: { increment: 1 },
        },
      });
      if (updated.count !== 1) {
        return res.status(409).json({
          error: 'This account changed while you were updating access. Refresh and retry.',
        });
      }
      return res.json({
        staff: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: parsed.data.role,
          isActive: user.isActive,
          emailVerified: user.emailVerified,
        },
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/overview', async (req, res) => {
    const day = typeof req.query.day === 'string' ? req.query.day : undefined;
    let range: ReturnType<typeof getLocalDayRange>;
    try {
      range = day ? getLocalDayRangeForKey(day) : getLocalDayRange();
    } catch {
      return res.status(400).json({ error: 'Choose a valid store calendar day.' });
    }
    try {
      const cashierId = authenticatedAdminId(res);
      const isBillingStaff = authenticatedRole(res) === 'BILLING_STAFF';
      if (isBillingStaff && !cashierId) {
        return res.status(401).json({ error: 'Authentication is required.' });
      }
      const saleScope: Prisma.PosSaleWhereInput =
        isBillingStaff && cashierId ? { shift: { cashierId } } : {};
      const [
        currentShift,
        sales,
        paymentCollections,
        cashier,
        groupedTopProducts,
        products,
        openRefundCount,
        openExchangeRefundCount,
        cancelledBills,
      ] = await Promise.all([
        prisma.posShift.findFirst({
          where: {
            status: 'OPEN',
            ...(cashierId ? { cashierId } : {}),
          },
          orderBy: { openedAt: 'desc' },
          include: { cashier: { select: { id: true, name: true } } },
        }),
        prisma.posSale.findMany({
          where: {
            createdAt: { gte: range.start, lt: range.end },
            status: { notIn: ['CANCELLED', 'CHECKOUT'] },
            ...saleScope,
          },
          select: {
            total: true,
            paymentMethod: true,
            paymentStatus: true,
            paidAmount: true,
            status: true,
            refundedAmount: true,
            paymentCollections: {
              select: { amount: true, method: true },
            },
          },
        }),
        prisma.posPaymentCollection.findMany({
          where: {
            createdAt: { gte: range.start, lt: range.end },
            ...(isBillingStaff && cashierId
              ? { sale: { shift: { cashierId } } }
              : {}),
          },
          select: { amount: true, method: true },
        }),
        cashierId
          ? prisma.user.findUnique({
            where: { id: cashierId },
            select: { id: true, name: true },
          })
          : Promise.resolve(null),
        prisma.posSaleItem.groupBy({
          by: ['productId'],
          where: {
            sale: {
              createdAt: { gte: range.start, lt: range.end },
              status: { notIn: ['CANCELLED', 'CHECKOUT'] },
              ...saleScope,
            },
            productId: { not: null },
          },
          _sum: { quantity: true },
          orderBy: { _sum: { quantity: 'desc' } },
          take: 5,
        }),
        prisma.product.findMany({
          where: { isActive: true },
          select: {
            id: true,
            name: true,
            unitLabel: true,
            lowStockThreshold: true,
            inventory: { select: { totalStock: true, reservedStock: true } },
          },
        }),
        isBillingStaff
          ? Promise.resolve(0)
          : prisma.posRefund.count({ where: { status: 'REQUESTED' } }),
        prisma.posExchange.count({
          where: {
            status: 'REFUND_REQUESTED',
            ...(isBillingStaff && cashierId
              ? { cashierId }
              : {}),
          },
        }),
        prisma.posSale.count({
          where: {
            createdAt: { gte: range.start, lt: range.end },
            status: 'CANCELLED',
            ...saleScope,
          },
        }),
      ]);
      const exchanges = await prisma.posExchange.findMany({
        where: {
          requestedAt: { gte: range.start, lt: range.end },
          status: { in: ['COMPLETED', 'REFUND_APPROVED'] },
          ...(isBillingStaff && cashierId ? { cashierId } : {}),
        },
        select: {
          difference: true,
          paymentMethod: true,
          refundPaymentMethod: true,
        },
      });
      const exchangeNet = exchanges.reduce(
        (sum, exchange) => sum + Number(exchange.difference),
        0,
      );
      const totalSales = roundMoney(
        sales.reduce((sum, sale) => sum + Number(sale.total), 0) +
        exchangeNet,
      );
      const cashSales = paymentCollections
        .filter((payment) => payment.method === 'CASH')
        .reduce((sum, payment) => sum + Number(payment.amount), 0) +
        sales
          .filter((sale) =>
            sale.paymentCollections.length === 0 &&
            sale.paymentStatus === 'COMPLETED' &&
            sale.paymentMethod === 'CASH',
          )
          .reduce((sum, sale) => sum + Number(sale.total), 0) +
        exchanges.reduce((sum, exchange) => {
          const difference = Number(exchange.difference);
          if (difference > 0 && exchange.paymentMethod === 'CASH') {
            return sum + difference;
          }
          if (difference < 0 && exchange.refundPaymentMethod === 'CASH') {
            return sum + difference;
          }
          return sum;
        }, 0);
      const digitalSales = paymentCollections
        .filter((payment) => ['DIGITAL', 'FONEPAY', 'ESEWA'].includes(payment.method))
        .reduce((sum, payment) => sum + Number(payment.amount), 0) +
        sales
          .filter((sale) =>
            sale.paymentCollections.length === 0 &&
            sale.paymentStatus === 'COMPLETED' &&
            ['DIGITAL', 'FONEPAY', 'ESEWA'].includes(sale.paymentMethod),
          )
          .reduce((sum, sale) => sum + Number(sale.total), 0) +
        exchanges.reduce((sum, exchange) => {
          const difference = Number(exchange.difference);
          if (difference > 0 && exchange.paymentMethod === 'DIGITAL') {
            return sum + difference;
          }
          if (difference < 0 && exchange.refundPaymentMethod === 'DIGITAL') {
            return sum + difference;
          }
          return sum;
        }, 0);
      const pendingSales = sales
        .filter((sale) => sale.paymentStatus === 'PENDING')
        .reduce((sum, sale) =>
          sum + Number(sale.total) - Number(sale.paidAmount), 0);
      const topProductIds = groupedTopProducts
        .map((entry) => entry.productId)
        .filter((id): id is string => id !== null);
      const topProducts = products
        .filter((product) => topProductIds.includes(product.id))
        .map((product) => ({
          productId: product.id,
          name: product.name,
          sold: groupedTopProducts.find((entry) => entry.productId === product.id)
            ?._sum.quantity ?? 0,
        }))
        .sort((left, right) => right.sold - left.sold);
      const lowStock = products
        .filter((product) => {
          const available = Math.max(
            0,
            (product.inventory?.totalStock ?? 0) -
            (product.inventory?.reservedStock ?? 0),
          );
          const threshold = isWeightUnitLabel(product.unitLabel)
            ? product.lowStockThreshold * 1000
            : product.lowStockThreshold;
          return available <= threshold;
        })
        .map((product) => ({
          productId: product.id,
          name: product.name,
          available: Math.max(
            0,
            (product.inventory?.totalStock ?? 0) -
            (product.inventory?.reservedStock ?? 0),
          ),
          unitLabel: product.unitLabel,
        }));
      let expectedClosingCash: number | null = null;
      if (currentShift) {
        const [shiftSales, shiftMovements, shiftExchanges] = await Promise.all([
          prisma.posSale.findMany({
            where: { shiftId: currentShift.id, status: { notIn: ['CANCELLED', 'CHECKOUT'] } },
            select: {
              total: true,
              paymentMethod: true,
              paymentCollections: {
                select: { amount: true, method: true },
              },
              refunds: {
                where: { status: 'APPROVED' },
                select: { amount: true },
              },
            },
          }),
          prisma.posCashMovement.findMany({
            where: { shiftId: currentShift.id },
            select: { type: true, amount: true },
          }),
          prisma.posExchange.findMany({
            where: {
              shiftId: currentShift.id,
              status: { in: ['COMPLETED', 'REFUND_APPROVED'] },
            },
            select: {
              difference: true,
              paymentMethod: true,
              refundPaymentMethod: true,
            },
          }),
        ]);
        expectedClosingCash = roundMoney(
          Number(currentShift.openingCash) +
          shiftSales.reduce((sum, sale) => {
            const receivedCash = sale.paymentCollections.length > 0
              ? sale.paymentCollections
                .filter((payment) => payment.method === 'CASH')
                .reduce((amount, payment) => amount + Number(payment.amount), 0)
              : sale.paymentMethod === 'CASH' ? Number(sale.total) : 0;
            const refunds = sale.refunds.reduce(
              (amount, refund) => amount + Number(refund.amount),
              0,
            );
            return sum + receivedCash - refunds;
          }, 0) +
          shiftExchanges.reduce((sum, exchange) => {
            const difference = Number(exchange.difference);
            if (difference > 0 && exchange.paymentMethod === 'CASH') {
              return sum + difference;
            }
            if (difference < 0 && exchange.refundPaymentMethod === 'CASH') {
              return sum + difference;
            }
            return sum;
          }, 0) +
          shiftMovements.reduce(
            (sum, movement) => sum +
              (movement.type === 'CASH_IN' ? 1 : -1) * Number(movement.amount),
            0,
          ),
        );
      }
      const completedBills = sales.filter((sale) =>
        ['COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED'].includes(sale.status),
      ).length;
      return res.json({
        day: day ?? getStoreDayKey(new Date()),
        cashier,
        currentShift: currentShift
          ? {
            id: currentShift.id,
            cashier: currentShift.cashier,
            openingCash: Number(currentShift.openingCash),
            expectedClosingCash,
            openedAt: currentShift.openedAt.toISOString(),
          }
          : null,
        metrics: {
          totalSales: roundMoney(totalSales),
          completedBills,
          averageBillValue: completedBills === 0
            ? 0
            : roundMoney(totalSales / completedBills),
          cashSales: roundMoney(cashSales),
          digitalSales: roundMoney(digitalSales),
          pendingSales: roundMoney(pendingSales),
          refunds: roundMoney(
            sales.reduce((sum, sale) => sum + Number(sale.refundedAmount), 0) +
            exchanges.reduce(
              (sum, exchange) => sum + Math.max(0, -Number(exchange.difference)),
              0,
            ),
          ),
          cancelledBills,
          openRefundRequests: openRefundCount + openExchangeRefundCount,
        },
        topProducts,
        lowStock,
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/cash-movements', async (req, res) => {
    const actorId = authenticatedAdminId(res);
    if (!actorId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = cashMovementInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid cash movement and note.' });
    }
    try {
      const movement = await runTransactionWithRetry(prisma, async (tx) => {
        const shift = await findOrCreateOpenShift(tx, actorId);
        const [sales, movements] = await Promise.all([
          tx.posSale.findMany({
            where: { shiftId: shift.id, status: { notIn: ['CANCELLED', 'CHECKOUT'] } },
            select: {
              total: true,
              paymentMethod: true,
              refunds: {
                where: { status: 'APPROVED' },
                select: { amount: true },
              },
            },
          }),
          tx.posCashMovement.findMany({
            where: { shiftId: shift.id },
            select: { type: true, amount: true },
          }),
        ]);
        const expected = roundMoney(
          Number(shift.openingCash) +
          sales.reduce((sum, sale) => {
            if (sale.paymentMethod !== 'CASH') return sum;
            return sum + Number(sale.total) - sale.refunds.reduce(
              (refundSum, refund) => refundSum + Number(refund.amount),
              0,
            );
          }, 0) +
          movements.reduce(
            (sum, item) => sum +
              (item.type === 'CASH_IN' ? 1 : -1) * Number(item.amount),
            0,
          ),
        );
        if (parsed.data.type === 'CASH_OUT' && parsed.data.amount > expected) {
          throw new Error('POS_CASH_OUT_EXCEEDS_DRAWER');
        }
        return tx.posCashMovement.create({
          data: { ...parsed.data, shiftId: shift.id, actorId },
        });
      });
      return res.status(201).json({
        movement: {
          id: movement.id,
          type: movement.type,
          amount: Number(movement.amount),
          note: movement.note,
          createdAt: movement.createdAt.toISOString(),
        },
      });
    } catch (error) {
      if (error instanceof Error && error.message === 'POS_CASH_OUT_EXCEEDS_DRAWER') {
        return res.status(409).json({ error: 'Cash out cannot exceed the expected drawer balance.' });
      }
      sendAdminError(error, res);
    }
  });

  router.post('/offline-streak-purchases', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = offlineStreakPurchaseInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter the registered customer and local invoice number.' });
    }
    try {
      const result = await runTransactionWithRetry(prisma, async (tx) => {
        const existing = await tx.posOfflineStreakPurchase.findUnique({
          where: { invoiceNumber: parsed.data.invoiceNumber },
          select: { userId: true },
        });
        if (existing) {
          if (existing.userId !== parsed.data.customerId) {
            throw new Error('POS_OFFLINE_INVOICE_REUSED');
          }
          return { recorded: false };
        }
        const user = await tx.user.findFirst({
          where: {
            id: parsed.data.customerId,
            isActive: true,
            role: 'CUSTOMER',
          },
          select: { id: true },
        });
        if (!user) throw new Error('POS_CUSTOMER_UNAVAILABLE');
        await tx.posOfflineStreakPurchase.create({
          data: {
            invoiceNumber: parsed.data.invoiceNumber,
            userId: user.id,
          },
        });
        await recordBuyingStreakPurchase(tx, user.id, new Date());
        return { recorded: true };
      });
      return res.status(200).json(result);
    } catch (error) {
      if (error instanceof Error && error.message === 'POS_CUSTOMER_UNAVAILABLE') {
        return res.status(404).json({ error: 'The selected customer is no longer active.' });
      }
      if (error instanceof Error && error.message === 'POS_OFFLINE_INVOICE_REUSED') {
        return res.status(409).json({ error: 'That local invoice number belongs to a different customer.' });
      }
      sendAdminError(error, res);
    }
  });

  router.get('/held-sales', async (_req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const shift = await prisma.posShift.findFirst({
        where: { cashierId, status: 'OPEN' },
        select: { id: true },
      });
      if (!shift) return res.json({ heldSales: [] });
      const heldSales = await prisma.posHeldSale.findMany({
        where: { shiftId: shift.id },
        orderBy: { createdAt: 'desc' },
      });
      return res.json({
        heldSales: heldSales.map((sale) => ({
          id: sale.id,
          customerName: sale.customerName,
          customerPhone: sale.customerPhone,
          items: sale.items,
          createdAt: sale.createdAt.toISOString(),
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/held-sales', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = holdInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Check the held bill details.' });
    try {
      const heldSale = await runTransactionWithRetry(prisma, async (tx) => {
        const shift = await findOrCreateOpenShift(tx, cashierId);
        const customer = parsed.data.customerId
          ? await tx.user.findFirst({
            where: { id: parsed.data.customerId, isActive: true },
            select: { name: true, phone: true },
          })
          : null;
        if (parsed.data.customerId && !customer) {
          throw new Error('POS_CUSTOMER_UNAVAILABLE');
        }
        return tx.posHeldSale.create({
          data: {
            shiftId: shift.id,
            customerName: customer?.name ?? parsed.data.customerName ?? null,
            customerPhone: customer?.phone ?? parsed.data.customerPhone ?? null,
            items: parsed.data.items as Prisma.InputJsonValue,
          },
        });
      });
      return res.status(201).json({ id: heldSale.id });
    } catch (error) {
      if (error instanceof Error && error.message === 'POS_CUSTOMER_UNAVAILABLE') {
        return res.status(409).json({ error: 'The selected customer is no longer available.' });
      }
      sendAdminError(error, res);
    }
  });

  router.delete('/held-sales/:id', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const deleted = await prisma.posHeldSale.deleteMany({
        where: {
          id: req.params.id,
          shift: { cashierId, status: 'OPEN' },
        },
      });
      if (deleted.count !== 1) return res.status(404).json({ error: 'Held bill not found.' });
      return res.sendStatus(204);
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/offline-sync', adminOnly, async (req, res) => {
    const parsed = z.object({
      productsSince: z.string().datetime({ offset: true }).optional(),
      wholesaleSince: z.string().datetime({ offset: true }).optional(),
      drinksSince: z.string().datetime({ offset: true }).optional(),
      customersSince: z.string().datetime({ offset: true }).optional(),
      billsSince: z.string().datetime({ offset: true }).optional(),
      refundsSince: z.string().datetime({ offset: true }).optional(),
      pendingCashSince: z.string().datetime({ offset: true }).optional(),
    }).strict().safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose valid offline sync cursors.' });
    }
    const cutoff = new Date();
    const since = (value?: string) => new Date(value ?? '1970-01-01T00:00:00.000Z');
    const productSince = since(parsed.data.productsSince);
    const drinksSince = since(parsed.data.drinksSince);
    const billsSince = since(parsed.data.billsSince);
    const pendingCashSince = since(parsed.data.pendingCashSince);
    const productQuerySince = new Date(Math.min(productSince.getTime(), drinksSince.getTime()));
    const saleQuerySince = new Date(Math.min(billsSince.getTime(), pendingCashSince.getTime()));
    try {
      const [products, wholesaleProducts, customers, sales, refunds] = await Promise.all([
        prisma.product.findMany({
          where: { updatedAt: { gt: productQuerySince, lte: cutoff } },
          orderBy: [{ updatedAt: 'asc' }, { id: 'asc' }],
          select: {
            id: true, name: true, sku: true, barcode: true, price: true,
            unitLabel: true, imageUrl: true, imageMimeType: true, isActive: true,
            isVendingDrink: true, updatedAt: true,
            inventory: { select: { totalStock: true, reservedStock: true } },
          },
        }),
        prisma.wholesaleItem.findMany({
          where: { updatedAt: { gt: since(parsed.data.wholesaleSince), lte: cutoff } },
          orderBy: [{ updatedAt: 'asc' }, { id: 'asc' }],
          select: {
            id: true, name: true, sku: true, price: true, stock: true,
            unitLabel: true, imageUrl: true, imageMimeType: true, isActive: true,
            updatedAt: true,
          },
        }),
        prisma.user.findMany({
          where: {
            role: 'CUSTOMER',
            updatedAt: { gt: since(parsed.data.customersSince), lte: cutoff },
          },
          orderBy: [{ updatedAt: 'asc' }, { id: 'asc' }],
          select: {
            id: true, userNumber: true, name: true, email: true, phone: true,
            isActive: true, createdAt: true, updatedAt: true,
          },
        }),
        prisma.posSale.findMany({
          where: { updatedAt: { gt: saleQuerySince, lte: cutoff } },
          orderBy: [{ updatedAt: 'asc' }, { id: 'asc' }],
          select: {
            id: true, receiptNumber: true, invoiceNumber: true, customerName: true,
            customerPhone: true, status: true, paymentMethod: true,
            paymentStatus: true, paidAmount: true, subtotal: true, discount: true,
            vatRate: true, vatAmount: true, total: true, refundedAmount: true,
            createdAt: true, updatedAt: true,
            items: {
              select: {
                id: true, productId: true, productName: true, sku: true,
                quantity: true, weightGrams: true, unitPrice: true, lineTotal: true,
              },
            },
            paymentCollections: {
              select: { id: true, amount: true, method: true, note: true, createdAt: true },
            },
          },
        }),
        prisma.posRefund.findMany({
          where: {
            OR: [
              { requestedAt: { gt: since(parsed.data.refundsSince), lte: cutoff } },
              { resolvedAt: { gt: since(parsed.data.refundsSince), lte: cutoff } },
            ],
          },
          orderBy: [{ requestedAt: 'asc' }, { id: 'asc' }],
          select: {
            id: true, saleId: true, amount: true, reason: true, status: true,
            restockStock: true, requestedAt: true, resolvedAt: true,
            sale: { select: { receiptNumber: true, customerName: true, customerPhone: true } },
            requestedBy: { select: { name: true } },
          },
        }),
      ]);
      const changedProducts = products.filter((product) => product.updatedAt > productSince);
      const changedDrinks = products.filter((product) =>
        product.isVendingDrink && product.updatedAt > drinksSince);
      const changedBills = sales.filter((sale) => sale.updatedAt > billsSince);
      const changedPendingCash = sales.filter((sale) => sale.updatedAt > pendingCashSince);
      const imageUrl = (product: { id: string; updatedAt: Date; imageMimeType: string | null; imageUrl: string | null }) =>
        product.imageMimeType
          ? `/api/v1/products/${encodeURIComponent(product.id)}/image?v=${product.updatedAt.getTime()}`
          : product.imageUrl;
      return res.json({
        cutoff: cutoff.toISOString(),
        products: changedProducts.map((product) => ({
          id: product.id, name: product.name, sku: product.sku, barcode: product.barcode,
          price: Number(product.price), unitLabel: product.unitLabel,
          available: Math.max(0, (product.inventory?.totalStock ?? 0) - (product.inventory?.reservedStock ?? 0)),
          imageUrl: imageUrl(product), isActive: product.isActive,
          isVendingDrink: product.isVendingDrink, updatedAt: product.updatedAt.toISOString(),
        })),
        wholesaleProducts: wholesaleProducts.map((product) => ({
          id: product.id, name: product.name, sku: product.sku,
          price: Number(product.price), stock: product.stock, unitLabel: product.unitLabel,
          imageUrl: imageUrl(product), isActive: product.isActive,
          updatedAt: product.updatedAt.toISOString(),
        })),
        drinks: changedDrinks.map((drink) => ({
          id: drink.id, name: drink.name, sku: drink.sku, barcode: drink.barcode,
          price: Number(drink.price), isActive: drink.isActive,
          updatedAt: drink.updatedAt.toISOString(),
        })),
        customers: customers.map((customer) => ({
          id: customer.id, profileId: customer.userNumber.toString(),
          name: customer.name, email: customer.email, phone: customer.phone ?? '',
          isActive: customer.isActive, createdAt: customer.createdAt.toISOString(),
          updatedAt: customer.updatedAt.toISOString(), orderCount: 0, orderValue: 0,
          addresses: [], recentOrders: [],
        })),
        bills: changedBills.map((sale) => ({
          id: sale.id, receiptNumber: sale.receiptNumber, invoiceNumber: sale.invoiceNumber,
          customerName: sale.customerName, customerPhone: sale.customerPhone,
          status: sale.status, paymentMethod: sale.paymentMethod,
          paymentStatus: sale.paymentStatus, paidAmount: Number(sale.paidAmount),
          subtotal: Number(sale.subtotal), discount: Number(sale.discount),
          vatRate: Number(sale.vatRate), vatAmount: Number(sale.vatAmount),
          total: Number(sale.total), refundedAmount: Number(sale.refundedAmount),
          createdAt: sale.createdAt.toISOString(), updatedAt: sale.updatedAt.toISOString(),
          items: sale.items.map((item) => ({
            id: item.id, productId: item.productId, productName: item.productName,
            sku: item.sku, quantity: item.quantity, weightGrams: item.weightGrams,
            unitPrice: Number(item.unitPrice), lineTotal: Number(item.lineTotal),
          })),
          paymentCollections: sale.paymentCollections.map((payment) => ({
            id: payment.id, amount: Number(payment.amount), method: payment.method,
            note: payment.note, createdAt: payment.createdAt.toISOString(),
          })),
        })),
        refunds: refunds.map((refund) => ({
          id: refund.id, saleId: refund.saleId, receiptNumber: refund.sale.receiptNumber,
          customerName: refund.sale.customerName, customerPhone: refund.sale.customerPhone,
          amount: Number(refund.amount), reason: refund.reason, status: refund.status,
          restockStock: refund.restockStock, requestedBy: refund.requestedBy.name,
          requestedAt: refund.requestedAt.toISOString(),
          updatedAt: (refund.resolvedAt ?? refund.requestedAt).toISOString(),
          isDeleted: false,
        })),
        pendingCash: changedPendingCash.map((sale) => ({
          id: sale.id, invoiceNumber: sale.invoiceNumber,
          customerName: sale.customerName, customerPhone: sale.customerPhone,
          amount: Math.max(0, Number(sale.total) - Number(sale.paidAmount)),
          total: Number(sale.total), paidAmount: Number(sale.paidAmount),
          paymentStatus: sale.paymentStatus, status: sale.status,
          updatedAt: sale.updatedAt.toISOString(),
          isDeleted: sale.paymentStatus !== 'PENDING' || sale.status === 'CANCELLED',
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/products', async (req, res) => {
    const query = z.string().trim().max(100).safeParse(req.query.query ?? '');
    if (!query.success) return res.status(400).json({ error: 'Enter a valid product search.' });
    try {
      const select = {
        id: true,
        name: true,
        sku: true,
        barcode: true,
        price: true,
        unitLabel: true,
        imageUrl: true,
        imageMimeType: true,
        updatedAt: true,
        inventory: { select: { totalStock: true, reservedStock: true } },
      } satisfies Prisma.ProductSelect;
      const exactProduct = query.data
        ? await prisma.product.findFirst({
          where: {
            isActive: true,
            OR: [
              { id: query.data },
              { sku: { equals: query.data } },
              { barcode: { equals: query.data } },
            ],
          },
          select,
        })
        : null;
      const matchingProducts = await prisma.product.findMany({
        where: {
          isActive: true,
          ...(query.data
            ? {
              OR: [
                { name: { contains: query.data } },
                { sku: { contains: query.data } },
                { barcode: { contains: query.data } },
              ],
            }
            : {}),
        },
        take: 20,
        orderBy: { name: 'asc' },
        select,
      });
      const products = exactProduct
        ? [
          exactProduct,
          ...matchingProducts
            .filter((product) => product.id !== exactProduct.id)
            .slice(0, 19),
        ]
        : matchingProducts;
      return res.json({
        products: products.map((product) => ({
          id: product.id,
          name: product.name,
          sku: product.sku,
          barcode: product.barcode,
          price: Number(product.price),
          unitLabel: product.unitLabel,
          imageUrl: product.imageMimeType
            ? `/api/v1/products/${encodeURIComponent(product.id)}/image?v=${product.updatedAt.getTime()}`
            : product.imageUrl,
          available: Math.max(
            0,
            (product.inventory?.totalStock ?? 0) -
            (product.inventory?.reservedStock ?? 0),
          ),
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/sales', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = saleInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({
      error: 'Check the bill items and payment details.',
      details: parsed.error.issues.map(issue => ({ field: issue.path.join('.'), message: issue.message })),
    });
    const manualFonepay = ['FONEPAY', 'ESEWA'].includes(parsed.data.paymentMethod) && !!parsed.data.manualVerification;
    const manualItem = (item: { productId: string }) => /^manual-[a-f0-9-]{36}$/i.test(item.productId);
    // eSewa is a DIGITAL payment subtype; preserve its provider in audit metadata.
    const storedPaymentMethod = parsed.data.paymentMethod === 'ESEWA' ? 'DIGITAL' : parsed.data.paymentMethod;
    if (manualFonepay && !['ADMIN', 'BILLING_STAFF'].includes(authenticatedRole(res) ?? '')) {
      return res.status(403).json({ error: 'Only a cashier or administrator can manually verify a Fonepay payment.' });
    }
    const confirmedAt = new Date();
    if (parsed.data.cataloguePriceChanges && (authenticatedRole(res) !== 'ADMIN' || !parsed.data.idempotencyKey ||
      parsed.data.cataloguePriceChanges.some(change => !parsed.data.items.some(item => item.productId === change.productId)))) {
      return res.status(403).json({ error: 'Only an administrator may update prices of products in this bill.' });
    }
    if (parsed.data.paymentMethod === 'FONEPAY' && !manualFonepay) {
      return res.status(400).json({ error: 'Confirm receipt of the static QR payment before creating this bill.' });
    }
    const offline = parsed.data.offlineSale;
    if (offline && (authenticatedRole(res) !== 'ADMIN' ||
      parsed.data.paymentMethod === 'DIGITAL' ||
      (parsed.data.paymentMethod === 'PENDING' && parsed.data.paidNowMethod === 'DIGITAL'))) {
      return res.status(403).json({ error: 'Only an administrator may import offline cash bills. Digital payments require online verification.' });
    }
    if (offline && (!parsed.data.idempotencyKey ||
      new Date(offline.occurredAt).getTime() > Date.now() + 300000 ||
      offline.invoiceNumber !== `RPGS-INV-${getStoreDayKey(new Date(offline.occurredAt)).slice(0, 4)}-L-${parsed.data.idempotencyKey.replaceAll('-', '').toUpperCase()}`)) {
      return res.status(400).json({ error: 'The offline reference or sale date is invalid.' });
    }
    const receiptNumber = parsed.data.idempotencyKey
      ? `POS-${parsed.data.idempotencyKey.toUpperCase()}`
      : `POS-${Date.now()}-${randomUUID().slice(0, 8).toUpperCase()}`;
    const manualReplayMatches = (existing: { items: Array<{ productId: string | null; sku?: string; productName?: string; quantity: number; unitPrice: Prisma.Decimal }> }) =>
      JSON.stringify(existing.items.filter(i => i.productId == null && i.sku?.startsWith('manual-'))
        .map(i => [i.sku, i.productName, i.quantity, Number(i.unitPrice)]).sort()) ===
      JSON.stringify(parsed.data.items.filter(manualItem)
        .map(i => [i.productId, i.manualName || 'Miscellaneous item', i.quantity, i.manualPrice]).sort());
    const offlineReplayMatches = (existing: {
      total: Prisma.Decimal; discount: Prisma.Decimal; vatRate: Prisma.Decimal;
      paymentMethod?: string;
      paymentCollections?: Array<{ method: string; note: string | null }>;
      items: Array<{ productId: string | null; sku?: string; productName?: string; quantity: number; weightGrams: number | null; unitPrice: Prisma.Decimal }>;
    }) => manualReplayMatches(existing) && (!(offline || manualFonepay) || (
      (!manualFonepay || (existing.paymentMethod === storedPaymentMethod && existing.paymentCollections?.some(payment => payment.method === storedPaymentMethod && manualPaymentProvider(payment.note) === parsed.data.paymentMethod && manualFonepayReference(payment.note) === parsed.data.manualVerification!.transactionReference))) &&
      roundMoney(Number(existing.total)) === roundMoney((offline?.expectedTotal ?? parsed.data.quote!.expectedTotal)) &&
      roundMoney(Number(existing.discount)) === roundMoney(parsed.data.discount) &&
      roundMoney(Number(existing.vatRate)) === roundMoney(parsed.data.vatRate) &&
      JSON.stringify(existing.items.map((item) =>
        `${item.productId ?? item.sku}:${item.quantity}:${item.weightGrams ?? ''}:${Number(item.unitPrice)}${item.productId == null ? ':' + item.productName : ''}`).sort()) ===
      JSON.stringify(parsed.data.items.map((item) =>
        `${item.productId}:${item.quantity}:${item.weightGrams ?? ''}:${item.manualPrice ?? (offline?.unitPrices ?? parsed.data.quote!.unitPrices)[item.productId]}${manualItem(item) ? ':' + (item.manualName || 'Miscellaneous item') : ''}`).sort())
    ));
    try {
      let replayed = false;
      const sale = await runTransactionWithRetry(prisma, async (tx) => {
        if (parsed.data.idempotencyKey) {
          const existing = await tx.posSale.findUnique({
            where: { receiptNumber },
            include: {
              items: true,
              paymentCollections: true,
              shift: { select: { cashierId: true } },
            },
          });
          if (existing) {
            if (existing.shift.cashierId !== cashierId) {
              throw new Error('POS_IDEMPOTENCY_KEY_REUSED');
            }
            if (!offlineReplayMatches(existing)) {
              throw new Error(manualFonepay ? 'POS_MANUAL_FONEPAY_CONFLICT' : 'POS_OFFLINE_PRICE_CONFLICT');
            }
            if (parsed.data.roomPicks) {
              const plan = await tx.inventoryRoomCheckout.findUnique({ where: { saleId: existing.id } });
              const canonical = (picks: unknown) => JSON.stringify((picks as Array<{ productId: string; roomId: string | null; quantity: number }>).map(p => [p.productId, p.roomId, p.quantity]).sort());
              if (!plan || canonical(plan.picks) !== canonical(parsed.data.roomPicks)) throw new RoomInventoryError('This bill is already saved with different source rooms. Review the original bill.');
            }
            replayed = true;
            return existing;
          }
        }
        if (parsed.data.cataloguePriceChanges) {
          await applyPosPriceChanges(tx, parsed.data.idempotencyKey!, cashierId, parsed.data.cataloguePriceChanges);
        }
        const products = await tx.product.findMany({
          where: {
            id: { in: parsed.data.items.map((item) => item.productId) },
            isActive: true,
          },
          select: {
            id: true,
            name: true,
            sku: true,
            price: true,
            unitLabel: true,
            inventory: { select: { totalStock: true, reservedStock: true } },
          },
        });
        const productById = new Map(products.map((product) => [product.id, product]));
        const lines = parsed.data.items.map((item) => {
          if (manualItem(item)) {
            const unitPrice = item.manualPrice!;
            const quote = offline?.unitPrices ?? parsed.data.quote?.unitPrices;
            if (quote && quote[item.productId] !== unitPrice) throw new Error('POS_QUOTE_CHANGED');
            return { product: { id: item.productId, name: item.manualName || 'Miscellaneous item', sku: item.productId },
              manual: true, quantity: item.quantity, weightGrams: null, stockQuantity: 0,
              unitPrice, lineTotal: roundMoney(unitPrice * item.quantity) };
          }
          const product = productById.get(item.productId);
          if (!product) throw new Error('POS_PRODUCT_UNAVAILABLE');
          const byWeight = isWeightUnitLabel(product.unitLabel);
          const weightGrams = item.weightGrams ?? null;
          if (byWeight !== (weightGrams !== null)) {
            throw new Error('POS_WEIGHT_REQUIRED');
          }
          const stockQuantity = weightGrams ?? item.quantity;
          const available = Math.max(
            0,
            (product.inventory?.totalStock ?? 0) -
            (product.inventory?.reservedStock ?? 0),
          );
          if (stockQuantity > available) throw new Error('POS_INSUFFICIENT_STOCK');
          const unitPrice = Number(product.price);
          const quotedPrices = offline?.unitPrices ?? parsed.data.quote?.unitPrices;
          if (quotedPrices && (quotedPrices[product.id] === undefined ||
            quotedPrices[product.id] !== unitPrice)) {
            throw new Error(offline ? 'POS_OFFLINE_PRICE_CONFLICT' : 'POS_QUOTE_CHANGED');
          }
          const lineTotal = roundMoney(
            unitPrice * (weightGrams === null ? item.quantity : weightGrams / 1000),
          );
          return {
            product,
            manual: false,
            quantity: item.quantity,
            weightGrams,
            stockQuantity,
            unitPrice,
            lineTotal,
          };
        });
        const stockTotals = new Map<string, number>();
        for (const line of lines) {
          if (line.manual) continue;
          stockTotals.set(
            line.product.id,
            (stockTotals.get(line.product.id) ?? 0) + line.stockQuantity,
          );
        }
        for (const [productId, requestedStock] of stockTotals) {
          const product = productById.get(productId)!;
          const available = Math.max(
            0,
            (product.inventory?.totalStock ?? 0) -
            (product.inventory?.reservedStock ?? 0),
          );
          if (requestedStock > available) {
            throw new Error('POS_INSUFFICIENT_STOCK');
          }
        }
        const customer = parsed.data.customerId
          ? await tx.user.findFirst({
            where: { id: parsed.data.customerId, isActive: true },
            select: { name: true, phone: true, isActive: true },
          })
          : null;
        if (parsed.data.customerId && (!customer || !customer.isActive)) {
          throw new Error('POS_CUSTOMER_UNAVAILABLE');
        }
        const subtotal = roundMoney(lines.reduce((sum, line) => sum + line.lineTotal, 0));
        const discount = roundMoney(parsed.data.discount);
        if (discount > subtotal) throw new Error('POS_DISCOUNT_EXCEEDS_TOTAL');
        const vatRate = roundMoney(parsed.data.vatRate);
        const vatAmount = roundMoney((subtotal - discount) * vatRate / 100);
        const total = roundMoney(subtotal - discount + vatAmount);
        const quotedTotal = offline?.expectedTotal ?? parsed.data.quote?.expectedTotal;
        if (quotedTotal !== undefined && roundMoney(quotedTotal) !== total) {
          throw new Error(offline ? 'POS_OFFLINE_PRICE_CONFLICT' : 'POS_QUOTE_CHANGED');
        }
        const invoiceYear = Number(getStoreDayKey(new Date()).slice(0, 4));
        const invoiceSequence = offline ? null : await tx.invoiceSequence.upsert({
          where: { year: invoiceYear },
          create: { year: invoiceYear, nextNumber: 1 },
          update: { nextNumber: { increment: 1 } },
        });
        const invoiceNumber = offline?.invoiceNumber ?? `RPGS-INV-${invoiceYear}-${String(invoiceSequence!.nextNumber).padStart(6, '0')}`;
        const paidAmount = roundMoney(
          parsed.data.paymentMethod === 'PENDING'
            ? Math.min(parsed.data.paidAmount ?? 0, total)
            : total,
        );
        if (parsed.data.paymentMethod === 'PENDING' &&
          (parsed.data.paidAmount ?? 0) > total) {
          throw new Error('POS_PAID_AMOUNT_EXCEEDS_TOTAL');
        }
        if (manualFonepay && total <= 0) throw new Error('POS_FONEPAY_EMPTY_TOTAL');
        const isPending = paidAmount < total;
        const collectionMethod = parsed.data.paymentMethod === 'PENDING'
          ? parsed.data.paidNowMethod
          : storedPaymentMethod;
        // Imported cash belongs to an explicitly closed import shift, never
        // silently to the currently open till. No physical cash count is claimed.
        const shift = offline
          ? await tx.posShift.create({
            data: {
              cashierId,
              status: 'CLOSED',
              openingCash: 0,
              expectedClosingCash: collectionMethod === 'CASH' ? paidAmount : 0,
              openedAt: new Date(offline.occurredAt),
              closedAt: new Date(offline.occurredAt),
            }
          })
          : await findOrCreateOpenShift(tx, cashierId);
        const sale = await tx.posSale.create({
          data: {
            receiptNumber,
            invoiceNumber,
            shiftId: shift.id,
            customerName: customer?.name ?? parsed.data.customerName ?? null,
            customerPhone: customer?.phone ?? parsed.data.customerPhone ?? null,
            status: 'COMPLETED',
            paymentMethod: isPending ? 'PENDING' : collectionMethod,
            paymentStatus: isPending ? 'PENDING' : 'COMPLETED',
            paidAmount,
            subtotal,
            discount,
            vatRate,
            vatAmount,
            total,
            ...(offline ? { createdAt: new Date(offline.occurredAt) } : {}),
            ...(paidAmount <= 0 || total === 0
              ? {}
              : {
                paymentCollections: {
                  create: {
                    recordedById: cashierId,
                    amount: paidAmount,
                    method: collectionMethod,
                    ...(manualFonepay ? { note: manualFonepayNote(parsed.data.manualVerification!.transactionReference, cashierId, total, confirmedAt, parsed.data.paymentMethod), createdAt: confirmedAt } : {}),
                    ...(offline ? { createdAt: new Date(offline.occurredAt) } : {}),
                  },
                },
              }),
            items: {
              create: lines.map((line) => ({
                productId: line.manual ? null : line.product.id,
                productName: line.product.name,
                sku: line.product.sku,
                quantity: line.quantity,
                weightGrams: line.weightGrams,
                unitPrice: line.unitPrice,
                lineTotal: line.lineTotal,
              })),
            },
          },
          include: { items: true, paymentCollections: true },
        });
        if (parsed.data.roomPicks) {
          if (parsed.data.roomPicks.some((pick) => !stockTotals.has(pick.productId))) throw new RoomInventoryError('Room selections contain a product outside this bill.');
          await tx.inventoryRoomCheckout.create({ data: { saleId: sale.id, picks: parsed.data.roomPicks } });
        }
        await inventoryService.consumeStockForPosSale(
          tx,
          [...stockTotals].map(([productId, quantity]) => ({
            productId,
            quantity,
          })),
          sale.id,
          cashierId,
          parsed.data.roomPicks,
        );
        if (parsed.data.heldSaleId) {
          await tx.posHeldSale.deleteMany({
            where: offline
              ? { id: parsed.data.heldSaleId, shift: { cashierId } }
              : { id: parsed.data.heldSaleId, shiftId: shift.id },
          });
        }
        return sale;
      });
      return res.status(replayed ? 200 : 201).json({ sale: { ...serializeSale(sale), ...(manualFonepay ? { autoPrintAllowed: !replayed } : {}) } });
    } catch (error) {
      if (
        parsed.data.idempotencyKey &&
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        try {
          const existing = await prisma.posSale.findUnique({
            where: { receiptNumber },
            include: {
              items: true,
              paymentCollections: true,
              shift: { select: { cashierId: true } },
            },
          });
          if (existing?.shift.cashierId === cashierId) {
            if (!offlineReplayMatches(existing)) {
              return res.status(409).json({ error: manualFonepay ? 'This payment reference or bill differs from the saved Fonepay checkout. Review the original bill.' : 'The server bill differs from this offline snapshot. Review the original record; nothing was overwritten.' });
            }
            return res.status(200).json({ sale: { ...serializeSale(existing), ...(manualFonepay ? { autoPrintAllowed: false } : {}) } });
          }
        } catch (lookupError) {
          return sendAdminError(lookupError, res);
        }
      }
      if (error instanceof Error) {
        if (error.message === 'POS_IDEMPOTENCY_KEY_REUSED') {
          return res.status(409).json({
            error: 'This bill request key was already used by another cashier.',
          });
        }
        const clientErrors: Record<string, string> = {
          POS_PRODUCT_UNAVAILABLE: 'One or more products are no longer available.',
          POS_WEIGHT_REQUIRED: 'Enter a weight for each product sold by weight.',
          POS_INSUFFICIENT_STOCK: 'The requested quantity exceeds available stock.',
          POS_DISCOUNT_EXCEEDS_TOTAL: 'The discount cannot exceed the bill subtotal.',
          POS_CUSTOMER_UNAVAILABLE: 'The selected customer is no longer available.',
          POS_QUOTE_CHANGED: 'Prices or totals changed. Refresh the products and review the bill before collecting payment. No sale was saved.',
          POS_OFFLINE_PRICE_CONFLICT: 'Offline bill prices differ from the current catalogue. Review this conflict; the original bill has not been changed or imported.',
          POS_MANUAL_FONEPAY_CONFLICT: 'This payment reference or bill differs from the saved Fonepay checkout. Review the original bill; no duplicate was created.',
          POS_FONEPAY_EMPTY_TOTAL: 'Fonepay requires a payable amount greater than NPR 0.00.',
          POS_PAID_AMOUNT_EXCEEDS_TOTAL: 'The received amount exceeds the bill total.',
        };
        if (clientErrors[error.message]) {
          return res.status(409).json({ error: clientErrors[error.message] });
        }
      }
      if (error instanceof InventoryAdjustmentError || error instanceof RoomInventoryError) {
        return res.status(409).json({ error: error.message });
      }
      sendAdminError(error, res);
    }
  });

  router.get('/sales', async (req, res) => {
    const parsed = z.object({
      page: z.coerce.number().int().min(1).max(10000).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
      day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
      search: z.string().trim().max(120).optional(),
    }).strict().safeParse(req.query);
    if (!parsed.success) return res.status(400).json({ error: 'Choose a valid bill-history filter.' });
    try {
      const range = parsed.data.day
        ? getLocalDayRangeForKey(parsed.data.day)
        : undefined;
      const cashierId = authenticatedAdminId(res);
      const isBillingStaff = authenticatedRole(res) === 'BILLING_STAFF';
      if (isBillingStaff && !cashierId) {
        return res.status(401).json({ error: 'Authentication is required.' });
      }
      const where: Prisma.PosSaleWhereInput = {
        status: { not: 'CHECKOUT' },
        ...(range
          ? { createdAt: { gte: range.start, lt: range.end } }
          : {}),
        ...(parsed.data.search?.trim()
          ? {
            OR: [
              { receiptNumber: { contains: parsed.data.search.trim() } },
              { invoiceNumber: { contains: parsed.data.search.trim() } },
              { customerName: { contains: parsed.data.search.trim() } },
              { customerPhone: { contains: parsed.data.search.trim() } },
            ],
          }
          : {}),
        ...(isBillingStaff && cashierId ? { shift: { cashierId } } : {}),
      };
      const [sales, total] = await Promise.all([
        prisma.posSale.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          skip: (parsed.data.page - 1) * parsed.data.pageSize,
          take: parsed.data.pageSize,
          include: { items: true, paymentCollections: true },
        }),
        prisma.posSale.count({ where }),
      ]);
      return res.json({
        sales: sales.map(serializeSale),
        pagination: {
          page: parsed.data.page,
          pageSize: parsed.data.pageSize,
          total,
        },
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/pending-payments', async (req, res) => {
    const parsed = z.object({
      page: z.coerce.number().int().min(1).max(10000).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(50),
      search: z.string().trim().max(120).optional(),
      day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    }).strict().safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose a valid pending-payment page.' });
    }
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    let dayRange: { start: Date; end: Date } | undefined;
    try {
      dayRange = parsed.data.day
        ? getLocalDayRangeForKey(parsed.data.day)
        : undefined;
    } catch {
      return res.status(400).json({ error: 'Choose a valid pending-payment date.' });
    }
    const search = parsed.data.search?.trim();
    const where: Prisma.PosSaleWhereInput = {
      paymentStatus: 'PENDING',
      status: { notIn: ['CANCELLED', 'CHECKOUT'] },
      ...(dayRange
        ? { createdAt: { gte: dayRange.start, lt: dayRange.end } }
        : {}),
      ...(search
        ? {
          OR: [
            { receiptNumber: { contains: search } },
            { invoiceNumber: { contains: search } },
            { customerName: { contains: search } },
            { customerPhone: { contains: search } },
          ],
        }
        : {}),
      ...(authenticatedRole(res) === 'BILLING_STAFF'
        ? { shift: { cashierId } }
        : {}),
    };
    try {
      const total = await prisma.posSale.count({ where });
      const page = Math.min(
        parsed.data.page,
        Math.max(1, Math.ceil(total / parsed.data.pageSize)),
      );
      const sales = await prisma.posSale.findMany({
        where,
        orderBy: { createdAt: 'asc' },
        skip: (page - 1) * parsed.data.pageSize,
        take: parsed.data.pageSize,
        include: {
          items: true,
          paymentCollections: { orderBy: { createdAt: 'asc' } },
        },
      });
      return res.json({
        sales: sales.map(serializeSale),
        pagination: {
          page,
          pageSize: parsed.data.pageSize,
          total,
        },
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/sales/:id/payments', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = paymentCollectionInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid received amount and payment method.' });
    }
    const paymentId = parsed.data.idempotencyKey
      ? `PPC-${parsed.data.idempotencyKey.toUpperCase()}` : null;
    const matchesAttempt = (payment: {
      saleId: string; recordedById: string; amount: Prisma.Decimal;
      method: string; note: string | null;
    }) => payment.saleId === req.params.id &&
    payment.recordedById === cashierId &&
    roundMoney(Number(payment.amount)) === roundMoney(parsed.data.amount) &&
    payment.method === parsed.data.paymentMethod &&
      (payment.note ?? '') === (parsed.data.note?.trim() ?? '');
    let replayed = false;
    try {
      const payment = await runTransactionWithRetry(prisma, async (tx) => {
        if (paymentId) {
          const existing = await tx.posPaymentCollection.findUnique({ where: { id: paymentId } });
          if (existing) {
            if (!matchesAttempt(existing)) throw new Error('POS_PAYMENT_KEY_REUSED');
            replayed = true;
            return existing;
          }
        }
        const sale = await tx.posSale.findUnique({
          where: { id: req.params.id },
          include: { shift: { select: { cashierId: true } } },
        });
        const isBillingStaff = authenticatedRole(res) === 'BILLING_STAFF';
        if (!sale ||
          ['CHECKOUT', 'CANCELLED'].includes(sale.status) ||
          sale.paymentStatus !== 'PENDING' ||
          (isBillingStaff && sale.shift.cashierId !== cashierId)) {
          throw new Error('POS_SALE_NOT_AWAITING_PAYMENT');
        }
        const paidAmount = Number(sale.paidAmount);
        const total = Number(sale.total);
        const amount = roundMoney(parsed.data.amount);
        const remaining = roundMoney(total - paidAmount);
        if (amount > remaining) throw new Error('POS_PAYMENT_EXCEEDS_BALANCE');
        const nextPaidAmount = roundMoney(paidAmount + amount);
        const settled = nextPaidAmount >= total;
        const updated = await tx.posSale.updateMany({
          where: {
            id: sale.id,
            paymentStatus: 'PENDING',
            paidAmount: sale.paidAmount,
            status: { notIn: ['CANCELLED', 'CHECKOUT'] },
          },
          data: {
            paidAmount: nextPaidAmount,
            ...(settled
              ? {
                paymentStatus: 'COMPLETED',
                paymentMethod: parsed.data.paymentMethod,
              }
              : {}),
          },
        });
        if (updated.count !== 1) throw new Error('POS_PAYMENT_CONCURRENT_UPDATE');
        return tx.posPaymentCollection.create({
          data: {
            ...(paymentId ? { id: paymentId } : {}),
            saleId: sale.id,
            recordedById: cashierId,
            amount,
            method: parsed.data.paymentMethod,
            note: parsed.data.note?.trim() || null,
          },
        });
      });
      return res.status(replayed ? 200 : 201).json({
        payment: {
          id: payment.id,
          amount: Number(payment.amount),
          method: payment.method,
          note: payment.note,
          createdAt: payment.createdAt.toISOString(),
        },
      });
    } catch (error) {
      if (paymentId && error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        try {
          const existing = await prisma.posPaymentCollection.findUnique({ where: { id: paymentId } });
          if (existing && matchesAttempt(existing)) {
            return res.status(200).json({
              payment: {
                id: existing.id, amount: Number(existing.amount), method: existing.method,
                note: existing.note, createdAt: existing.createdAt.toISOString(),
              }
            });
          }
        } catch (lookupError) {
          return sendAdminError(lookupError, res);
        }
        return res.status(409).json({ error: 'This payment request key is already in use. Refresh the payment ledger.' });
      }
      if (error instanceof Error) {
        if (error.message === 'POS_PAYMENT_KEY_REUSED') {
          return res.status(409).json({ error: 'This request key belongs to a different payment. No extra payment was recorded.' });
        }
        if (error.message === 'POS_SALE_NOT_AWAITING_PAYMENT') {
          return res.status(409).json({ error: 'This bill is not awaiting payment.' });
        }
        if (error.message === 'POS_PAYMENT_EXCEEDS_BALANCE') {
          return res.status(409).json({ error: 'The received amount exceeds the remaining balance.' });
        }
        if (error.message === 'POS_PAYMENT_CONCURRENT_UPDATE') {
          return res.status(409).json({ error: 'This bill changed while recording payment. Refresh and retry.' });
        }
      }
      sendAdminError(error, res);
    }
  });

  router.patch('/sales/:id/payment', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = paymentInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose cash or digital payment.' });
    }
    try {
      const updated = await runTransactionWithRetry(prisma, async (tx) => {
        const sale = await tx.posSale.findUnique({
          where: { id: req.params.id },
          include: { shift: { select: { cashierId: true } } },
        });
        const isBillingStaff = authenticatedRole(res) === 'BILLING_STAFF';
        if (!sale ||
          ['CHECKOUT', 'CANCELLED'].includes(sale.status) ||
          sale.paymentStatus !== 'PENDING' ||
          (isBillingStaff && sale.shift.cashierId !== cashierId)) {
          return false;
        }
        const remaining = roundMoney(
          Number(sale.total) - Number(sale.paidAmount),
        );
        if (remaining <= 0) return false;
        const result = await tx.posSale.updateMany({
          where: {
            id: sale.id,
            paymentStatus: 'PENDING',
            paidAmount: sale.paidAmount,
          },
          data: {
            paymentMethod: parsed.data.paymentMethod,
            paymentStatus: 'COMPLETED',
            paidAmount: Number(sale.total),
          },
        });
        if (result.count !== 1) return false;
        await tx.posPaymentCollection.create({
          data: {
            saleId: sale.id,
            recordedById: cashierId,
            amount: remaining,
            method: parsed.data.paymentMethod,
          },
        });
        return true;
      });
      if (!updated) {
        return res.status(409).json({ error: 'This bill is not awaiting payment.' });
      }
      return res.sendStatus(204);
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/sales/:id/cancel', adminOnly, async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const cancelled = await runTransactionWithRetry(prisma, async (tx) => {
        const sale = await tx.posSale.findUnique({
          where: { id: req.params.id },
          include: { items: true, refunds: { where: { status: 'APPROVED' } } },
        });
        if (!sale ||
          ['CHECKOUT', 'CANCELLED'].includes(sale.status) ||
          sale.paymentStatus !== 'PENDING' ||
          Number(sale.paidAmount) > 0 ||
          sale.refunds.length > 0) {
          return null;
        }
        const returnedQuantities = new Map<string, number>();
        for (const item of sale.items) {
          if (!item.productId) continue;
          returnedQuantities.set(
            item.productId,
            (returnedQuantities.get(item.productId) ?? 0) +
            (item.weightGrams ?? item.quantity),
          );
        }
        await inventoryService.restockPosSale(
          tx,
          [...returnedQuantities].map(([productId, quantity]) => ({
            productId,
            quantity,
          })),
          sale.id,
          cashierId,
          `Cancelled POS bill ${sale.receiptNumber}`,
        );
        return tx.posSale.update({
          where: { id: sale.id },
          data: { status: 'CANCELLED', paymentStatus: 'CANCELLED' },
          select: { id: true, receiptNumber: true },
        });
      });
      if (!cancelled) {
        return res.status(409).json({
          error: 'Only an unpaid bill without an approved refund can be cancelled.',
        });
      }
      return res.json({ id: cancelled.id, receiptNumber: cancelled.receiptNumber });
    } catch (error) {
      if (error instanceof InventoryAdjustmentError) {
        return res.status(409).json({ error: error.message });
      }
      sendAdminError(error, res);
    }
  });

  router.get('/refunds', adminOnly, async (req, res) => {
    const parsed = z.object({
      search: z.string().trim().max(120).optional(),
      day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    }).strict().safeParse(req.query);
    if (!parsed.success) return res.status(400).json({ error: 'Choose a valid refund filter.' });
    let dayRange: { start: Date; end: Date } | undefined;
    try {
      dayRange = parsed.data.day
        ? getLocalDayRangeForKey(parsed.data.day)
        : undefined;
    } catch {
      return res.status(400).json({ error: 'Choose a valid refund date.' });
    }
    try {
      const search = parsed.data.search?.trim();
      const refunds = await prisma.posRefund.findMany({
        where: {
          ...(dayRange
            ? { requestedAt: { gte: dayRange.start, lt: dayRange.end } }
            : {}),
          ...(search
            ? {
              OR: [
                { reason: { contains: search } },
                {
                  sale: {
                    is: {
                      OR: [
                        { receiptNumber: { contains: search } },
                        { invoiceNumber: { contains: search } },
                        { customerName: { contains: search } },
                        { customerPhone: { contains: search } },
                      ]
                    }
                  }
                },
                { requestedBy: { is: { name: { contains: search } } } },
              ],
            }
            : {}),
        },
        orderBy: { requestedAt: 'desc' },
        take: 100,
        include: {
          sale: {
            select: {
              receiptNumber: true,
              total: true,
              paymentMethod: true,
              customerName: true,
              customerPhone: true,
            }
          },
          requestedBy: { select: { name: true } },
        },
      });
      return res.json({
        refunds: refunds.map((refund) => ({
          id: refund.id,
          saleId: refund.saleId,
          receiptNumber: refund.sale.receiptNumber,
          customerName: refund.sale.customerName,
          customerPhone: refund.sale.customerPhone,
          amount: Number(refund.amount),
          reason: refund.reason,
          status: refund.status,
          restockStock: refund.restockStock,
          requestedBy: refund.requestedBy.name,
          requestedAt: refund.requestedAt.toISOString(),
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/sales/:id/refunds', adminOnly, async (req, res) => {
    const requestedById = authenticatedAdminId(res);
    if (!requestedById) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = refundInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Enter a valid refund amount and reason.' });
    const requestedAmount = roundMoney(parsed.data.amount);
    try {
      const refund = await runTransactionWithRetry(prisma, async (tx) => {
        const sale = await tx.posSale.findUnique({
          where: { id: req.params.id },
          include: {
            refunds: {
              where: { status: { in: ['REQUESTED', 'APPROVED'] } },
              select: { amount: true },
            },
            items: true,
            exchanges: {
              where: { status: { not: 'REFUND_REJECTED' } },
              select: { id: true },
            },
          },
        });
        if (!sale || ['CHECKOUT', 'CANCELLED'].includes(sale.status)) throw new Error('POS_SALE_NOT_REFUNDABLE');
        if (sale.exchanges.length > 0) {
          throw new Error('POS_REFUND_EXCHANGE_EXISTS');
        }
        const alreadyRefunded = sale.refunds.reduce(
          (sum, item) => sum + Number(item.amount),
          0,
        );
        const received = sale.paidAmount === undefined
          ? sale.paymentStatus === 'COMPLETED' ? Number(sale.total) : 0
          : Number(sale.paidAmount);
        const remaining = roundMoney(Math.min(Number(sale.total), received) - alreadyRefunded);
        if (requestedAmount > remaining) throw new Error('POS_REFUND_TOO_LARGE');
        if (parsed.data.restockStock &&
          (alreadyRefunded > 0 ||
            requestedAmount !== Number(sale.total))) {
          throw new Error('POS_RESTOCK_REQUIRES_FULL_REFUND');
        }
        return tx.posRefund.create({
          data: {
            saleId: sale.id,
            requestedById,
            amount: requestedAmount,
            reason: parsed.data.reason,
            restockStock: parsed.data.restockStock,
          },
        });
      });
      return res.status(201).json({ id: refund.id, status: refund.status });
    } catch (error) {
      if (error instanceof Error) {
        const messages: Record<string, string> = {
          POS_SALE_NOT_REFUNDABLE: 'This bill cannot be refunded.',
          POS_REFUND_TOO_LARGE: 'The refund exceeds the amount actually received after earlier or pending refunds.',
          POS_RESTOCK_REQUIRES_FULL_REFUND: 'Stock can only be restored for a full refund.',
          POS_REFUND_EXCHANGE_EXISTS: 'A bill with an exchange cannot also have a refund request.',
        };
        if (messages[error.message]) return res.status(409).json({ error: messages[error.message] });
      }
      sendAdminError(error, res);
    }
  });

  router.patch('/refunds/:id', adminOnly, async (req, res) => {
    const resolvedById = authenticatedAdminId(res);
    if (!resolvedById) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = refundResolutionInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Choose approve or reject.' });
    try {
      const result = await runTransactionWithRetry(prisma, async (tx) => {
        const refund = await tx.posRefund.findUnique({
          where: { id: req.params.id },
          include: {
            sale: {
              include: {
                items: true,
                refunds: {
                  where: { status: 'REQUESTED' },
                  select: { id: true, amount: true },
                },
              },
            },
          },
        });
        if (!refund || refund.status !== 'REQUESTED') return null;
        if (parsed.data.decision === 'REJECT') {
          return tx.posRefund.update({
            where: { id: refund.id },
            data: { status: 'REJECTED', resolvedById, resolvedAt: new Date() },
          });
        }
        const alreadyRefunded = Number(refund.sale.refundedAmount);
        const totalRefunded = roundMoney(alreadyRefunded + Number(refund.amount));
        const otherPendingRefunds = refund.sale.refunds
          .filter((item) => item.id !== refund.id)
          .reduce((sum, item) => sum + Number(item.amount), 0);
        const received = refund.sale.paidAmount === undefined
          ? refund.sale.paymentStatus === 'COMPLETED' ? Number(refund.sale.total) : 0
          : Number(refund.sale.paidAmount);
        if (totalRefunded + otherPendingRefunds > Math.min(Number(refund.sale.total), received)) {
          throw new Error('POS_REFUND_TOO_LARGE');
        }
        if (refund.restockStock) {
          const returnedQuantities = new Map<string, number>();
          for (const item of refund.sale.items) {
            if (!item.productId) continue;
            returnedQuantities.set(
              item.productId,
              (returnedQuantities.get(item.productId) ?? 0) +
              (item.weightGrams ?? item.quantity),
            );
          }
          await inventoryService.restockPosSale(
            tx,
            [...returnedQuantities].map(([productId, quantity]) => ({
              productId,
              quantity,
            })),
            refund.sale.id,
            resolvedById,
            `POS refund for ${refund.sale.receiptNumber}`,
          );
        }
        await tx.posSale.update({
          where: { id: refund.sale.id },
          data: {
            refundedAmount: totalRefunded,
            status: totalRefunded >= Number(refund.sale.total)
              ? 'REFUNDED'
              : 'PARTIALLY_REFUNDED',
            ...(totalRefunded >= Number(refund.sale.total)
              ? {
                paymentStatus: refund.sale.paymentStatus === 'PENDING'
                  ? 'CANCELLED' as const
                  : 'REFUNDED' as const,
              }
              : {}),
          },
        });
        return tx.posRefund.update({
          where: { id: refund.id },
          data: { status: 'APPROVED', resolvedById, resolvedAt: new Date() },
        });
      });
      if (!result) return res.status(409).json({ error: 'This refund request has already been handled.' });
      return res.json({ id: result.id, status: result.status });
    } catch (error) {
      if (error instanceof InventoryAdjustmentError) {
        return res.status(409).json({ error: error.message });
      }
      if (error instanceof Error && error.message === 'POS_REFUND_TOO_LARGE') {
        return res.status(409).json({ error: 'This refund exceeds the remaining amount actually received. Refresh and review the payment ledger.' });
      }
      sendAdminError(error, res);
    }
  });

  router.get('/exchanges', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) {
      return res.status(401).json({ error: 'Authentication is required.' });
    }
    try {
      const query = z.object({
        search: z.string().trim().max(160).optional(),
        day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional()
      }).safeParse(req.query);
      if (!query.success) return res.status(400).json({ error: 'Choose a valid exchange search or date.' });
      const search = query.data.search;
      const range = query.data.day ? getLocalDayRangeForKey(query.data.day) : undefined;
      const isBillingStaff = authenticatedRole(res) === 'BILLING_STAFF';
      const exchanges = await prisma.posExchange.findMany({
        where: {
          ...(isBillingStaff ? { cashierId } : {}),
          ...(range ? { requestedAt: { gte: range.start, lt: range.end } } : {}),
          ...(search ? {
            sale: {
              OR: [
                { receiptNumber: { contains: search } },
                { invoiceNumber: { contains: search } },
                { customerName: { contains: search } },
                { customerPhone: { contains: search } },
              ]
            }
          } : {}),
        },
        orderBy: { requestedAt: 'desc' },
        take: 100,
        include: {
          sale: { select: { receiptNumber: true, invoiceNumber: true, customerName: true, customerPhone: true } },
          cashier: { select: { name: true } },
          items: true,
        },
      });
      return res.json({
        exchanges: exchanges.map((exchange) => ({
          id: exchange.id,
          saleId: exchange.saleId,
          receiptNumber: exchange.sale.receiptNumber,
          invoiceNumber: exchange.sale.invoiceNumber,
          customerName: exchange.sale.customerName,
          customerPhone: exchange.sale.customerPhone,
          cashier: exchange.cashier.name,
          returnedCredit: Number(exchange.returnedCredit),
          replacementTotal: Number(exchange.replacementTotal),
          difference: Number(exchange.difference),
          paymentMethod: exchange.paymentMethod,
          refundPaymentMethod: exchange.refundPaymentMethod,
          status: exchange.status,
          restockReturnedItems: exchange.restockReturnedItems,
          reason: exchange.reason,
          requestedAt: exchange.requestedAt.toISOString(),
          items: exchange.items.map((item) => ({
            id: item.id,
            type: item.type,
            saleItemId: item.saleItemId,
            productId: item.productId,
            productName: item.productName,
            sku: item.sku,
            quantity: item.quantity,
            weightGrams: item.weightGrams,
            unitPrice: Number(item.unitPrice),
            lineTotal: Number(item.lineTotal),
          })),
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/sales/:id/exchanges', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) {
      return res.status(401).json({ error: 'Authentication is required.' });
    }
    const parsed = exchangeInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Check the returned and replacement item quantities.',
      });
    }
    try {
      let replayed = false;
      const exchange = await runTransactionWithRetry(prisma, async (tx) => {
        const existing = await tx.posExchange.findUnique({
          where: { idempotencyKey: parsed.data.idempotencyKey },
          include: { items: true, sale: { select: { receiptNumber: true } } },
        });
        if (existing) {
          if (existing.cashierId !== cashierId ||
            existing.saleId !== req.params.id) {
            throw new Error('POS_EXCHANGE_IDEMPOTENCY_KEY_REUSED');
          }
          replayed = true;
          return existing;
        }

        const shift = await findOrCreateOpenShift(tx, cashierId);

        const sale = await tx.posSale.findUnique({
          where: { id: req.params.id },
          include: {
            items: true,
            shift: { select: { cashierId: true } },
            refunds: {
              where: { status: { in: ['REQUESTED', 'APPROVED'] } },
              select: { amount: true, status: true },
            },
            exchanges: {
              include: { items: true },
            },
          },
        });
        if (!sale || ['CHECKOUT', 'CANCELLED'].includes(sale.status) ||
          sale.paymentStatus !== 'COMPLETED') {
          throw new Error('POS_SALE_NOT_EXCHANGEABLE');
        }
        if (authenticatedRole(res) === 'BILLING_STAFF' &&
          sale.shift.cashierId !== cashierId) {
          throw new Error('POS_EXCHANGE_WRONG_CASHIER');
        }

        const returnedById = new Map(
          sale.items.map((item) => [item.id, item]),
        );
        const previousReturns = new Map<string, number>();
        let previousReturnedCredit = 0;
        for (const prior of sale.exchanges) {
          if (prior.status === 'REFUND_REJECTED') continue;
          if (prior.status === 'REFUND_REQUESTED') {
            throw new Error('POS_EXCHANGE_REFUND_PENDING');
          }
          previousReturnedCredit += Number(prior.returnedCredit);
          for (const item of prior.items) {
            if (item.type !== 'RETURN' || !item.saleItemId) continue;
            previousReturns.set(
              item.saleItemId,
              (previousReturns.get(item.saleItemId) ?? 0) +
              (item.weightGrams ?? item.quantity),
            );
          }
        }
        if (sale.refunds.length > 0) {
          throw new Error('POS_EXCHANGE_REFUND_EXISTS');
        }

        const discountFactor = Number(sale.subtotal) > 0
          ? Number(sale.total) / Number(sale.subtotal)
          : 1;
        const returnedLines = parsed.data.returnedItems.map((request) => {
          const item = returnedById.get(request.saleItemId);
          if (!item) throw new Error('POS_EXCHANGE_ITEM_NOT_IN_SALE');
          const weighted = item.weightGrams !== null;
          if (weighted !== (request.weightGrams !== undefined) ||
            weighted === (request.quantity !== undefined)) {
            throw new Error('POS_EXCHANGE_QUANTITY_TYPE_MISMATCH');
          }
          const requestedUnits = request.weightGrams ?? request.quantity!;
          const soldUnits = item.weightGrams ?? item.quantity;
          const alreadyReturned = previousReturns.get(item.id) ?? 0;
          if (requestedUnits > soldUnits - alreadyReturned) {
            throw new Error('POS_EXCHANGE_QUANTITY_EXCEEDED');
          }
          const rawTotal = Number(item.unitPrice) *
            (weighted ? requestedUnits / 1000 : requestedUnits);
          const lineTotal = roundMoney(rawTotal * discountFactor);
          return {
            saleItemId: item.id,
            productId: item.productId,
            type: 'RETURN' as const,
            productName: item.productName,
            sku: item.sku,
            quantity: request.quantity ?? 1,
            weightGrams: request.weightGrams ?? null,
            unitPrice: Number(item.unitPrice),
            lineTotal,
          };
        });

        const replacementProducts = await tx.product.findMany({
          where: {
            id: { in: parsed.data.replacementItems.map((item) => item.productId) },
            isActive: true,
          },
          select: {
            id: true,
            name: true,
            sku: true,
            price: true,
            unitLabel: true,
            inventory: { select: { totalStock: true, reservedStock: true } },
          },
        });
        const replacementById = new Map(
          replacementProducts.map((product) => [product.id, product]),
        );
        const replacementLines = parsed.data.replacementItems.map((request) => {
          const product = replacementById.get(request.productId);
          if (!product) throw new Error('POS_PRODUCT_UNAVAILABLE');
          const weighted = isWeightUnitLabel(product.unitLabel);
          if (weighted !== (request.weightGrams !== undefined) ||
            weighted === (request.quantity !== undefined)) {
            throw new Error('POS_WEIGHT_REQUIRED');
          }
          const quantity = request.quantity ?? 1;
          const weightGrams = request.weightGrams ?? null;
          const requestedUnits = weightGrams ?? quantity;
          const available = Math.max(
            0,
            (product.inventory?.totalStock ?? 0) -
            (product.inventory?.reservedStock ?? 0),
          );
          if (requestedUnits > available) {
            throw new Error('POS_INSUFFICIENT_STOCK');
          }
          const unitPrice = Number(product.price);
          const lineTotal = roundMoney(
            unitPrice * (weightGrams === null ? quantity : weightGrams / 1000),
          );
          return {
            saleItemId: null,
            productId: product.id,
            type: 'REPLACEMENT' as const,
            productName: product.name,
            sku: product.sku,
            quantity,
            weightGrams,
            unitPrice,
            lineTotal,
          };
        });
        const returnedCredit = roundMoney(
          returnedLines.reduce((sum, line) => sum + line.lineTotal, 0),
        );
        const replacementTotal = roundMoney(
          replacementLines.reduce((sum, line) => sum + line.lineTotal, 0),
        );
        const remainingValue = roundMoney(
          Number(sale.total) - previousReturnedCredit,
        );
        if (returnedCredit > remainingValue) {
          throw new Error('POS_EXCHANGE_VALUE_EXCEEDED');
        }
        const difference = roundMoney(replacementTotal - returnedCredit);
        if (difference > 0 && !parsed.data.paymentMethod) {
          throw new Error('POS_EXCHANGE_PAYMENT_REQUIRED');
        }
        if (difference <= 0 && parsed.data.paymentMethod) {
          throw new Error('POS_EXCHANGE_PAYMENT_NOT_REQUIRED');
        }

        const created = await tx.posExchange.create({
          data: {
            idempotencyKey: parsed.data.idempotencyKey,
            saleId: sale.id,
            cashierId,
            shiftId: shift.id,
            returnedCredit,
            replacementTotal,
            difference,
            paymentMethod: difference > 0
              ? parsed.data.paymentMethod
              : null,
            status: difference < 0
              ? 'REFUND_REQUESTED'
              : 'COMPLETED',
            restockReturnedItems: parsed.data.restockReturnedItems,
            reason: parsed.data.reason ?? null,
            items: { create: [...returnedLines, ...replacementLines] },
          },
          include: { items: true, sale: { select: { receiptNumber: true } } },
        });

        if (difference >= 0) {
          const returnedStock = new Map<string, number>();
          if (parsed.data.restockReturnedItems) {
            for (const item of returnedLines) {
              if (!item.productId) continue;
              returnedStock.set(
                item.productId,
                (returnedStock.get(item.productId) ?? 0) +
                (item.weightGrams ?? item.quantity),
              );
            }
          }
          if (returnedStock.size > 0) {
            await inventoryService.restockPosSale(
              tx,
              [...returnedStock].map(([productId, quantity]) => ({
                productId,
                quantity,
              })),
              created.id,
              cashierId,
              `Returned stock for POS exchange ${sale.receiptNumber}`,
            );
          }
          const replacementStock = new Map<string, number>();
          for (const item of replacementLines) {
            replacementStock.set(
              item.productId!,
              (replacementStock.get(item.productId!) ?? 0) +
              (item.weightGrams ?? item.quantity),
            );
          }
          if (replacementStock.size > 0) {
            await inventoryService.consumeStockForPosSale(
              tx,
              [...replacementStock].map(([productId, quantity]) => ({
                productId,
                quantity,
              })),
              created.id,
              cashierId,
            );
          }
        }
        return created;
      });
      return res.status(replayed ? 200 : 201).json({
        exchange: {
          id: exchange.id,
          receiptNumber: exchange.sale.receiptNumber,
          returnedCredit: Number(exchange.returnedCredit),
          replacementTotal: Number(exchange.replacementTotal),
          difference: Number(exchange.difference),
          paymentMethod: exchange.paymentMethod,
          status: exchange.status,
          restockReturnedItems: exchange.restockReturnedItems,
          requestedAt: exchange.requestedAt.toISOString(),
          items: exchange.items.map((item) => ({
            id: item.id,
            type: item.type,
            productName: item.productName,
            quantity: item.quantity,
            weightGrams: item.weightGrams,
            lineTotal: Number(item.lineTotal),
          })),
        },
      });
    } catch (error) {
      if (error instanceof Error) {
        const errors: Record<string, { status: number; message: string }> = {
          POS_EXCHANGE_IDEMPOTENCY_KEY_REUSED: {
            status: 409,
            message: 'This exchange request key was already used by another cashier.',
          },
          POS_SALE_NOT_EXCHANGEABLE: {
            status: 409,
            message: 'Only completed, paid bills can be exchanged.',
          },
          POS_EXCHANGE_REFUND_PENDING: {
            status: 409,
            message: 'Resolve the pending exchange refund before starting another exchange on this bill.',
          },
          POS_EXCHANGE_REFUND_EXISTS: {
            status: 409,
            message: 'A bill with a refund request or payment cannot also be exchanged.',
          },
          POS_EXCHANGE_WRONG_CASHIER: {
            status: 403,
            message: 'Billing staff can only exchange bills from their own shift.',
          },
          POS_EXCHANGE_ITEM_NOT_IN_SALE: {
            status: 400,
            message: 'A returned item does not belong to this bill.',
          },
          POS_EXCHANGE_QUANTITY_TYPE_MISMATCH: {
            status: 400,
            message: 'Use a unit quantity for unit items and weight for weighed items.',
          },
          POS_EXCHANGE_QUANTITY_EXCEEDED: {
            status: 409,
            message: 'The returned quantity exceeds the unused quantity on this bill.',
          },
          POS_EXCHANGE_VALUE_EXCEEDED: {
            status: 409,
            message: 'Returned value exceeds the remaining value on this bill.',
          },
          POS_EXCHANGE_PAYMENT_REQUIRED: {
            status: 400,
            message: 'Choose how the customer paid the exchange difference.',
          },
          POS_EXCHANGE_PAYMENT_NOT_REQUIRED: {
            status: 400,
            message: 'A payment method is only needed when the customer owes extra.',
          },
          POS_PRODUCT_UNAVAILABLE: {
            status: 409,
            message: 'One or more replacement products are no longer available.',
          },
          POS_INSUFFICIENT_STOCK: {
            status: 409,
            message: 'A replacement quantity exceeds available stock.',
          },
          POS_WEIGHT_REQUIRED: {
            status: 400,
            message: 'Enter the correct quantity type for each replacement product.',
          },
        };
        const clientError = errors[error.message];
        if (clientError) {
          return res.status(clientError.status).json({ error: clientError.message });
        }
      }
      if (error instanceof InventoryAdjustmentError) {
        return res.status(409).json({ error: error.message });
      }
      sendAdminError(error, res);
    }
  });

  router.patch('/exchanges/:id', adminOnly, async (req, res) => {
    const resolvedById = authenticatedAdminId(res);
    if (!resolvedById) {
      return res.status(401).json({ error: 'Authentication is required.' });
    }
    const parsed = exchangeResolutionInput.safeParse(req.body);
    if (!parsed.success ||
      (parsed.success && parsed.data.decision === 'APPROVE' &&
        !parsed.data.refundPaymentMethod)) {
      return res.status(400).json({
        error: 'Choose a decision and refund method when approving.',
      });
    }
    try {
      const exchange = await runTransactionWithRetry(prisma, async (tx) => {
        const current = await tx.posExchange.findUnique({
          where: { id: req.params.id },
          include: { items: true, sale: { select: { receiptNumber: true } } },
        });
        if (!current || current.status !== 'REFUND_REQUESTED') return null;
        if (parsed.data.decision === 'REJECT') {
          return tx.posExchange.update({
            where: { id: current.id },
            data: {
              status: 'REFUND_REJECTED',
              resolvedById,
              resolvedAt: new Date(),
            },
          });
        }
        const returnedStock = new Map<string, number>();
        if (current.restockReturnedItems) {
          for (const item of current.items) {
            if (item.type !== 'RETURN' || !item.productId) continue;
            returnedStock.set(
              item.productId,
              (returnedStock.get(item.productId) ?? 0) +
              (item.weightGrams ?? item.quantity),
            );
          }
        }
        if (returnedStock.size > 0) {
          await inventoryService.restockPosSale(
            tx,
            [...returnedStock].map(([productId, quantity]) => ({
              productId,
              quantity,
            })),
            current.id,
            resolvedById,
            `Returned stock for approved POS exchange ${current.sale.receiptNumber}`,
          );
        }
        const replacementStock = new Map<string, number>();
        for (const item of current.items) {
          if (item.type !== 'REPLACEMENT' || !item.productId) continue;
          replacementStock.set(
            item.productId,
            (replacementStock.get(item.productId) ?? 0) +
            (item.weightGrams ?? item.quantity),
          );
        }
        if (replacementStock.size > 0) {
          await inventoryService.consumeStockForPosSale(
            tx,
            [...replacementStock].map(([productId, quantity]) => ({
              productId,
              quantity,
            })),
            current.id,
            resolvedById,
          );
        }
        return tx.posExchange.update({
          where: { id: current.id },
          data: {
            status: 'REFUND_APPROVED',
            refundPaymentMethod: parsed.data.refundPaymentMethod,
            resolvedById,
            resolvedAt: new Date(),
          },
        });
      });
      if (!exchange) {
        return res.status(409).json({
          error: 'This exchange request has already been handled.',
        });
      }
      return res.json({ id: exchange.id, status: exchange.status });
    } catch (error) {
      if (error instanceof InventoryAdjustmentError) {
        return res.status(409).json({ error: error.message });
      }
      sendAdminError(error, res);
    }
  });

  return router;
}
