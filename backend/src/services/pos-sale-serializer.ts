import { Prisma } from '@prisma/client';
const roundMoney = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100;
export function serializeSale(sale: {
  id: string;
  receiptNumber: string;
  invoiceNumber: string | null;
  customerName: string | null;
  customerPhone: string | null;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  subtotal: Prisma.Decimal;
  discount: Prisma.Decimal;
  vatRate: Prisma.Decimal;
  vatAmount: Prisma.Decimal;
  total: Prisma.Decimal;
  paidAmount?: Prisma.Decimal;
  refundedAmount: Prisma.Decimal;
  createdAt: Date;
  paymentCollections?: Array<{
    id: string;
    amount: Prisma.Decimal;
    method: string;
    note: string | null;
    createdAt: Date;
  }>;
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
    invoiceNumber: sale.invoiceNumber ?? sale.receiptNumber,
    customerName: sale.customerName,
    customerPhone: sale.customerPhone,
    status: sale.status,
    paymentMethod: sale.paymentMethod,
    paymentStatus: sale.paymentStatus,
    subtotal: Number(sale.subtotal),
    discount: Number(sale.discount),
    vatRate: Number(sale.vatRate),
    vatAmount: Number(sale.vatAmount),
    total: Number(sale.total),
    paidAmount: sale.paidAmount === undefined
      ? sale.paymentStatus === 'COMPLETED' ? Number(sale.total) : 0
      : Number(sale.paidAmount),
    outstandingAmount: roundMoney(
      Math.max(
        0,
        Number(sale.total) -
          (sale.paidAmount === undefined
            ? sale.paymentStatus === 'COMPLETED' ? Number(sale.total) : 0
            : Number(sale.paidAmount)),
      ),
    ),
    refundedAmount: Number(sale.refundedAmount),
    createdAt: sale.createdAt.toISOString(),
    paymentCollections: (sale.paymentCollections ?? []).map((payment) => ({
      id: payment.id,
      amount: Number(payment.amount),
      method: payment.method,
      note: payment.note,
      createdAt: payment.createdAt.toISOString(),
    })),
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
