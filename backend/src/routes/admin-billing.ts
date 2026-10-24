import { randomUUID } from 'node:crypto';
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

const openShiftInput = z.object({
  openingCash: z.number().finite().min(0).max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100))),
}).strict();

const saleItemsInput = z.array(z.object({
  productId: z.string().trim().min(1).max(100),
  quantity: z.number().int().min(1).max(100000),
  weightGrams: z.number().int().min(1).max(1000000).nullable().optional(),
}).strict()).min(1).max(100);

const saleInput = z.object({
  items: saleItemsInput,
  idempotencyKey: z.string().uuid().optional(),
  discount: z.number().finite().min(0).max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100)))
    .default(0),
  paymentMethod: z.enum(['CASH', 'DIGITAL', 'PENDING']),
  customerName: z.string().trim().max(120).nullable().optional(),
  customerPhone: z.string().trim().max(32).nullable().optional(),
  heldSaleId: z.string().trim().min(1).max(100).nullable().optional(),
}).strict();

const holdInput = z.object({
  items: z.array(z.object({
    productId: z.string().trim().min(1).max(100),
    quantity: z.number().int().min(1).max(100000),
    weightGrams: z.number().int().min(1).max(1000000).nullable().optional(),
    productName: z.string().trim().min(1).max(180),
    sku: z.string().trim().min(1).max(80),
    price: z.number().finite().nonnegative().max(999999999),
    unitLabel: z.string().trim().max(50),
  }).strict()).min(1).max(100),
  customerName: z.string().trim().max(120).nullable().optional(),
  customerPhone: z.string().trim().max(32).nullable().optional(),
}).strict();

const cashMovementInput = z.object({
  type: z.enum(['CASH_IN', 'CASH_OUT']),
  amount: z.number().finite().positive().max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100))),
  note: z.string().trim().min(1).max(240),
}).strict();

const refundInput = z.object({
  amount: z.number().finite().positive().max(999999999)
    .refine((value) => Number.isSafeInteger(Math.round(value * 100))),
  reason: z.string().trim().min(2).max(500),
  restockStock: z.boolean().default(false),
}).strict();

const refundResolutionInput = z.object({
  decision: z.enum(['APPROVE', 'REJECT']),
}).strict();

