import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { Prisma, type PrismaClient, type PosFonepayRequest } from '@prisma/client';
import { runTransactionWithRetry } from './transaction-retry.js';
import { InventoryService } from './inventory.js';
import { getStoreDayKey } from './local-day.js';
import { FonepayError, npr, paisa, type FonepayGateway, type FonepayRequest } from './fonepay-gateway.js';

type Actor = { id: string; role: string };
type Tx = Prisma.TransactionClient;
const active = ['CREATING', 'READY', 'PENDING', 'UNKNOWN'];
const fingerprint = (sale: { total: Prisma.Decimal; paidAmount: Prisma.Decimal; refundedAmount: Prisma.Decimal;
  subtotal: Prisma.Decimal; discount: Prisma.Decimal; vatRate: Prisma.Decimal; vatAmount: Prisma.Decimal;
  status: string; paymentStatus: string; invoiceNumber: string | null; updatedAt: Date }) =>
  createHash('sha256').update(JSON.stringify([
    sale.total.toString(), sale.paidAmount.toString(), sale.refundedAmount.toString(),
    sale.subtotal.toString(), sale.discount.toString(), sale.vatRate.toString(), sale.vatAmount.toString(),
    sale.status, sale.paymentStatus, sale.invoiceNumber, sale.updatedAt.toISOString(),
  ])).digest('hex');

async function bill(tx: Tx, id: string, actor: Actor) {
  const sale = await tx.posSale.findUnique({ where: { id }, include: { shift: { select: { cashierId: true } } } });
  if (!sale || (actor.role !== 'ADMIN' && sale.shift.cashierId !== actor.id)) {
    throw new FonepayError('BILL_NOT_FOUND', 'Bill not found or not accessible.', 404);
  }
  return sale;
}
const request = (intent: PosFonepayRequest): FonepayRequest => ({
  reference: intent.reference, merchantCode: intent.merchantCode, currency: 'NPR',
  amount: intent.amount.toFixed(2), invoiceNumber: intent.invoiceNumber,
});
export function publicFonepayRequest(intent: PosFonepayRequest) {
  return { id: intent.id, saleId: intent.saleId, invoiceNumber: intent.invoiceNumber,
    reference: intent.reference, merchantName: intent.merchantName, currency: intent.currency,
    amount: intent.amount.toFixed(2), state: intent.state, environment: intent.environment,
    qrPayload: ['READY', 'PENDING'].includes(intent.state) ? intent.qrPayload : null,
    expiresAt: intent.expiresAt?.toISOString() ?? null, failureCode: intent.failureCode,
    isTest: intent.environment !== 'live' };
}

async function deadline<T>(operation: Promise<T>): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try { return await Promise.race([operation, new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new FonepayError('PROVIDER_TIMEOUT', 'Fonepay response is uncertain. Verify this reference before retrying.', 502)), 12000);
  })]); } finally { if (timer) clearTimeout(timer); }
}

/** Orchestration only. A reviewed, official account-specific gateway is required. */
export class FonepayPayments {
  constructor(private prisma: PrismaClient, private gateway: FonepayGateway,
    private inventory: Pick<InventoryService,'consumeStockForPosSale'> = new InventoryService(prisma)) {}

