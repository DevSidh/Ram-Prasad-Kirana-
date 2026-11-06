import { PrismaClient } from '@prisma/client';
import { recoverRoomMigration } from './lib/room-migration-recovery.mjs';
import { resolveApplied } from './lib/prisma-cli.mjs';

const prisma = new PrismaClient();
try { await recoverRoomMigration(prisma, resolveApplied); }
finally { await prisma.$disconnect(); }
