import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';

dotenv.config();

const prisma = new PrismaClient();

async function createAdmin(): Promise<void> {
  const name = process.env.ADMIN_NAME?.trim();
  const username = process.env.ADMIN_USERNAME?.trim().toLowerCase();
  const email = z.string().trim().email().max(254).safeParse(process.env.ADMIN_EMAIL);
  const password = process.env.ADMIN_PASSWORD;

  if (
    !name ||
    name.length > 120 ||
    !username ||
    !/^[a-z0-9][a-z0-9._-]{2,31}$/.test(username) ||
    !email.success
  ) {
    throw new Error(
      'Set valid ADMIN_NAME, ADMIN_USERNAME, and ADMIN_EMAIL environment variables.',
    );
  }
  if (!password || password.length < 8) {
    throw new Error('Set ADMIN_PASSWORD to a password with at least 8 characters.');
  }

  const user = await prisma.user.create({
    data: {
      name,
      email: email.data.toLowerCase(),
      passwordHash: await bcrypt.hash(password, 12),
      role: 'ADMIN',
    },
    select: { id: true, name: true, email: true, role: true },
  });

  console.log(`Created ${user.role} account for username "${username}".`);
}

createAdmin()
  .catch((error: unknown) => {
    console.error('Unable to create the admin account:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
