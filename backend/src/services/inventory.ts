import { PrismaClient, Prisma } from '@prisma/client';
import { getLocalDayRange } from './local-day.js';

export class InventoryAdjustmentError extends Error {}

export type InventoryBatchDetails = {
  lotNumber?: string | null;
  manufacturedAt?: Date | null;
  expiresAt?: Date | null;
  noExpiry: boolean;
  datesVerified: boolean;
  purchasePrice?: number | null;
};

export class InventoryService {
  constructor(private prisma: PrismaClient) {}

  private async addBatch(
    tx: Prisma.TransactionClient,
    productId: string,
    quantity: number,
    details: InventoryBatchDetails,
  ): Promise<void> {
    await tx.inventoryBatch.create({
      data: {
        productId,
        lotNumber: details.lotNumber ?? null,
        manufacturedAt: details.manufacturedAt ?? null,
        expiresAt: details.expiresAt ?? null,
        noExpiry: details.noExpiry,
        datesVerified: details.datesVerified,
        receivedQuantity: quantity,
        remainingQuantity: quantity,
        purchasePrice: details.purchasePrice ?? null,
      },
    });
  }

  private async adjustBatchStock(
    tx: Prisma.TransactionClient,
    productId: string,
    adjustment: number,
    referenceId: string,
  ): Promise<void> {
    if (adjustment > 0) {
      await this.addBatch(tx, productId, adjustment, {
        lotNumber: `UNTRACKED-${referenceId.slice(0, 80)}`,
        noExpiry: false,
        datesVerified: false,
      });
      return;
    }
    if (adjustment === 0) return;

    const batches = await tx.$queryRaw<
      Array<{ id: string; remainingQuantity: number }>
    >`
      SELECT "id", "remainingQuantity"
      FROM "InventoryBatch"
      WHERE "productId" = ${productId}
        AND "remainingQuantity" > 0
      ORDER BY
        CASE WHEN "expiresAt" IS NULL THEN 1 ELSE 0 END,
        "expiresAt" ASC,
        "createdAt" ASC
      FOR UPDATE
    `;
    let remaining = -adjustment;
    for (const batch of batches) {
      if (remaining === 0) break;
      const quantity = Math.min(remaining, batch.remainingQuantity);
      const updated = await tx.inventoryBatch.updateMany({
        where: { id: batch.id, remainingQuantity: { gte: quantity } },
        data: { remainingQuantity: { decrement: quantity } },
      });
      if (updated.count !== 1) {
        throw new InventoryAdjustmentError(
          'A batch changed during the stock adjustment. Refresh and try again.',
        );
      }
      remaining -= quantity;
    }
    if (remaining > 0) {
      throw new InventoryAdjustmentError(
        'Batch quantities do not match inventory. Reconcile batches before adjusting stock.',
      );
    }
  }

