import dotenv from 'dotenv';
import { PrismaLibSQL } from '@prisma/adapter-libsql';
import { PrismaClient } from '@prisma/client';

dotenv.config({ path: new URL('../.env', import.meta.url) });
const adapter = new PrismaLibSQL({
  url: process.env.TURSO_DATABASE_URL,
  authToken: process.env.TURSO_AUTH_TOKEN,
});
const prisma = new PrismaClient({ adapter });
try {
  const [users, products] = await Promise.all([prisma.user.count(), prisma.product.count()]);
  console.log(JSON.stringify({ typedClient: 'connected', users, products }));
} finally {
  await prisma.$disconnect();
}
