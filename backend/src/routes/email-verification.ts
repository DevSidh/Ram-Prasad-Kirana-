import bcrypt from 'bcryptjs';
import { randomInt } from 'node:crypto';
import type { PrismaClient } from '@prisma/client';
import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import {
  createStoreEmailSender,
  getEmailDeliveryFailureDetails,
  getSafeErrorMetadata,
  StoreEmailDeliveryError,
  type SendStoreEmail,
} from '../services/email-sender.js';
import { formatUserDisplayId } from '../services/user-display-id.js';

const emailSchema = z.string().trim().email().max(254)
  .transform((email) => email.toLowerCase());
const requestSchema = z.object({ email: emailSchema }).strict();
const confirmSchema = z.object({
  email: emailSchema,
  code: z.string().regex(/^\d{6}$/),
}).strict();

const otpLifetimeMs = 10 * 60 * 1000;
const maxOtpAttempts = 5;

class InvalidVerificationCodeError extends Error {}

export interface PendingRegistrationInput {
  email: string;
  name: string;
  phone: string;
  passwordHash: string;
}

export function normalizeRegistrationPhone(phone: string): string | null {
  const normalizedPhone = phone.trim().replace(/[\s()-]/g, '');
  const match = /^(?:\+977)?(9[78]\d{8})$/.exec(normalizedPhone);
  return match?.[1] ?? null;
}

export class RegistrationEmailUnavailableError extends Error {}

export async function cleanupExpiredRegistrations(
  prisma: PrismaClient,
  now = new Date(),
): Promise<void> {
  await Promise.all([
    prisma.pendingRegistration.deleteMany({
      where: { expiresAt: { lte: now } },
    }),
    prisma.emailVerificationOtp.deleteMany({
      where: { expiresAt: { lte: now } },
    }),
  ]);
}

export async function beginPendingRegistration(
  prisma: PrismaClient,
  registration: PendingRegistrationInput,
  sendEmail: SendStoreEmail | null,
): Promise<void> {
  if (!sendEmail) throw new RegistrationEmailUnavailableError();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + otpLifetimeMs);
  await cleanupExpiredRegistrations(prisma, now);

  const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
  const otpHash = await bcrypt.hash(code, 10);
  await prisma.$transaction(async (transaction) => {
    await transaction.pendingRegistration.create({
      data: { ...registration, expiresAt },
    });
    await transaction.emailVerificationOtp.upsert({
      where: { email: registration.email },
      create: {
        email: registration.email,
        otpHash,
        expiresAt,
      },
      update: { otpHash, expiresAt, attempts: 0 },
    });
  });

  try {
    await sendEmail({
      to: registration.email,
      subject: 'Verify your Ram Prasad General Store email',
      text: `Your email verification code is ${code}. It expires in 10 minutes. If you did not create this account, you can ignore this email.`,
    });
  } catch (error) {
    await Promise.all([
      prisma.pendingRegistration.deleteMany({
        where: {
          email: registration.email,
          passwordHash: registration.passwordHash,
          expiresAt,
        },
      }),
      prisma.emailVerificationOtp.deleteMany({
        where: { email: registration.email, otpHash },
      }),
    ]);
    throw error;
  }
}

