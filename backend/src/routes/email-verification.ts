import bcrypt from 'bcryptjs';
import { randomInt } from 'node:crypto';
import type { PrismaClient } from '@prisma/client';
import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import {
  createSmtpEmailSender,
  type SendStoreEmail,
} from '../services/email-sender.js';

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

export function createEmailVerificationRouter(
  prisma: PrismaClient,
  authSecret: string,
  jwtExpiresInSeconds: number,
  sendEmail: SendStoreEmail | null = createSmtpEmailSender(),
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
      const user = await prisma.user.findUnique({
        where: { email },
        select: { isActive: true, emailVerified: true },
      });
      if (user?.isActive && !user.emailVerified) {
        const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
        const otpHash = await bcrypt.hash(code, 10);
        const expiresAt = new Date(Date.now() + otpLifetimeMs);
        await prisma.emailVerificationOtp.upsert({
          where: { email },
          create: { email, otpHash, expiresAt },
          update: { otpHash, expiresAt, attempts: 0 },
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
          throw error;
        }
      }

      return res.json({
        message: 'If this account needs email verification, a code has been sent.',
      });
    } catch (error) {
      console.error('Email verification code delivery failed:', error);
      return res.status(500).json({
        error: 'Unable to send a verification code right now.',
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
          email: user.email,
          fullName: user.name,
          phone: user.phone,
          role: user.role,
          avatarUrl: user.avatarUrl,
        },
      });
    } catch (error) {
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
