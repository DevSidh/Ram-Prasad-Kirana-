import { Router, type RequestHandler, type Response } from 'express';
import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { getLocalDayRange } from '../services/local-day.js';
import { sendPushToUser } from '../services/push-notifications.js';

const assignmentQuery = z.object({
  status: z.enum([
    'ASSIGNED', 'ACCEPTED', 'DECLINED', 'PICKED_UP',
    'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED', 'CANCELLED',
  ]).optional(),
});
const availabilityInput = z.object({ isAvailable: z.boolean() }).strict();
const locationInput = z.object({
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
}).strict();
const updateInput = z.object({
  status: z.enum([
    'ACCEPTED', 'DECLINED', 'PICKED_UP',
    'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED',
  ]),
  reason: z.string().trim().max(500).optional(),
  recipientName: z.string().trim().min(1).max(120).optional(),
  cashCollected: z.number().finite().nonnegative().optional(),
}).strict();

function riderId(res: Response): string | null {
  const id = res.locals.authenticatedUserId;
  return typeof id === 'string' ? id : null;
}

function invalidRequest(res: Response, message: string) {
  return res.status(400).json({ error: message });
}

function calculateCashDue(
  total: number,
  paidOnline: number,
  paymentMethod: string,
): number {
  if (paymentMethod !== 'COD' && paidOnline <= 0) return 0;
  return Math.max(0, total - paidOnline);
}

