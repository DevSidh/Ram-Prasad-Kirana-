import bcrypt from 'bcryptjs';
import { randomInt } from 'node:crypto';
import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import type { PrismaClient } from '@prisma/client';
import { createSmtpEmailSender } from '../services/email-sender.js';

const emailSchema = z.string().trim().email().max(254).transform((email) => email.toLowerCase());
const requestSchema = z.object({ email: emailSchema }).strict();
const confirmSchema = z.object({
  email: emailSchema,
  code: z.string().regex(/^\d{6}$/),
  password: z.string().min(8).max(128),
}).strict();

const otpLifetimeMs = 10 * 60 * 1000;
const maxOtpAttempts = 5;

class InvalidResetCodeError extends Error {}

type SendResetCode = (email: string, code: string) => Promise<void>;

function createSmtpSender(): SendResetCode | null {
  const sendEmail = createSmtpEmailSender();
  if (!sendEmail) return null;
  return async (email, code) => {
    await sendEmail({
      to: email,
      subject: 'Your Ram Prasad General Store password reset code',
      text: `Your password reset code is ${code}. It expires in 10 minutes. If you did not request this, you can ignore this email.`,
    });
  };
}

export function createPasswordResetRouter(
  prisma: PrismaClient,
  sendResetCode: SendResetCode | null = createSmtpSender(),
): Router {
  const router = Router();
  const requestLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 3,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many reset requests. Try again later.' },
  });
  const confirmLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many verification attempts. Try again later.' },
  });

  router.post('/request', requestLimiter, async (req, res) => {
    if (!sendResetCode) {
      return res.status(503).json({
        error: 'Password reset email delivery is not configured on the server.',
      });
    }
    const parsed = requestSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid email address.' });
    }

    const email = parsed.data.email;
    try {
      const user = await prisma.user.findUnique({
        where: { email },
        select: { isActive: true },
      });
      if (user?.isActive) {
        const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
        const otpHash = await bcrypt.hash(code, 10);
        const expiresAt = new Date(Date.now() + otpLifetimeMs);
        await prisma.passwordResetOtp.upsert({
          where: { email },
          create: { email, otpHash, expiresAt },
          update: { otpHash, expiresAt, attempts: 0 },
        });
        try {
          await sendResetCode(email, code);
        } catch (error) {
          await prisma.passwordResetOtp.deleteMany({ where: { email, otpHash } });
          throw error;
        }
      }

      return res.json({
        message: 'If an active account matches that email, a reset code has been sent.',
      });
    } catch (error) {
      console.error('Password reset code delivery failed:', error);
      return res.status(500).json({ error: 'Unable to send a reset code right now.' });
    }
  });

  router.post('/confirm', confirmLimiter, async (req, res) => {
    const parsed = confirmSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Enter a valid email, six-digit code, and password of at least 8 characters.',
      });
    }

    const { email, code, password } = parsed.data;
    try {
      const reset = await prisma.passwordResetOtp.findUnique({ where: { email } });
      if (!reset || reset.expiresAt.getTime() <= Date.now() ||
          reset.attempts >= maxOtpAttempts) {
        if (reset) await prisma.passwordResetOtp.deleteMany({ where: { email } });
        return res.status(400).json({ error: 'The reset code is invalid or expired.' });
      }

      if (!(await bcrypt.compare(code, reset.otpHash))) {
        await prisma.passwordResetOtp.updateMany({
          where: { email, otpHash: reset.otpHash, attempts: { lt: maxOtpAttempts } },
          data: { attempts: { increment: 1 } },
        });
        return res.status(400).json({ error: 'The reset code is invalid or expired.' });
      }

      const passwordHash = await bcrypt.hash(password, 12);
      await prisma.$transaction(async (transaction) => {
        const consumed = await transaction.passwordResetOtp.deleteMany({
          where: {
            email,
            otpHash: reset.otpHash,
            expiresAt: { gt: new Date() },
            attempts: { lt: maxOtpAttempts },
          },
        });
        if (consumed.count !== 1) {
          throw new InvalidResetCodeError();
        }
        const updated = await transaction.user.updateMany({
          where: { email, isActive: true },
          data: { passwordHash, tokenVersion: { increment: 1 } },
        });
        if (updated.count !== 1) {
          throw new InvalidResetCodeError();
        }
      });

      return res.json({ message: 'Your password has been changed. You can now sign in.' });
    } catch (error) {
      if (error instanceof InvalidResetCodeError) {
        return res.status(400).json({ error: 'The reset code is invalid or expired.' });
      }
      console.error('Password reset confirmation failed:', error);
      return res.status(500).json({ error: 'Unable to change the password right now.' });
    }
  });

  return router;
}