  private async restockItem(
    tx: Prisma.TransactionClient,
    productId: string,
    quantity: number,
    referenceId: string,
    notes: string,
    performedById?: string,
    batch?: InventoryBatchDetails,
  ): Promise<void> {
    if (!Number.isSafeInteger(quantity) || quantity <= 0) {
      throw new InventoryAdjustmentError('Restock quantity must be a positive integer.');
    }

    const rows = await tx.$queryRaw<Array<{ totalStock: number; reservedStock: number }>>`
      SELECT "totalStock", "reservedStock"
      FROM "Inventory"
      WHERE "productId" = ${productId}
      FOR UPDATE
    `;
    const current = rows[0];
    if (!current) {
      const inventory = await tx.inventory.create({
        data: { productId, totalStock: quantity },
        select: { id: true },
      });
      await this.addBatch(tx, productId, quantity, batch ?? {
        lotNumber: `UNTRACKED-${referenceId.slice(0, 80)}`,
        noExpiry: false,
        datesVerified: false,
      });
      await tx.inventoryTransaction.create({
        data: {
          inventory: { connect: { id: inventory.id } },
          type: 'RESTOCKED',
          quantity,
          balanceAfter: quantity,
          referenceId,
          notes,
          ...(performedById
            ? { performedBy: { connect: { id: performedById } } }
            : {}),
        },
      });
      return;
    }

    const totalStock = current.totalStock + quantity;
    if (totalStock > 2147483647) {
      throw new InventoryAdjustmentError('Restock quantity exceeds the supported stock limit.');
    }
    const rowsAffected = await tx.$executeRaw`
      UPDATE "Inventory"
      SET "totalStock" = ${totalStock},
          "version" = "version" + 1,
          "updatedAt" = NOW()
      WHERE "productId" = ${productId}
        AND "totalStock" = ${current.totalStock}
        AND "reservedStock" = ${current.reservedStock}
    `;
    if (rowsAffected === 0) {
      throw new InventoryAdjustmentError(
        'Inventory changed concurrently. Refresh the product and try again.',
      );
    }

    await this.addBatch(tx, productId, quantity, batch ?? {
      lotNumber: `UNTRACKED-${referenceId.slice(0, 80)}`,
      noExpiry: false,
      datesVerified: false,
    });
    await tx.inventoryTransaction.create({
      data: {
        inventory: { connect: { productId } },
        type: 'RESTOCKED',
        quantity,
        balanceAfter: totalStock - current.reservedStock,
        referenceId,
        notes,
        ...(performedById
          ? { performedBy: { connect: { id: performedById } } }
          : {}),
      },
    });
  }

  async setStock(
    tx: Prisma.TransactionClient,
    productId: string,
    totalStock: number,
    referenceId: string,
    notes: string,
  ): Promise<void> {
    if (!Number.isSafeInteger(totalStock) || totalStock < 0) {
      throw new InventoryAdjustmentError('Stock must be a non-negative integer.');
    }

    const rows = await tx.$queryRaw<Array<{ totalStock: number; reservedStock: number }>>`
      SELECT "totalStock", "reservedStock"
      FROM "Inventory"
      WHERE "productId" = ${productId}
      FOR UPDATE
    `;
    const current = rows[0];

    if (!current) {
      const inventory = await tx.inventory.create({
        data: { productId, totalStock },
        select: { id: true },
      });
      if (totalStock > 0) {
        await this.addBatch(tx, productId, totalStock, {
          lotNumber: `UNTRACKED-${referenceId.slice(0, 80)}`,
          noExpiry: false,
          datesVerified: false,
        });
      }
      await tx.inventoryTransaction.create({
        data: {
          inventoryId: inventory.id,
          type: 'ADJUSTED',
          quantity: totalStock,
          balanceAfter: totalStock,
          referenceId,
          notes,
        },
      });
      return;
    }

    if (totalStock < current.reservedStock) {
      throw new InventoryAdjustmentError(
        `Stock cannot be set below the ${current.reservedStock} units reserved for orders.`,
      );
    }

    const adjustment = totalStock - current.totalStock;
    if (adjustment === 0) return;

    const rowsAffected = await tx.$executeRaw`
      UPDATE "Inventory"
      SET "totalStock" = ${totalStock},
          "version" = "version" + 1,
          "updatedAt" = NOW()
      WHERE "productId" = ${productId}
        AND "totalStock" = ${current.totalStock}
        AND "reservedStock" = ${current.reservedStock}
    `;
    if (rowsAffected === 0) {
      throw new InventoryAdjustmentError(
        'Inventory changed concurrently. Refresh the product and try again.',
      );
    }

    await this.adjustBatchStock(tx, productId, adjustment, referenceId);
    await tx.inventoryTransaction.create({
      data: {
        inventory: { connect: { productId } },
        type: 'ADJUSTED',
        quantity: adjustment,
        balanceAfter: totalStock - current.reservedStock,
        referenceId,
        notes,
      },
    });
  }

