import { PrismaClient, Prisma } from '@prisma/client';

export class InventoryAdjustmentError extends Error {}

export class InventoryService {
  constructor(private prisma: PrismaClient) {}

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
    notes?: string
  ): Promise<void> {
    for (const item of items) {
      await tx.$executeRaw`
        UPDATE "Inventory"
        SET
          "totalStock" = "totalStock" + ${item.quantity},
          "version" = "version" + 1,
          "updatedAt" = NOW()
        WHERE "productId" = ${item.productId};
      `;

      await tx.inventoryTransaction.create({
        data: {
          inventory: { connect: { productId: item.productId } },
          type: 'RESTOCKED',
          quantity: item.quantity,
          balanceAfter: 0,
          referenceId,
          notes: notes ?? `Stock restocked for ${referenceId}`,
        },
      });
    }
  }

  async adjustInventory(
    tx: Prisma.TransactionClient,
    items: { productId: string; quantity: number }[],
    referenceId: string,
    notes?: string
  ): Promise<void> {
    for (const item of items) {
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