const paymentInput = z.object({
  paymentMethod: z.enum(['CASH', 'DIGITAL']),
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

function roundMoney(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function serializeSale(sale: {
  id: string;
  receiptNumber: string;
  customerName: string | null;
  customerPhone: string | null;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  subtotal: Prisma.Decimal;
  discount: Prisma.Decimal;
  total: Prisma.Decimal;
  refundedAmount: Prisma.Decimal;
  createdAt: Date;
  items: Array<{
    id: string;
    productId: string | null;
    productName: string;
    sku: string;
    quantity: number;
    weightGrams: number | null;
    unitPrice: Prisma.Decimal;
    lineTotal: Prisma.Decimal;
  }>;
}) {
  return {
    id: sale.id,
    receiptNumber: sale.receiptNumber,
    customerName: sale.customerName,
    customerPhone: sale.customerPhone,
    status: sale.status,
    paymentMethod: sale.paymentMethod,
    paymentStatus: sale.paymentStatus,
    subtotal: Number(sale.subtotal),
    discount: Number(sale.discount),
    total: Number(sale.total),
    refundedAmount: Number(sale.refundedAmount),
    createdAt: sale.createdAt.toISOString(),
    items: sale.items.map((item) => ({
      id: item.id,
      productId: item.productId,
      productName: item.productName,
      sku: item.sku,
      quantity: item.quantity,
      weightGrams: item.weightGrams,
      unitPrice: Number(item.unitPrice),
      lineTotal: Number(item.lineTotal),
    })),
  };
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

  router.get('/shifts', adminOnly, async (req, res) => {
    const parsed = z.object({
      page: z.coerce.number().int().min(1).max(10000).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
    }).strict().safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose a valid shift-history page.' });
    }
    try {
      const [shifts, total] = await Promise.all([
        prisma.posShift.findMany({
          orderBy: { openedAt: 'desc' },
          skip: (parsed.data.page - 1) * parsed.data.pageSize,
          take: parsed.data.pageSize,
          include: { cashier: { select: { name: true } } },
        }),
        prisma.posShift.count(),
      ]);
      return res.json({
        shifts: shifts.map((shift) => ({
          id: shift.id,
          status: shift.status,
          openingCash: Number(shift.openingCash),
          expectedClosingCash: shift.expectedClosingCash === null
            ? null
            : Number(shift.expectedClosingCash),
          actualClosingCash: shift.actualClosingCash === null
            ? null
            : Number(shift.actualClosingCash),
          variance: shift.expectedClosingCash === null ||
              shift.actualClosingCash === null
            ? null
            : roundMoney(
              Number(shift.actualClosingCash) -
                Number(shift.expectedClosingCash),
            ),
          openedAt: shift.openedAt,
          closedAt: shift.closedAt,
          cashierName: shift.cashier.name,
        })),
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
                { name: { contains: query, mode: 'insensitive' } },
                { email: { contains: query, mode: 'insensitive' } },
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
            status: { not: 'CANCELLED' },
            ...saleScope,
          },
          select: {
            total: true,
            paymentMethod: true,
            paymentStatus: true,
            status: true,
            refundedAmount: true,
          },
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
              status: { not: 'CANCELLED' },
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
      const paidSales = sales.filter((sale) => sale.paymentStatus === 'COMPLETED');
      const cashSales = paidSales
        .filter((sale) => sale.paymentMethod === 'CASH')
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
      const digitalSales = paidSales
        .filter((sale) => sale.paymentMethod === 'DIGITAL')
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
        .reduce((sum, sale) => sum + Number(sale.total), 0);
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
            where: { shiftId: currentShift.id, status: { not: 'CANCELLED' } },
            select: {
              total: true,
              paymentMethod: true,
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
            if (sale.paymentMethod !== 'CASH') return sum;
            const refunds = sale.refunds.reduce(
              (amount, refund) => amount + Number(refund.amount),
              0,
            );
            return sum + Number(sale.total) - refunds;
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

  router.post('/shifts/open', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = openShiftInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid opening cash amount.' });
    }
    try {
      const shift = await runTransactionWithRetry(prisma, async (tx) => {
        const existing = await tx.posShift.findFirst({
          where: { status: 'OPEN', cashierId },
          select: { id: true },
        });
        if (existing) throw new Error('POS_SHIFT_ALREADY_OPEN');
        return tx.posShift.create({
          data: {
            cashierId,
            openingCash: parsed.data.openingCash,
          },
          include: { cashier: { select: { id: true, name: true } } },
        });
      });
      return res.status(201).json({
        shift: {
          id: shift.id,
          openingCash: Number(shift.openingCash),
          openedAt: shift.openedAt.toISOString(),
          cashier: shift.cashier,
        },
      });
    } catch (error) {
      if (error instanceof Error && error.message === 'POS_SHIFT_ALREADY_OPEN') {
        return res.status(409).json({ error: 'You already have an open cash register shift.' });
      }
      sendAdminError(error, res);
    }
  });

  router.post('/shifts/:id/close', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const actualCash = z.number().finite().min(0).max(999999999)
      .refine((value) => Number.isSafeInteger(Math.round(value * 100)))
      .safeParse(req.body?.actualCash);
    if (!actualCash.success) {
      return res.status(400).json({ error: 'Enter the counted closing cash amount.' });
    }
    try {
      const result = await runTransactionWithRetry(prisma, async (tx) => {
        const shift = await tx.posShift.findFirst({
          where: { id: req.params.id, cashierId, status: 'OPEN' },
          select: { id: true, openingCash: true },
        });
        if (!shift) return null;
        const [heldBillCount, pendingExchangeCount] = await Promise.all([
          tx.posHeldSale.count({ where: { shiftId: shift.id } }),
          tx.posExchange.count({
            where: { shiftId: shift.id, status: 'REFUND_REQUESTED' },
          }),
        ]);
        if (heldBillCount > 0) throw new Error('POS_HELD_BILLS_EXIST');
        if (pendingExchangeCount > 0) {
          throw new Error('POS_EXCHANGE_REFUNDS_PENDING');
        }
        const [sales, movements, exchanges] = await Promise.all([
          tx.posSale.findMany({
            where: { shiftId: shift.id, status: { not: 'CANCELLED' } },
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
          tx.posExchange.findMany({
            where: {
              shiftId: shift.id,
              status: { in: ['COMPLETED', 'REFUND_APPROVED'] },
            },
            select: {
              difference: true,
              paymentMethod: true,
              refundPaymentMethod: true,
            },
          }),
        ]);
        const expected = roundMoney(
          Number(shift.openingCash) +
          sales.reduce((sum, sale) => {
            if (sale.paymentMethod !== 'CASH') return sum;
            const refunds = sale.refunds.reduce(
              (amount, refund) => amount + Number(refund.amount),
              0,
            );
            return sum + Number(sale.total) - refunds;
          }, 0) +
          exchanges.reduce((sum, exchange) => {
            const difference = Number(exchange.difference);
            if (difference > 0 && exchange.paymentMethod === 'CASH') {
              return sum + difference;
            }
            if (difference < 0 && exchange.refundPaymentMethod === 'CASH') {
              return sum + difference;
            }
            return sum;
          }, 0) +
          movements.reduce(
            (sum, movement) => sum +
              (movement.type === 'CASH_IN' ? 1 : -1) * Number(movement.amount),
            0,
          ),
        );
        const closed = await tx.posShift.update({
          where: { id: shift.id },
          data: {
            status: 'CLOSED',
            expectedClosingCash: expected,
            actualClosingCash: actualCash.data,
            closedAt: new Date(),
          },
        });
        return { expected, shiftId: closed.id };
      });
      if (!result) return res.status(404).json({ error: 'Open register shift not found.' });
      return res.json(result);
    } catch (error) {
      if (error instanceof Error && error.message === 'POS_HELD_BILLS_EXIST') {
        return res.status(409).json({
          error: 'Resume or discard held bills before closing this register.',
        });
      }
      if (error instanceof Error &&
          error.message === 'POS_EXCHANGE_REFUNDS_PENDING') {
        return res.status(409).json({
          error: 'Resolve pending exchange refunds before closing this register.',
        });
      }
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
        const shift = await tx.posShift.findFirst({
          where: { cashierId: actorId, status: 'OPEN' },
          select: { id: true, openingCash: true },
        });
        if (!shift) throw new Error('POS_SHIFT_NOT_OPEN');
        const [sales, movements] = await Promise.all([
          tx.posSale.findMany({
            where: { shiftId: shift.id, status: { not: 'CANCELLED' } },
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
      if (error instanceof Error && error.message === 'POS_SHIFT_NOT_OPEN') {
        return res.status(409).json({ error: 'Open a register shift first.' });
      }
      if (error instanceof Error && error.message === 'POS_CASH_OUT_EXCEEDS_DRAWER') {
        return res.status(409).json({ error: 'Cash out cannot exceed the expected drawer balance.' });
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
      const shift = await prisma.posShift.findFirst({
        where: { cashierId, status: 'OPEN' },
        select: { id: true },
      });
      if (!shift) return res.status(409).json({ error: 'Open a register shift first.' });
      const heldSale = await prisma.posHeldSale.create({
        data: {
          shiftId: shift.id,
          customerName: parsed.data.customerName ?? null,
          customerPhone: parsed.data.customerPhone ?? null,
          items: parsed.data.items as Prisma.InputJsonValue,
        },
      });
      return res.status(201).json({ id: heldSale.id });
    } catch (error) {
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
        inventory: { select: { totalStock: true, reservedStock: true } },
      } satisfies Prisma.ProductSelect;
      const exactProduct = query.data
        ? await prisma.product.findFirst({
          where: {
            isActive: true,
            OR: [
              { id: query.data },
              { sku: { equals: query.data, mode: 'insensitive' } },
              { barcode: { equals: query.data, mode: 'insensitive' } },
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
                { name: { contains: query.data, mode: 'insensitive' } },
                { sku: { contains: query.data, mode: 'insensitive' } },
                { barcode: { contains: query.data, mode: 'insensitive' } },
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
    if (!parsed.success) return res.status(400).json({ error: 'Check the bill items and payment details.' });
    const receiptNumber = parsed.data.idempotencyKey
      ? `POS-${parsed.data.idempotencyKey.toUpperCase()}`
      : `POS-${Date.now()}-${randomUUID().slice(0, 8).toUpperCase()}`;
    try {
      let replayed = false;
      const sale = await runTransactionWithRetry(prisma, async (tx) => {
        if (parsed.data.idempotencyKey) {
          const existing = await tx.posSale.findUnique({
            where: { receiptNumber },
            include: { items: true, shift: { select: { cashierId: true } } },
          });
          if (existing) {
            if (existing.shift.cashierId !== cashierId) {
              throw new Error('POS_IDEMPOTENCY_KEY_REUSED');
            }
            replayed = true;
            return existing;
          }
        }
        const shift = await tx.posShift.findFirst({
          where: { cashierId, status: 'OPEN' },
          select: { id: true },
        });
        if (!shift) throw new Error('POS_SHIFT_NOT_OPEN');
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
          const lineTotal = roundMoney(
            unitPrice * (weightGrams === null ? item.quantity : weightGrams / 1000),
          );
          return {
            product,
            quantity: item.quantity,
            weightGrams,
            stockQuantity,
            unitPrice,
            lineTotal,
          };
        });
        const stockTotals = new Map<string, number>();
        for (const line of lines) {
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
        const subtotal = roundMoney(lines.reduce((sum, line) => sum + line.lineTotal, 0));
        const discount = roundMoney(parsed.data.discount);
        if (discount > subtotal) throw new Error('POS_DISCOUNT_EXCEEDS_TOTAL');
        const total = roundMoney(subtotal - discount);
        const sale = await tx.posSale.create({
          data: {
            receiptNumber,
            shiftId: shift.id,
            customerName: parsed.data.customerName ?? null,
            customerPhone: parsed.data.customerPhone ?? null,
            paymentMethod: parsed.data.paymentMethod,
            paymentStatus: parsed.data.paymentMethod === 'PENDING'
              ? 'PENDING'
              : 'COMPLETED',
            subtotal,
            discount,
            total,
            items: {
              create: lines.map((line) => ({
                productId: line.product.id,
                productName: line.product.name,
                sku: line.product.sku,
                quantity: line.quantity,
                weightGrams: line.weightGrams,
                unitPrice: line.unitPrice,
                lineTotal: line.lineTotal,
              })),
            },
          },
          include: { items: true },
        });
        await inventoryService.consumeStockForPosSale(
          tx,
          [...stockTotals].map(([productId, quantity]) => ({
            productId,
            quantity,
          })),
          sale.id,
          cashierId,
        );
        if (parsed.data.heldSaleId) {
          await tx.posHeldSale.deleteMany({
            where: { id: parsed.data.heldSaleId, shiftId: shift.id },
          });
        }
        return sale;
      });
      return res.status(replayed ? 200 : 201).json({ sale: serializeSale(sale) });
    } catch (error) {
      if (
        parsed.data.idempotencyKey &&
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        try {
          const existing = await prisma.posSale.findUnique({
            where: { receiptNumber },
            include: { items: true, shift: { select: { cashierId: true } } },
          });
          if (existing?.shift.cashierId === cashierId) {
            return res.status(200).json({ sale: serializeSale(existing) });
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
          POS_SHIFT_NOT_OPEN: 'Open a register shift before completing a bill.',
          POS_PRODUCT_UNAVAILABLE: 'One or more products are no longer available.',
          POS_WEIGHT_REQUIRED: 'Enter a weight for each product sold by weight.',
          POS_INSUFFICIENT_STOCK: 'The requested quantity exceeds available stock.',
          POS_DISCOUNT_EXCEEDS_TOTAL: 'The discount cannot exceed the bill subtotal.',
        };
        if (clientErrors[error.message]) {
          return res.status(409).json({ error: clientErrors[error.message] });
        }
      }
      if (error instanceof InventoryAdjustmentError) {
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
        ...(range
          ? { createdAt: { gte: range.start, lt: range.end } }
          : {}),
        ...(isBillingStaff && cashierId ? { shift: { cashierId } } : {}),
      };
      const [sales, total] = await Promise.all([
        prisma.posSale.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          skip: (parsed.data.page - 1) * parsed.data.pageSize,
          take: parsed.data.pageSize,
          include: { items: true },
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

  router.patch('/sales/:id/payment', async (req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = paymentInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose cash or digital payment.' });
    }
    try {
      const updated = await prisma.posSale.updateMany({
        where: {
          id: req.params.id,
          paymentStatus: 'PENDING',
          status: { not: 'CANCELLED' },
          shift: { cashierId },
        },
        data: {
          paymentMethod: parsed.data.paymentMethod,
          paymentStatus: 'COMPLETED',
        },
      });
      if (updated.count !== 1) {
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
            sale.status === 'CANCELLED' ||
            sale.paymentStatus !== 'PENDING' ||
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

  router.get('/refunds', adminOnly, async (_req, res) => {
    try {
      const refunds = await prisma.posRefund.findMany({
        orderBy: { requestedAt: 'desc' },
        take: 100,
        include: {
          sale: { select: { receiptNumber: true, total: true, paymentMethod: true } },
          requestedBy: { select: { name: true } },
        },
      });
      return res.json({
        refunds: refunds.map((refund) => ({
          id: refund.id,
          saleId: refund.saleId,
          receiptNumber: refund.sale.receiptNumber,
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
    try {
      const refund = await prisma.$transaction(async (tx) => {
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
        if (!sale || sale.status === 'CANCELLED') throw new Error('POS_SALE_NOT_REFUNDABLE');
        if (sale.exchanges.length > 0) {
          throw new Error('POS_REFUND_EXCHANGE_EXISTS');
        }
        const alreadyRefunded = sale.refunds.reduce(
          (sum, item) => sum + Number(item.amount),
          0,
        );
        const remaining = roundMoney(Number(sale.total) - alreadyRefunded);
        if (parsed.data.amount > remaining) throw new Error('POS_REFUND_TOO_LARGE');
        if (parsed.data.restockStock &&
            (alreadyRefunded > 0 ||
              parsed.data.amount !== Number(sale.total))) {
          throw new Error('POS_RESTOCK_REQUIRES_FULL_REFUND');
        }
        return tx.posRefund.create({
          data: {
            saleId: sale.id,
            requestedById,
            amount: parsed.data.amount,
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
          POS_REFUND_TOO_LARGE: 'The refund exceeds the remaining refundable amount.',
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
        if (totalRefunded + otherPendingRefunds > Number(refund.sale.total)) {
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
      sendAdminError(error, res);
    }
  });

  router.get('/exchanges', async (_req, res) => {
    const cashierId = authenticatedAdminId(res);
    if (!cashierId) {
      return res.status(401).json({ error: 'Authentication is required.' });
    }
    try {
      const isBillingStaff = authenticatedRole(res) === 'BILLING_STAFF';
      const exchanges = await prisma.posExchange.findMany({
        where: isBillingStaff ? { cashierId } : undefined,
        orderBy: { requestedAt: 'desc' },
        take: 100,
        include: {
          sale: { select: { receiptNumber: true } },
          cashier: { select: { name: true } },
          items: true,
        },
      });
      return res.json({
        exchanges: exchanges.map((exchange) => ({
          id: exchange.id,
          saleId: exchange.saleId,
          receiptNumber: exchange.sale.receiptNumber,
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

        const shift = await tx.posShift.findFirst({
          where: { cashierId, status: 'OPEN' },
          select: { id: true },
        });
        if (!shift) throw new Error('POS_SHIFT_NOT_OPEN');

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
        if (!sale || sale.status === 'CANCELLED' ||
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
          POS_SHIFT_NOT_OPEN: {
            status: 409,
            message: 'Open a register shift before processing an exchange.',
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