export function createEmailVerificationRouter(
  prisma: PrismaClient,
  authSecret: string,
  jwtExpiresInSeconds: number,
  sendEmail: SendStoreEmail | null = createStoreEmailSender(),
): Router {
  const router = Router();
  const requestLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 3,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many verification emails. Try again later.' },
  });
  const confirmLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many verification attempts. Try again later.' },
  });

  router.post('/request', requestLimiter, async (req, res) => {
    const parsed = requestSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid email address.' });
    }
    if (!sendEmail) {
      return res.status(503).json({
        error: 'Email delivery is not configured on the store server.',
      });
    }

    const email = parsed.data.email;
    try {
      await cleanupExpiredRegistrations(prisma);
      const [user, pendingRegistration] = await Promise.all([
        prisma.user.findUnique({
          where: { email },
          select: { isActive: true, emailVerified: true },
        }),
        prisma.pendingRegistration.findUnique({ where: { email } }),
      ]);
      const pendingIsValid = pendingRegistration &&
        pendingRegistration.expiresAt.getTime() > Date.now();
      const shouldSendCode = user
        ? user.isActive && !user.emailVerified
        : Boolean(pendingIsValid);
      if (shouldSendCode) {
        const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
        const otpHash = await bcrypt.hash(code, 10);
        const expiresAt = new Date(Date.now() + otpLifetimeMs);
        await prisma.$transaction(async (transaction) => {
          if (pendingIsValid) {
            await transaction.pendingRegistration.updateMany({
              where: { email, expiresAt: { gt: new Date() } },
              data: { expiresAt },
            });
          }
          await transaction.emailVerificationOtp.upsert({
            where: { email },
            create: { email, otpHash, expiresAt },
            update: { otpHash, expiresAt, attempts: 0 },
          });
        });
        try {
          await sendEmail({
            to: email,
            subject: 'Verify your Ram Prasad General Store email',
            text: `Your email verification code is ${code}. It expires in 10 minutes. If you did not create this account, you can ignore this email.`,
          });
        } catch (error) {
          await prisma.emailVerificationOtp.deleteMany({
            where: { email, otpHash },
          });
          if (error instanceof StoreEmailDeliveryError) {
            const failure = getEmailDeliveryFailureDetails(error);
            console.error(
              'Email verification provider failure:',
              failure.diagnostic,
            );
            return res.status(failure.statusCode).json({
              error: failure.message,
            });
          }
          throw error;
        }
      }

      return res.json({
        message: 'If this account needs email verification, a code has been sent.',
      });
    } catch (error) {
      console.error(
        'Email verification request failed:',
        getSafeErrorMetadata(error),
      );
      return res.status(500).json({
        error: 'Unable to process email verification right now. Check the server logs.',
      });
    }
  });

  router.post('/confirm', confirmLimiter, async (req, res) => {
    const parsed = confirmSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Enter a valid email address and six-digit verification code.',
      });
    }

    const { email, code } = parsed.data;
    try {
      await cleanupExpiredRegistrations(prisma);
      const verification = await prisma.emailVerificationOtp.findUnique({
        where: { email },
      });
      if (!verification || verification.expiresAt.getTime() <= Date.now() ||
          verification.attempts >= maxOtpAttempts) {
        if (verification) {
          await prisma.emailVerificationOtp.deleteMany({ where: { email } });
        }
        return res.status(400).json({
          error: 'The verification code is invalid or expired.',
        });
      }

      if (!(await bcrypt.compare(code, verification.otpHash))) {
        await prisma.emailVerificationOtp.updateMany({
          where: {
            email,
            otpHash: verification.otpHash,
            attempts: { lt: maxOtpAttempts },
          },
          data: { attempts: { increment: 1 } },
        });
        return res.status(400).json({
          error: 'The verification code is invalid or expired.',
        });
      }

      const user = await prisma.$transaction(async (transaction) => {
        const consumed = await transaction.emailVerificationOtp.deleteMany({
          where: {
            email,
            otpHash: verification.otpHash,
            expiresAt: { gt: new Date() },
            attempts: { lt: maxOtpAttempts },
          },
        });
        if (consumed.count !== 1) {
          throw new InvalidVerificationCodeError();
        }

        const pendingRegistration =
          await transaction.pendingRegistration.findUnique({
            where: { email },
          });
        if (pendingRegistration) {
          if (pendingRegistration.expiresAt.getTime() <= Date.now()) {
            throw new InvalidVerificationCodeError();
          }
          const registrationConsumed =
            await transaction.pendingRegistration.deleteMany({
              where: {
                email,
                passwordHash: pendingRegistration.passwordHash,
                expiresAt: { gt: new Date() },
              },
            });
          if (registrationConsumed.count !== 1) {
            throw new InvalidVerificationCodeError();
          }
          return transaction.user.create({
            data: {
              email,
              name: pendingRegistration.name,
              phone: pendingRegistration.phone,
              passwordHash: pendingRegistration.passwordHash,
              emailVerified: true,
            },
            select: {
              id: true,
              userNumber: true,
              email: true,
              name: true,
              phone: true,
              role: true,
              avatarUrl: true,
              tokenVersion: true,
            },
          });
        }

        const updated = await transaction.user.updateMany({
          where: { email, isActive: true, emailVerified: false },
          data: { emailVerified: true },
        });
        if (updated.count !== 1) {
          throw new InvalidVerificationCodeError();
        }

        return transaction.user.findUnique({
          where: { email },
          select: {
            id: true,
            userNumber: true,
            email: true,
            name: true,
            phone: true,
            role: true,
            avatarUrl: true,
            tokenVersion: true,
          },
        });
      });
      if (!user) {
        throw new InvalidVerificationCodeError();
      }

      const token = jwt.sign(
        {
          id: user.id,
          email: user.email,
          fullName: user.name,
          role: user.role,
          tokenVersion: user.tokenVersion,
        },
        authSecret,
        { expiresIn: jwtExpiresInSeconds },
      );

      return res.json({
        message: 'Email verified successfully.',
        token,
        user: {
          id: user.id,
          profileId: formatUserDisplayId(user.userNumber),
          email: user.email,
          fullName: user.name,
          phone: user.phone,
          role: user.role,
          avatarUrl: user.avatarUrl,
        },
      });
    } catch (error) {
      if (
        error && typeof error === 'object' && 'code' in error &&
        error.code === 'P2002'
      ) {
        return res.status(409).json({
          error: 'An account with this email or phone already exists.',
        });
      }
      if (error instanceof InvalidVerificationCodeError) {
        return res.status(400).json({
          error: 'The verification code is invalid or expired.',
        });
      }
      console.error('Email verification failed:', error);
      return res.status(500).json({
        error: 'Unable to verify this email right now.',
      });
    }
  });

  return router;
}
