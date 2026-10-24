import type { NextFunction, Request, RequestHandler, Response } from 'express';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';

interface AuthenticatedRequest extends Request {
  userId?: string;
  userRole?: string;
}

export function createAuthMiddleware(prisma: PrismaClient, secret: string): {
  authenticateToken: RequestHandler;
  requireAdmin: RequestHandler;
  requireDeliveryPerson: RequestHandler;
  requireBillingStaff: RequestHandler;
} {
  const authenticateToken: RequestHandler = async (req, res, next) => {
    const authorization = req.headers.authorization;
    const match = authorization?.match(/^Bearer\s+(\S+)$/i);
    if (!match) {
      return res.status(401).json({ error: 'A valid bearer token is required' });
    }

    let decoded: string | jwt.JwtPayload;
    try {
      decoded = jwt.verify(match[1], secret);
    } catch {
      return res.status(401).json({ error: 'Invalid or expired access token' });
    }

    const userId = typeof decoded === 'object' && typeof decoded.id === 'string'
      ? decoded.id
      : undefined;
    if (!userId) {
      return res.status(401).json({ error: 'Invalid access token' });
    }

    const versionClaim = typeof decoded === 'object'
      ? decoded.tokenVersion
      : undefined;
    const tokenVersion = versionClaim === undefined
      ? 0
      : typeof versionClaim === 'number' &&
          Number.isSafeInteger(versionClaim) &&
          versionClaim >= 0
        ? versionClaim
        : null;
    if (tokenVersion === null) {
      return res.status(401).json({ error: 'Invalid access token' });
    }

    let user: { isActive: boolean; tokenVersion: number } | null;
    try {
      user = await prisma.user.findUnique({
        where: { id: userId },
        select: { isActive: true, tokenVersion: true },
      });
    } catch (error) {
      return next(error);
    }
    if (!user || !user.isActive || user.tokenVersion !== tokenVersion) {
      return res.status(401).json({ error: 'Invalid or revoked access token' });
    }

    res.locals.authenticatedUserId = userId;
    (req as AuthenticatedRequest).userId = userId;
    return next();
  };

  const requireAdmin: RequestHandler = async (req, res, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;
    if (!userId) {
      return res.status(401).json({ error: 'Authentication is required' });
    }

    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { role: true, isActive: true },
      });
      if (!user || !user.isActive) {
        return res.status(401).json({ error: 'Authentication is required' });
      }
      if (user.role !== 'ADMIN') {
        return res.status(403).json({ error: 'Administrator access required' });
      }

      (req as AuthenticatedRequest).userRole = user.role;
      res.locals.authenticatedUserRole = user.role;
      return next();
    } catch (error) {
      return next(error);
    }
  };

  const requireBillingStaff: RequestHandler = async (req, res, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;
    if (!userId) {
      return res.status(401).json({ error: 'Authentication is required' });
    }

    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { role: true, isActive: true },
      });
      if (!user || !user.isActive) {
        return res.status(401).json({ error: 'Authentication is required' });
      }
      if (user.role !== 'ADMIN' && user.role !== 'BILLING_STAFF') {
        return res.status(403).json({ error: 'Billing staff access required' });
      }

      (req as AuthenticatedRequest).userRole = user.role;
      res.locals.authenticatedUserRole = user.role;
      return next();
    } catch (error) {
      return next(error);
    }
  };

  const requireDeliveryPerson: RequestHandler = async (req, res, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;
    if (!userId) {
      return res.status(401).json({ error: 'Authentication is required' });
    }

    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { role: true, isActive: true },
      });
      if (!user || !user.isActive) {
        return res.status(401).json({ error: 'Authentication is required' });
      }
      if (user.role !== 'DELIVERY_PERSON') {
        return res.status(403).json({ error: 'Delivery staff access required' });
      }

      (req as AuthenticatedRequest).userRole = user.role;
      res.locals.authenticatedUserRole = user.role;
      return next();
    } catch (error) {
      return next(error);
    }
  };

  return {
    authenticateToken,
    requireAdmin,
    requireDeliveryPerson,
    requireBillingStaff,
  };
}

export function sendAdminError(error: unknown, res: Response): void {
  console.error('Admin API request failed:', error);
  res.status(500).json({ error: 'Unable to complete the admin request' });
}