  /**
   * Safely reserves stock using atomic decrement with a conditional WHERE check.
   * Prevents race conditions and guarantees that stock never drops below 0,
   * even when 1,000 requests hit simultaneously for a product with 1 unit in stock.
   */
  async reserveStockForOrder(
    tx: Prisma.TransactionClient,
    items: { productId: string; quantity: number }[],
    orderId: string
  ): Promise<{ success: boolean; failedProductId?: string; reason?: string }> {
    for (const item of items) {
      const rowsAffected = await tx.$executeRaw`
        UPDATE "Inventory"
        SET 
          "reservedStock" = "reservedStock" + ${item.quantity},
          "version" = "version" + 1,
          "updatedAt" = NOW()
        WHERE 
          "productId" = ${item.productId}
          AND ("totalStock" - "reservedStock") >= ${item.quantity};
      `;

      if (rowsAffected === 0) {
        throw new Error(
          `INSUFFICIENT_STOCK: Product ${item.productId} does not have ${item.quantity} available unit(s).`
        );
      }

      const current = await tx.inventory.findUnique({
        where: { productId: item.productId },
        select: { totalStock: true, reservedStock: true },
      });

      await tx.inventoryTransaction.create({
        data: {
          inventory: { connect: { productId: item.productId } },
          type: 'RESERVED',
          quantity: item.quantity,
          balanceAfter: current ? current.totalStock - current.reservedStock : 0,
          referenceId: orderId,
          notes: `Stock reserved for Order #${orderId}`,
        },
      });
    }

    return { success: true };
  }

  async commitReservedStock(
    tx: Prisma.TransactionClient,
    items: { productId: string; quantity: number }[],
    orderId: string
  ): Promise<void> {
    for (const item of items) {
      await this.consumeBatchStock(tx, item.productId, item.quantity, orderId);
      const current = await tx.inventory.findUnique({
        where: { productId: item.productId },
        select: { totalStock: true, reservedStock: true },
      });

      await tx.$executeRaw`
        UPDATE "Inventory"
        SET 
          "totalStock" = "totalStock" - ${item.quantity},
          "reservedStock" = "reservedStock" - ${item.quantity},
          "version" = "version" + 1,
          "updatedAt" = NOW()
        WHERE "productId" = ${item.productId};
      `;

      await tx.inventoryTransaction.create({
        data: {
          inventory: { connect: { productId: item.productId } },
          type: 'PURCHASED',
          quantity: item.quantity,
          balanceAfter: current ? current.totalStock - item.quantity - current.reservedStock + item.quantity : 0,
          referenceId: orderId,
          notes: `Purchased and deducted for Order #${orderId}`,
        },
      });
    }
  }

  private async consumeBatchStock(
    tx: Prisma.TransactionClient,
    productId: string,
    quantity: number,
    orderId: string,
  ): Promise<void> {
    const today = getLocalDayRange().start;
    const batches = await tx.$queryRaw<
      Array<{ id: string; remainingQuantity: number }>
    >`
      SELECT "id", "remainingQuantity"
      FROM "InventoryBatch"
      WHERE "productId" = ${productId}
        AND "remainingQuantity" > 0
        AND ("expiresAt" IS NULL OR "expiresAt" >= ${today})
      ORDER BY
        CASE WHEN "expiresAt" IS NULL THEN 1 ELSE 0 END,
        "expiresAt" ASC,
        "createdAt" ASC
      FOR UPDATE
    `;
    let remaining = quantity;
    for (const batch of batches) {
      if (remaining === 0) break;
      const allocated = Math.min(remaining, batch.remainingQuantity);
      const updated = await tx.inventoryBatch.updateMany({
        where: { id: batch.id, remainingQuantity: { gte: allocated } },
        data: { remainingQuantity: { decrement: allocated } },
      });
      if (updated.count !== 1) {
        throw new Error(
          `INSUFFICIENT_STOCK: A product batch changed while reserving ${productId}.`,
        );
      }
      await tx.orderBatchAllocation.create({
        data: { orderId, productId, batchId: batch.id, quantity: allocated },
      });
      remaining -= allocated;
    }
    if (remaining > 0) {
      throw new Error(
        `INSUFFICIENT_STOCK: Product ${productId} has insufficient unexpired batch stock.`,
      );
    }
  }

