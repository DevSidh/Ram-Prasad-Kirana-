import 'dotenv/config';
import {PrismaClient} from '@prisma/client';
import {PrismaLibSQL} from '@prisma/adapter-libsql';
import {databaseAvailabilityFailure} from '../dist/services/database-availability.js';

// Explicit, read-only operator diagnostic. Does not run migrations or print the
// connection string; run from backend after its normal build.
const url = process.env.TURSO_DATABASE_URL?.trim();
const authToken = process.env.TURSO_AUTH_TOKEN?.trim();
if (!url || !authToken) {
  console.log(JSON.stringify({database: 'disconnected', code: 'TURSO_NOT_CONFIGURED'}));
  process.exit(1);
}
const prisma = new PrismaClient({adapter: new PrismaLibSQL({url, authToken})});
try {
  await prisma.$queryRaw`SELECT 1`;
  console.log(JSON.stringify({database: 'connected'}));
} catch (error) {
  const failure = databaseAvailabilityFailure(error);
  console.log(JSON.stringify({database: 'disconnected', ...(failure ?? {
    code: 'DATABASE_UNAVAILABLE', error: 'Database connection failed. Check the provider console and server logs.',
  })}));
  process.exitCode = 1;
} finally {await prisma.$disconnect();}