  async create(saleId: string, actor: Actor): Promise<PosFonepayRequest> {
    let prepared: { intent: PosFonepayRequest; created: boolean };
    try {
      prepared = await runTransactionWithRetry(this.prisma, async (tx) => {
        const sale = await bill(tx, saleId, actor);
        if (!['CHECKOUT', 'COMPLETED'].includes(sale.status) || sale.paymentStatus !== 'PENDING') {
          throw new FonepayError('BILL_NOT_PAYABLE', 'Only a saved pending checkout or unpaid completed bill can request payment.');
        }
        const due = paisa(sale.total.toString()) - paisa(sale.paidAmount.toString());
        if (due <= 0n || paisa(sale.refundedAmount.toString()) !== 0n) throw new FonepayError('BILL_NOT_PAYABLE', 'Bill has no payable balance or has a refund.');
        const previous = await tx.posFonepayRequest.findUnique({ where: { activeKey: saleId } });
        if (previous) {
          if (previous.billFingerprint === fingerprint(sale) && (!previous.expiresAt || previous.expiresAt > new Date())) {
            return { intent: previous, created: false };
          }
          // Do not issue a new remotely-payable QR until the old attempt has
          // been explicitly retired and verified/reviewed by the operator.
          throw new FonepayError('PREVIOUS_REQUEST_ACTIVE', 'The previous payment request must be cancelled/reconciled before a replacement QR can be requested.');
        }
        const intent = await tx.posFonepayRequest.create({ data: {
          id: randomUUID(), saleId, reference: `FP${randomBytes(11).toString('hex')}`,
          activeKey: saleId, requestedById: actor.id, environment: this.gateway.environment,
          merchantCode: this.gateway.merchantCode, currency: 'NPR', amount: npr(due),
          billFingerprint: fingerprint(sale), invoiceNumber: sale.invoiceNumber ?? sale.receiptNumber,
        } });
        return { intent, created: true };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const existing = await this.prisma.posFonepayRequest.findUnique({ where: { activeKey: saleId } });
        if (existing) return this.get(existing.id, actor);
      }
      throw error;
    }
    if (!prepared.created) return this.get(prepared.intent.id, actor);
    const intent = prepared.intent;
    try {
      const qr = await deadline(this.gateway.create(request(intent)));
      if (qr.merchantCode !== intent.merchantCode || qr.reference !== intent.reference ||
          qr.currency !== 'NPR' || paisa(qr.amount) !== paisa(intent.amount.toString()) ||
          !qr.payload || qr.payload.length > 4096 || !qr.merchantName ||
          !(qr.expiresAt instanceof Date) || !Number.isFinite(qr.expiresAt.getTime()) || qr.expiresAt <= new Date()) {
        throw new FonepayError('INVALID_PROVIDER_QR', 'Fonepay QR response did not match this request.');
      }
      await runTransactionWithRetry(this.prisma, async (tx) => {
        const sale = await bill(tx, saleId, actor);
        const unchanged = fingerprint(sale) === intent.billFingerprint;
        await tx.posFonepayRequest.updateMany({ where: { id: intent.id, state: 'CREATING', activeKey: saleId }, data:
          unchanged ? { state: 'READY', qrPayload: qr.payload, merchantName: qr.merchantName, expiresAt: qr.expiresAt }
            : { state: 'STALE', failureCode: 'BILL_CHANGED' } });
      });
    } catch (error) {
      await this.prisma.posFonepayRequest.updateMany({ where: { id: intent.id, state: 'CREATING' },
        data: { state: 'UNKNOWN', failureCode: error instanceof FonepayError ? error.code : 'PROVIDER_UNCERTAIN' } });
      // Unknown remote result keeps the reference/active slot, never a new charge.
    }
    return this.get(intent.id, actor);
  }

  async get(id: string, actor: Actor): Promise<PosFonepayRequest> {
    return runTransactionWithRetry(this.prisma, async (tx) => {
      const intent = await tx.posFonepayRequest.findUnique({ where: { id } });
      if (!intent) throw new FonepayError('REQUEST_NOT_FOUND', 'Payment request not found.', 404);
      const sale = await bill(tx, intent.saleId, actor);
      if (active.includes(intent.state)) {
        const state = fingerprint(sale) !== intent.billFingerprint ? 'STALE'
          : intent.expiresAt && intent.expiresAt <= new Date() ? 'EXPIRED' : null;
        if (state) return tx.posFonepayRequest.update({ where: { id }, data: { state, qrPayload: null } });
      }
      return intent;
    });
  }

  async verify(id: string, actor: Actor): Promise<PosFonepayRequest> {
    const intent = await this.get(id, actor);
    if (['VERIFIED', 'PAID', 'TEST_VERIFIED'].includes(intent.state)) return intent;
    const lease = await this.prisma.posFonepayRequest.updateMany({
      where: { id, OR: [{ lastCheckedAt: null }, { lastCheckedAt: { lt: new Date(Date.now() - 5000) } }] },
      data: { lastCheckedAt: new Date() },
    });
    if (!lease.count) return intent;
    let proof;
    try { proof = await deadline(this.gateway.verify(request(intent))); }
    catch (_) { throw new FonepayError('VERIFICATION_UNAVAILABLE', 'Verification is unavailable. Payment remains unconfirmed; retry this reference.', 502); }
    try { return await runTransactionWithRetry(this.prisma, async (tx) => {
      const current = (await tx.posFonepayRequest.findUnique({ where: { id } }))!;
      if (['VERIFIED', 'PAID', 'TEST_VERIFIED'].includes(current.state)) return current;
      const sale = await bill(tx, current.saleId, actor);
      let exactAmount=false;
      try { exactAmount=paisa(proof.amount) === paisa(current.amount.toString()); } catch (_) { /* Invalid evidence never credits money. */ }
      const matches = proof.authenticated === true && proof.environment === current.environment &&
        proof.merchantCode === current.merchantCode && proof.reference === current.reference &&
        proof.currency === 'NPR' && exactAmount;
      if (!matches) return tx.posFonepayRequest.update({ where: { id }, data: { state: 'REVIEW', qrPayload: null, failureCode: 'VERIFICATION_MISMATCH' } });
      if (proof.status !== 'SUCCESS') {
        const retired=['FAILED','CANCELLED','EXPIRED'].includes(proof.status);
        const next = retired ? proof.status : active.includes(current.state) ? proof.status : current.state;
        return tx.posFonepayRequest.update({ where: { id }, data: {
          state: next, ...(retired ? { qrPayload: null, activeKey: null } : {}),
        } });
      }
      if (!proof.transactionId || !active.includes(current.state) || fingerprint(sale) !== current.billFingerprint ||
          (current.expiresAt && current.expiresAt <= new Date())) {
        return tx.posFonepayRequest.update({ where: { id }, data: { state: 'REVIEW', qrPayload: null, failureCode: 'LATE_OR_REVISED_BILL_PAYMENT' } });
      }
      if (current.environment !== 'live') return tx.posFonepayRequest.update({ where: { id },
        data: { state: 'TEST_VERIFIED', qrPayload: null, activeKey: null, providerTransactionId: proof.transactionId } });
      // Persist verified evidence BEFORE stock/invoice finalization. If the
      // latter fails, this proof survives and the same checkout can be retried.
      if (sale.status === 'CHECKOUT') return tx.posFonepayRequest.update({ where: { id }, data: {
        state:'VERIFIED', qrPayload:null, providerTransactionId:proof.transactionId,
        verifiedAt:new Date(), failureCode:null,
      } });
      // The unique provider transaction and deterministic collection ID are in
      // the SAME serializable transaction as the sale balance CAS.
      const updated = await tx.posSale.updateMany({ where: {
        id: sale.id, updatedAt: sale.updatedAt, total: sale.total, paidAmount: sale.paidAmount,
        refundedAmount: sale.refundedAmount, status: 'COMPLETED', paymentStatus: 'PENDING',
      }, data: { paidAmount: sale.total, paymentStatus: 'COMPLETED', paymentMethod: 'FONEPAY' } });
      if (updated.count !== 1) throw new FonepayError('BILL_CHANGED', 'Bill changed during verification. Reconcile this request before retrying.');
      await tx.posPaymentCollection.create({ data: {
        id: `FONEPAY-${current.id}`, saleId: sale.id, recordedById: current.requestedById,
        amount: current.amount, method: 'FONEPAY', note: `Fonepay verified reference ${current.reference}`,
      } });
      return tx.posFonepayRequest.update({ where: { id }, data: {
        state: 'PAID', activeKey: null, qrPayload: null, providerTransactionId: proof.transactionId, failureCode: null,
      } });
    }); } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        // The transaction rolled back both balance and collection. A provider
        // transaction already credited elsewhere requires reconciliation.
        await this.prisma.posFonepayRequest.updateMany({
          where: { id, state: { notIn: ['VERIFIED', 'PAID', 'TEST_VERIFIED'] } },
          data: { state: 'REVIEW', qrPayload: null, failureCode: 'DUPLICATE_PROVIDER_TRANSACTION' },
        });
        return this.get(id, actor);
      }
      throw error;
    }
  }

  async finalize(id: string, actor: Actor) {
    return runTransactionWithRetry(this.prisma, async (tx) => {
      const intent = await tx.posFonepayRequest.findUnique({ where:{id} });
      if (!intent) throw new FonepayError('REQUEST_NOT_FOUND','Payment request not found.',404);
      const sale = await bill(tx,intent.saleId,actor);
      if (intent.state === 'PAID') return tx.posSale.findUniqueOrThrow({
        where:{id:sale.id}, include:{items:true,paymentCollections:true},
      });
      if (intent.environment !== 'live' || intent.state !== 'VERIFIED' || !intent.verifiedAt || !intent.providerTransactionId) {
        throw new FonepayError('PAYMENT_NOT_VERIFIED','Only a backend-verified live payment can finalize a checkout.');
      }
      if (sale.status !== 'CHECKOUT' || fingerprint(sale) !== intent.billFingerprint ||
          paisa(sale.total.toString()) - paisa(sale.paidAmount.toString()) !== paisa(intent.amount.toString())) {
        throw new FonepayError('CHECKOUT_CHANGED','Verified payment retained. The checkout changed and requires reconciliation.');
      }
      const detail = await tx.posSale.findUniqueOrThrow({where:{id:sale.id},include:{items:true}});
      const quantities = new Map<string,number>();
      for (const item of detail.items) {
        if (!item.productId) throw new FonepayError('PRODUCT_UNAVAILABLE','Verified payment retained. Restore the missing product before finalizing.');
        quantities.set(item.productId,(quantities.get(item.productId) ?? 0)+(item.weightGrams ?? item.quantity));
      }
      await this.inventory.consumeStockForPosSale(tx,
        [...quantities].map(([productId,quantity])=>({productId,quantity})),sale.id,actor.id);
      const year=Number(getStoreDayKey(new Date()).slice(0,4));
      const sequence=await tx.invoiceSequence.upsert({where:{year},create:{year,nextNumber:1},update:{nextNumber:{increment:1}}});
      const updated=await tx.posSale.updateMany({where:{id:sale.id,status:'CHECKOUT',updatedAt:sale.updatedAt},data:{
        status:'COMPLETED',paymentStatus:'COMPLETED',paymentMethod:'FONEPAY',paidAmount:sale.total,
        invoiceNumber:`RPGS-INV-${year}-${String(sequence.nextNumber).padStart(6,'0')}`,
      }});
      if(updated.count!==1) throw new FonepayError('CHECKOUT_CHANGED','Checkout changed. Verified payment retained; retry finalization.');
      await tx.posPaymentCollection.create({data:{id:`FONEPAY-${id}`,saleId:sale.id,recordedById:intent.requestedById,
        amount:intent.amount,method:'FONEPAY',note:`Fonepay verified reference ${intent.reference}`}});
      await tx.posFonepayRequest.update({where:{id},data:{state:'PAID',activeKey:null,failureCode:null}});
      return tx.posSale.findUniqueOrThrow({where:{id:sale.id},include:{items:true,paymentCollections:true}});
    });
  }

  async claimAutoPrint(id:string,actor:Actor):Promise<boolean> {
    await this.get(id,actor);
    const claimed=await this.prisma.posFonepayRequest.updateMany({where:{id,state:'PAID',environment:'live',autoPrintClaimedAt:null},
      data:{autoPrintClaimedAt:new Date()}});
    return claimed.count===1;
  }

  async cancel(id: string, actor: Actor): Promise<PosFonepayRequest> {
    const intent = await this.get(id, actor);
    if (['VERIFIED', 'PAID', 'TEST_VERIFIED', 'REVIEW'].includes(intent.state)) throw new FonepayError('CANNOT_CANCEL', 'A verified, settled or review-required request cannot be cancelled.');
    // Without documented remote cancellation, keep the slot blocked. Never
    // imply that hiding a QR has stopped the bank from accepting it.
    if (!this.gateway.cancel) throw new FonepayError('REMOTE_CANCEL_UNSUPPORTED', 'Remote cancellation is not available for this merchant profile. Verify/reconcile the old request before issuing another QR.');
    await deadline(this.gateway.cancel(request(intent)));
    await this.prisma.posFonepayRequest.updateMany({ where: { id, state: { notIn: ['VERIFIED', 'PAID', 'TEST_VERIFIED', 'REVIEW'] } },
      data: { state: 'CANCELLED', activeKey: null, qrPayload: null } });
    return this.get(id, actor);
  }
}