  async receiveBatch(
    tx: Prisma.TransactionClient,
    productId: string,
    quantity: number,
    referenceId: string,
    details: InventoryBatchDetails,
    performedById: string,
    notes?: string,
  ): Promise<void> {
    await this.restockItem(
      tx,
      productId,
      quantity,
      referenceId,
      notes ?? `Batch ${details.lotNumber ?? 'received'} added by admin.`,
      performedById,
      details,
    );
  }

  async restoreCommittedStock(
    tx: Prisma.TransactionClient,
    productId: string,
    quantity: number,
    orderId: string,
  ): Promise<void> {
    const allocations = await tx.orderBatchAllocation.findMany({
      where: { orderId, productId },
      select: { id: true, batchId: true, quantity: true },
    });
    if (allocations.length === 0) {
      await this.addBatch(tx, productId, quantity, {
        lotNumber: `CANCELLED-${orderId}`,
        noExpiry: false,
        datesVerified: false,
      });
      return;
    }
    const allocatedQuantity = allocations.reduce(
      (total, allocation) => total + allocation.quantity,
      0,
    );
    if (allocatedQuantity !== quantity) {
      throw new InventoryAdjustmentError(
        'Order batch allocations do not match the quantity being returned.',
      );
    }
    for (const allocation of allocations) {
      await tx.inventoryBatch.update({
        where: { id: allocation.batchId },
        data: { remainingQuantity: { increment: allocation.quantity } },
      });
      await tx.orderBatchAllocation.delete({ where: { id: allocation.id } });
    }
  }

  async releaseReservedStock(
    tx: Prisma.TransactionClient,
    items: { productId: string; quantity: number }[],
    orderId: string
  ): Promise<void> {
    for (const item of items) {
      const current = await tx.inventory.findUnique({
        where: { productId: item.productId },
        select: { totalStock: true, reservedStock: true },
      });

      await tx.$executeRaw`
        UPDATE "Inventory"
        SET 
          "reservedStock" = GREATEST(0, "reservedStock" - ${item.quantity}),
          "version" = "version" + 1,
          "updatedAt" = NOW()
        WHERE "productId" = ${item.productId};
      `;

      await tx.inventoryTransaction.create({
        data: {
          inventory: { connect: { productId: item.productId } },
          type: 'RELEASED',
          quantity: item.quantity,
          balanceAfter: current ? current.totalStock - current.reservedStock + item.quantity : 0,
          referenceId: orderId,
          notes: `Released hold on Order #${orderId}`,
        },
      });
    }
  }

  async restock(
    tx: Prisma.TransactionClient,
    items: { productId: string; quantity: number }[],
    referenceId: string,
    notes?: string,
    performedById?: string,
  ): Promise<void> {
    for (const item of items) {
      await this.restockItem(
        tx,
        item.productId,
        item.quantity,
        referenceId,
        notes ?? `Stock restocked for ${referenceId}`,
        performedById,
      );
    }
  }

  async adjustInventory(
    tx: Prisma.TransactionClient,
    items: { productId: string; quantity: number }[],
    referenceId: string,
    notes?: string
  ): Promise<void> {
    for (const item of items) {
      await this.adjustBatchStock(tx, item.productId, item.quantity, referenceId);
      await tx.$executeRaw`
        UPDATE "Inventory"
        SET
          "totalStock" = "totalStock" + ${item.quantity},
          "version" = "version" + 1,
          "updatedAt" = NOW()
        WHERE "productId" = ${item.productId};
      `;

      const current = await tx.inventory.findUnique({
        where: { productId: item.productId },
        select: { totalStock: true, reservedStock: true },
      });
      await tx.inventoryTransaction.create({
        data: {
          inventory: { connect: { productId: item.productId } },
          type: 'ADJUSTED',
          quantity: item.quantity,
          balanceAfter: current
              ? current.totalStock - current.reservedStock
              : 0,
          referenceId,
          notes: notes ?? `Manual stock adjustment for ${referenceId}`,
        },
      });
    }
  }
}
