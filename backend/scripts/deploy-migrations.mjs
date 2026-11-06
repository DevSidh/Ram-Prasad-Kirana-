import { PrismaClient } from '@prisma/client';
import { recoverRoomMigration } from './lib/room-migration-recovery.mjs';
import { runPrisma, resolveApplied } from './lib/prisma-cli.mjs';

// Preserve committed migration checksums. A fresh database can hit the same
// default schema lock, so recover that specific failure and retry deploy once.
const prisma = new PrismaClient();
try {
  await recoverRoomMigration(prisma, resolveApplied);
  let status = runPrisma(['migrate', 'deploy']);
  if (status !== 0 && await recoverRoomMigration(prisma, resolveApplied)) {
    status = runPrisma(['migrate', 'deploy']);
  }
  process.exitCode = status;
} finally { await prisma.$disconnect(); }
