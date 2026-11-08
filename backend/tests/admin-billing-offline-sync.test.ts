import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';
import type { InventoryService } from '../src/services/inventory.js';

async function main(): Promise<void> {
    const since = new Date('2026-11-07T00:00:00.000Z');
    const updatedAt = new Date('2026-11-08T00:00:00.000Z');
    const calls: Record<string, Array<Record<string, unknown>>> = {
        products: [],
        wholesale: [],
        drinks: [],
        customers: [],
        bills: [],
        refunds: [],
        pending: [],
    };
    const sale = {
        id: 'sale-1',
        receiptNumber: 'POS-1001',
        invoiceNumber: 'INV-1001',
        customerName: 'Ram',
        customerPhone: '9800000000',
        status: 'COMPLETED',
        paymentMethod: 'CASH',
        paymentStatus: 'COMPLETED',
        paidAmount: 235,
        subtotal: 235,
        discount: 0,
        vatRate: 0,
        vatAmount: 0,
        total: 235,
        refundedAmount: 0,
        createdAt: updatedAt,
        updatedAt,
        items: [{
            id: 'sale-item-1', productId: 'product-1', productName: 'Tea', sku: 'TEA-1',
            quantity: 1, weightGrams: null, unitPrice: 235, lineTotal: 235,
        }],
        paymentCollections: [],
    };
    const prisma = {
        product: {
            findMany: async (args: Record<string, unknown>) => {
                calls.products.push(args);
                return [{
                    id: 'product-1', name: 'Tea', sku: 'TEA-1', barcode: '8901',
                    price: 235, unitLabel: 'pcs', imageUrl: null,
                    imageMimeType: 'image/jpeg', isActive: true, isVendingDrink: true,
                    updatedAt, inventory: { totalStock: 500, reservedStock: 20 },
                }];
            },
        },
        wholesaleItem: {
            findMany: async (args: Record<string, unknown>) => {
                calls.wholesale.push(args);
                return [{
                    id: 'wholesale-1', name: 'Rice sack', sku: 'RICE-25', price: 2500,
                    stock: 8, unitLabel: '25 kg', imageUrl: null, imageMimeType: null,
                    isActive: true, updatedAt,
                }];
            },
        },
        user: {
            findMany: async (args: Record<string, unknown>) => {
                calls.customers.push(args);
                return [{
                    id: 'customer-1', userNumber: 123n, name: 'Ram', email: 'ram@example.com',
                    phone: '9800000000', isActive: true, createdAt: updatedAt, updatedAt,
                }];
            },
        },
        posSale: {
            findMany: async (args: Record<string, unknown>) => {
                calls.bills.push(args);
                return [{ ...sale, paymentStatus: 'PENDING', paidAmount: 100 }];
            },
        },
        posRefund: {
            findMany: async (args: Record<string, unknown>) => {
                calls.refunds.push(args);
                return [{
                    id: 'refund-1', saleId: sale.id, amount: 10, reason: 'Damaged',
                    status: 'REQUESTED', restockStock: false, requestedAt: updatedAt,
                    resolvedAt: null, sale: {
                        receiptNumber: sale.receiptNumber,
                        customerName: sale.customerName, customerPhone: sale.customerPhone
                    },
                    requestedBy: { name: 'Cashier' },
                }];
            },
        },
    } as unknown as PrismaClient;
    const adminOnly: RequestHandler = (req, res, next) => {
        if (req.header('x-test-role') !== 'ADMIN') {
            return void res.status(403).json({ error: 'Administrator access required.' });
        }
        next();
    };
    const app = express();
    app.use('/billing', createAdminBillingRouter(
        prisma,
        {} as InventoryService,
        adminOnly,
    ));
    const server = app.listen(0);

    try {
        await new Promise<void>((resolve) => server.once('listening', resolve));
        const address = server.address();
        assert(address && typeof address !== 'string');
        const endpoint = `http://127.0.0.1:${address.port}/billing/offline-sync`;
        const denied = await fetch(endpoint);
        assert.equal(denied.status, 403);

        const response = await fetch(
            `${endpoint}?productsSince=${since.toISOString()}&customersSince=${since.toISOString()}`,
            { headers: { 'x-test-role': 'ADMIN' } },
        );
        assert.equal(response.status, 200);
        const body = await response.json() as Record<string, unknown>;
        assert.equal((body.products as Array<Record<string, unknown>>)[0].available, 480);
        assert.match(String((body.products as Array<Record<string, unknown>>)[0].imageUrl), /\/image\?v=/);
        assert.equal((body.bills as Array<Record<string, unknown>>)[0].id, sale.id);
        assert.equal((body.customers as Array<Record<string, unknown>>)[0].id, 'customer-1');
        assert.equal((body.refunds as Array<Record<string, unknown>>)[0].id, 'refund-1');
        assert.equal((body.pendingCash as Array<Record<string, unknown>>)[0].amount, 135);

        const productWhere = calls.products[0].where as Record<string, unknown>;
        const cutoff = new Date(body.cutoff as string);
        assert.deepEqual(productWhere.updatedAt, {
            gt: new Date('1970-01-01T00:00:00.000Z'),
            lte: cutoff,
        });
        assert.equal(calls.products.length, 1);
        assert.equal(calls.bills.length, 1);
        const productSelect = calls.products[0].select as Record<string, unknown>;
        assert.equal('imageData' in productSelect, false);
        assert.equal('imageMimeType' in productSelect, true);
        assert.deepEqual(
            (calls.bills[0].where as Record<string, unknown>).updatedAt,
            { gt: new Date('1970-01-01T00:00:00.000Z'), lte: cutoff },
        );
    } finally {
        await new Promise<void>((resolve, reject) =>
            server.close((error) => error ? reject(error) : resolve()),
        );
    }
}

void main().catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
});
