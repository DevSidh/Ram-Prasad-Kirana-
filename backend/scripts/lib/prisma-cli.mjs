import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const backendDir = fileURLToPath(new URL('../../', import.meta.url));
const prismaCli = fileURLToPath(new URL('../../node_modules/prisma/build/index.js', import.meta.url));
export function runPrisma(args) {
  const result = spawnSync(process.execPath, [prismaCli, ...args], { cwd: backendDir, stdio: 'inherit' });
  if (result.error) throw result.error;
  return result.status ?? 1;
}
export function resolveApplied(name) {
  const status = runPrisma(['migrate', 'resolve', '--applied', name]);
  if (status !== 0) throw new Error(`Prisma migrate resolve exited with status ${status}.`);
}
