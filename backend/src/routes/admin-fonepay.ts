import { Router, type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { configuredFonepayGateway, FonepayError, unavailableMessage } from '../services/fonepay-gateway.js';
import { FonepayPayments, publicFonepayRequest } from '../services/fonepay-payments.js';
import { serializeSale } from '../services/pos-sale-serializer.js';
import type { FonepayGateway } from '../services/fonepay-gateway.js';

/** Mounted behind the existing authenticated billing-staff middleware. */
export function createFonepayRouter(prisma: PrismaClient, gatewayFactory:()=>FonepayGateway=configuredFonepayGateway): Router {
  const router = Router();
  router.get('/config', (_req, res) => {
    try {
      const gateway=gatewayFactory();
      const interval=gateway.verificationPollSeconds;
      return res.json({enabled:true,environment:gateway.environment,
        ...(Number.isInteger(interval) && interval!>=5 && interval!<=120?{pollIntervalSeconds:interval}:{})});
    } catch (_) { return res.json({enabled:false,code:'FONEPAY_PROFILE_REQUIRED',message:unavailableMessage}); }
  });
  const handle = (operation: 'create' | 'get' | 'verify' | 'cancel' | 'finalize' | 'claim-print'): RequestHandler => async (req, res) => {
    const id = res.locals.authenticatedUserId;
    const role = res.locals.authenticatedUserRole;
    if (typeof id !== 'string' || !['ADMIN', 'BILLING_STAFF'].includes(role)) {
      return res.status(403).json({ error: 'Billing access required.' });
    }
    if (operation !== 'get' && !z.object({}).strict().safeParse(req.body ?? {}).success) {
      return res.status(400).json({ error: 'Amounts, statuses and verification evidence must not be supplied by the client.' });
    }
    try {
      const service = new FonepayPayments(prisma, gatewayFactory());
      const actor = { id, role };
      if(operation==='finalize') return res.json({sale:serializeSale(await service.finalize(req.params.id,actor))});
      if(operation==='claim-print') return res.json({allowed:await service.claimAutoPrint(req.params.id,actor)});
      const intent = operation === 'create'
        ? await service.create(req.params.saleId, actor)
        : await service[operation](req.params.id, actor);
      return res.json({ request: publicFonepayRequest(intent) });
    } catch (error) {
      if (error instanceof FonepayError) return res.status(error.statusCode).json({ code: error.code, error: error.message });
      // Never serialize/log raw provider objects: they may contain credentials.
      return res.status(503).json({ code: 'FONEPAY_UNAVAILABLE', error: 'Payment service is unavailable. No payment has been confirmed. Reconcile the same reference before retrying.' });
    }
  };
  router.post('/sales/:saleId/requests', handle('create'));
  router.get('/requests/:id', handle('get'));
  router.post('/requests/:id/verify', handle('verify'));
  router.post('/requests/:id/cancel', handle('cancel'));
  router.post('/requests/:id/finalize', handle('finalize'));
  router.post('/requests/:id/claim-print', handle('claim-print'));
  return router;
}