export function createDeliveryRouter(
  prisma: PrismaClient,
  authenticateToken: RequestHandler,
  requireDeliveryPerson: RequestHandler,
): Router {
  const router = Router();
  router.use(authenticateToken, requireDeliveryPerson);

  router.get('/assignments', async (req, res) => {
    const parsed = assignmentQuery.safeParse(req.query);
    if (!parsed.success) return invalidRequest(res, 'Invalid delivery filter.');
    const userId = riderId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });

    try {
      const { start: todayStart, end: tomorrowStart } = getLocalDayRange();
      const riderWhere = { deliveryPersonId: userId };
      const [
        deliveries,
        cashToHandOver,
        assigned,
        inProgress,
        deliveredToday,
        cashCollectedToday,
      ] = await Promise.all([
        prisma.delivery.findMany({
          where: {
            ...riderWhere,
            ...(parsed.data.status ? { status: parsed.data.status } : {}),
          },
          orderBy: [{ status: 'asc' }, { assignedAt: 'desc' }],
          take: 100,
          select: {
            id: true,
            status: true,
            assignedAt: true,
            pickedUpAt: true,
            deliveredAt: true,
            cashCollected: true,
            cashCollectedAt: true,
            cashHandedOver: true,
            cashHandedOverAt: true,
            customerLatitude: true,
            customerLongitude: true,
            customerLocationUpdatedAt: true,
            statusHistory: {
              orderBy: { createdAt: 'desc' },
              take: 5,
              select: { status: true, note: true, createdAt: true },
            },
            order: {
              select: {
                id: true,
                orderNumber: true,
                status: true,
                paymentMethod: true,
                paymentStatus: true,
                total: true,
                shippingName: true,
                shippingPhone: true,
                shippingAddress: true,
                shippingCity: true,
                shippingDistrict: true,
                shippingProvince: true,
                shippingPostalCode: true,
                notes: true,
                createdAt: true,
                user: { select: { name: true, phone: true } },
                address: { select: { latitude: true, longitude: true } },
                payments: {
                  where: { status: 'COMPLETED' },
                  select: { amount: true },
                },
                items: {
                  select: {
                    productName: true,
                    quantity: true,
                    weightGrams: true,
                  },
                },
              },
            },
          },
        }),
        prisma.delivery.aggregate({
          where: {
            ...riderWhere,
            status: 'DELIVERED',
            cashCollected: { gt: 0 },
            cashHandedOverAt: null,
          },
          _sum: { cashCollected: true },
        }),
        prisma.delivery.count({
          where: { ...riderWhere, status: { in: ['ASSIGNED', 'ACCEPTED'] } },
        }),
        prisma.delivery.count({
          where: {
            ...riderWhere,
            status: { in: ['PICKED_UP', 'OUT_FOR_DELIVERY'] },
          },
        }),
        prisma.delivery.count({
          where: {
            ...riderWhere,
            status: 'DELIVERED',
            deliveredAt: { gte: todayStart, lt: tomorrowStart },
          },
        }),
        prisma.delivery.aggregate({
          where: {
            ...riderWhere,
            status: 'DELIVERED',
            deliveredAt: { gte: todayStart, lt: tomorrowStart },
          },
          _sum: { cashCollected: true },
        }),
      ]);

      return res.json({
        assignments: deliveries.map((delivery) => {
          const { order } = delivery;
          const customerLocationFresh =
            delivery.status === 'OUT_FOR_DELIVERY' &&
            delivery.customerLocationUpdatedAt !== null &&
            Date.now() - delivery.customerLocationUpdatedAt.getTime() <= 120_000;
          const paidOnline = order.payments.reduce(
            (sum, payment) => sum + Number(payment.amount),
            0,
          );
          return {
            id: delivery.id,
            status: delivery.status,
            assignedAt: delivery.assignedAt?.toISOString() ?? null,
            pickedUpAt: delivery.pickedUpAt?.toISOString() ?? null,
            deliveredAt: delivery.deliveredAt?.toISOString() ?? null,
            cashCollected: Number(delivery.cashCollected),
            cashCollectedAt: delivery.cashCollectedAt?.toISOString() ?? null,
            cashHandedOver: Number(delivery.cashHandedOver),
            cashHandedOverAt: delivery.cashHandedOverAt?.toISOString() ?? null,
            history: delivery.statusHistory.map((entry) => ({
              status: entry.status,
              note: entry.note,
              createdAt: entry.createdAt.toISOString(),
            })),
            order: {
              id: order.id,
              orderNumber: order.orderNumber,
              status: order.status,
              paymentMethod: order.paymentMethod,
              paymentStatus: order.paymentStatus,
              total: Number(order.total),
              cashDue: calculateCashDue(
                Number(order.total),
                paidOnline,
                order.paymentMethod,
              ),
              customerName: order.shippingName || order.user.name,
              customerPhone: order.shippingPhone || order.user.phone || '',
              address: [
                order.shippingAddress,
                order.shippingCity,
                order.shippingDistrict,
                order.shippingProvince,
                order.shippingPostalCode,
              ].filter(Boolean).join(', '),
              latitude: order.address?.latitude ?? null,
              longitude: order.address?.longitude ?? null,
              customerLatitude: customerLocationFresh
                ? delivery.customerLatitude
                : null,
              customerLongitude: customerLocationFresh
                ? delivery.customerLongitude
                : null,
              customerLocationUpdatedAt: customerLocationFresh
                ? delivery.customerLocationUpdatedAt?.toISOString() ?? null
                : null,
              instructions: order.notes ?? '',
              createdAt: order.createdAt.toISOString(),
              items: order.items.map((item) => ({
                name: item.productName,
                quantity: item.quantity,
                weightGrams: item.weightGrams,
              })),
            },
          };
        }),
        summary: {
          assigned,
          inProgress,
          deliveredToday,
          cashCollectedToday: Number(cashCollectedToday._sum.cashCollected ?? 0),
          cashToHandOver: Number(cashToHandOver._sum.cashCollected ?? 0),
        },
      });
    } catch (error) {
      console.error('Delivery assignment list failed:', error);
      return res.status(500).json({ error: 'Unable to load your deliveries.' });
    }
  });

  router.patch('/availability', async (req, res) => {
    const parsed = availabilityInput.safeParse(req.body);
    if (!parsed.success) return invalidRequest(res, 'Choose a valid availability setting.');
    const userId = riderId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });

    try {
      const result = await prisma.$transaction(async (tx) => {
        if (!parsed.data.isAvailable) {
          const activeCount = await tx.delivery.count({
            where: {
              deliveryPersonId: userId,
              status: {
                in: ['ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'OUT_FOR_DELIVERY'],
              },
            },
          });
          if (activeCount > 0) return { kind: 'active-deliveries' as const };
        }
        const user = await tx.user.update({
          where: { id: userId },
          data: { isAvailable: parsed.data.isAvailable },
          select: { isAvailable: true },
        });
        return { kind: 'updated' as const, isAvailable: user.isAvailable };
      });
      if (result.kind === 'active-deliveries') {
        return res.status(409).json({
          error: 'Finish or ask a manager to reassign active deliveries before going unavailable.',
        });
      }
      return res.json({ isAvailable: result.isAvailable });
    } catch (error) {
      console.error('Delivery availability update failed:', error);
      return res.status(500).json({ error: 'Unable to update availability.' });
    }
  });

  router.post('/assignments/:id/location', async (req, res) => {
    const userId = riderId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    if (!req.params.id || req.params.id.length > 100) {
      return invalidRequest(res, 'A valid delivery assignment is required.');
    }
    const parsed = locationInput.safeParse(req.body);
    if (!parsed.success) return invalidRequest(res, 'Send a valid delivery location.');

    try {
      const updated = await prisma.delivery.updateMany({
        where: {
          id: req.params.id,
          deliveryPersonId: userId,
          status: 'OUT_FOR_DELIVERY',
        },
        data: {
          latitude: parsed.data.latitude,
          longitude: parsed.data.longitude,
          locationUpdatedAt: new Date(),
        },
      });
      if (updated.count !== 1) {
        return res.status(409).json({
          error: 'Live location is accepted only for your active delivery.',
        });
      }
      return res.sendStatus(204);
    } catch (error) {
      console.error('Delivery location update failed:', error);
      return res.status(500).json({ error: 'Unable to update your delivery location.' });
    }
  });

  router.patch('/assignments/:id', async (req, res) => {
    const userId = riderId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = updateInput.safeParse(req.body);
    if (!parsed.success) return invalidRequest(res, 'Invalid delivery update.');
    const { status, reason, recipientName, cashCollected } = parsed.data;
    if ((status === 'DECLINED' || status === 'FAILED') && !reason?.trim()) {
      return invalidRequest(res, 'Add a reason so the store can follow up.');
    }
    if (status === 'DELIVERED' && !recipientName?.trim()) {
      return invalidRequest(res, 'Enter the name of the person who received the order.');
    }

    try {
      const result = await prisma.$transaction(async (tx) => {
        const current = await tx.delivery.findFirst({
          where: { id: req.params.id, deliveryPersonId: userId },
          select: {
            id: true,
            status: true,
            order: {
              select: {
                id: true,
                orderNumber: true,
                status: true,
                paymentMethod: true,
                paymentStatus: true,
                userId: true,
                total: true,
                payments: {
                  where: { status: 'COMPLETED' },
                  select: { amount: true },
                },
              },
            },
          },
        });
        if (!current) return { kind: 'missing' as const };

        const allowed: Record<string, string[]> = {
          ASSIGNED: ['ACCEPTED', 'DECLINED'],
          ACCEPTED: ['PICKED_UP'],
          PICKED_UP: ['OUT_FOR_DELIVERY'],
          OUT_FOR_DELIVERY: ['DELIVERED', 'FAILED'],
          DECLINED: [],
          DELIVERED: [],
          FAILED: [],
          PENDING: [],
        };
        if (!allowed[current.status]?.includes(status)) {
          return { kind: 'invalid-transition' as const };
        }

        let amountCollected = 0;
        if (status === 'DELIVERED') {
          if (
            current.order.paymentMethod !== 'COD' &&
            current.order.paymentStatus !== 'COMPLETED'
          ) {
            return { kind: 'online-payment-unconfirmed' as const };
          }
          const amountDue = calculateCashDue(
            Number(current.order.total),
            current.order.payments.reduce(
              (sum, payment) => sum + Number(payment.amount),
              0,
            ),
            current.order.paymentMethod,
          );
          amountCollected = cashCollected ?? 0;
          if (Math.abs(amountCollected - amountDue) > 0.01) {
            return {
              kind: 'cash-mismatch' as const,
              cashDue: amountDue,
            };
          }
        } else if (cashCollected !== undefined) {
          return { kind: 'cash-not-allowed' as const };
        }

        const updated = await tx.delivery.updateMany({
          where: { id: current.id, deliveryPersonId: userId, status: current.status },
          data: {
            status,
            ...(current.status === 'OUT_FOR_DELIVERY' && status !== 'OUT_FOR_DELIVERY'
              ? {
                latitude: null,
                longitude: null,
                locationUpdatedAt: null,
                customerLatitude: null,
                customerLongitude: null,
                customerLocationUpdatedAt: null,
              }
              : {}),
            ...(status === 'PICKED_UP' ? { pickedUpAt: new Date() } : {}),
            ...(status === 'DELIVERED'
              ? {
                deliveredAt: new Date(),
                cashCollected: amountCollected,
                cashCollectedAt: new Date(),
              }
              : {}),
          },
        });
        if (updated.count !== 1) return { kind: 'conflict' as const };

        const note = status === 'DELIVERED'
          ? `Received by ${recipientName!.trim()}; cash collected: Rs. ${amountCollected.toFixed(2)}.`
          : reason?.trim() || `Delivery marked ${status.toLowerCase().replaceAll('_', ' ')}.`;
        await tx.deliveryStatusHistory.create({
          data: { deliveryId: current.id, changedById: userId, status, note },
        });

        if (status === 'OUT_FOR_DELIVERY' || status === 'DELIVERED') {
          const orderStatus = status === 'DELIVERED' ? 'DELIVERED' : 'OUT_FOR_DELIVERY';
          await tx.order.update({
            where: { id: current.order.id },
            data: {
              status: orderStatus,
              ...(status === 'DELIVERED' && current.order.paymentMethod === 'COD'
                ? { paymentStatus: 'COMPLETED' }
                : {}),
            },
          });
          await tx.orderStatusHistory.create({
            data: {
              orderId: current.order.id,
              status: orderStatus,
              note: status === 'DELIVERED'
                ? `Delivery completed by assigned delivery staff. ${note}`
                : 'Package picked up by assigned delivery staff.',
            },
          });
        }
        return {
          kind: 'updated' as const,
          orderId: current.order.id,
          orderNumber: current.order.orderNumber,
          customerId: current.order.userId,
        };
      });

      if (result.kind === 'missing') {
        return res.status(404).json({ error: 'This delivery is not assigned to your account.' });
      }
      if (result.kind === 'invalid-transition') {
        return res.status(409).json({ error: 'That delivery step is not available yet.' });
      }
      if (result.kind === 'cash-mismatch') {
        return res.status(400).json({
          error: `Record exactly Rs. ${result.cashDue.toFixed(2)} collected before completing delivery.`,
          cashDue: result.cashDue,
        });
      }
      if (result.kind === 'online-payment-unconfirmed') {
        return res.status(409).json({
          error: 'The store must confirm the online payment before this order can be completed.',
        });
      }
      if (result.kind === 'cash-not-allowed') {
        return res.status(400).json({ error: 'Cash can only be recorded when delivery is completed.' });
      }
      if (result.kind === 'conflict') {
        return res.status(409).json({ error: 'This delivery changed. Refresh and try again.' });
      }

      if (status === 'OUT_FOR_DELIVERY' || status === 'DELIVERED') {
        const notificationType = status === 'DELIVERED'
          ? 'ORDER_DELIVERED'
          : 'ORDER_OUT_FOR_DELIVERY';
        await prisma.notification.create({
          data: {
            userId: result.customerId,
            type: notificationType,
            title: status === 'DELIVERED' ? 'Order delivered' : 'Order on the way',
            body: status === 'DELIVERED'
              ? `Order ${result.orderNumber} has been delivered.`
              : `Order ${result.orderNumber} has been picked up for delivery.`,
            metadata: { orderId: result.orderId },
          },
        }).then(() => sendPushToUser(
          prisma,
          result.customerId,
          status === 'DELIVERED' ? 'Order delivered' : 'Order on the way',
          status === 'DELIVERED'
            ? `Order ${result.orderNumber} has been delivered.`
            : `Order ${result.orderNumber} has been picked up for delivery.`,
          { orderId: result.orderId },
        )).catch((error: unknown) => {
          console.error(`Unable to notify customer about delivery ${result.orderId}:`, error);
        });
      }
      return res.json({ message: 'Delivery updated.', status });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
        return res.status(404).json({ error: 'Delivery not found.' });
      }
      console.error('Delivery status update failed:', error);
      return res.status(500).json({ error: 'Unable to update this delivery.' });
    }
  });

  router.get('/profile', async (_req, res) => {
    const userId = riderId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, name: true, email: true, phone: true, isAvailable: true },
      });
      if (!user) return res.status(401).json({ error: 'Authentication is required.' });
      return res.json(user);
    } catch (error) {
      console.error('Delivery profile load failed:', error);
      return res.status(500).json({ error: 'Unable to load your profile.' });
    }
  });

  return router;
}
