import { PrismaLibSQL } from '@prisma/adapter-libsql';
import { PrismaClient } from '@prisma/client';

function required(name: 'TURSO_DATABASE_URL' | 'TURSO_AUTH_TOKEN'): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

export function createTursoPrismaClient(): PrismaClient {
  const url = required('TURSO_DATABASE_URL');
  if (!url.startsWith('libsql://') && !url.startsWith('https://')) {
    throw new Error('TURSO_DATABASE_URL must use a secure libsql:// or https:// URL.');
  }
  const adapter = new PrismaLibSQL({ url, authToken: required('TURSO_AUTH_TOKEN') });
  return new PrismaClient({ adapter });
}
