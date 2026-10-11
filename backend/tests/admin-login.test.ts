import assert from 'node:assert/strict';
import { findAdminByPassword } from '../src/services/admin-login.js';

async function run(): Promise<void> {
  const admins = [
    { id: 'admin-one', passwordHash: 'hash-one' },
    { id: 'admin-two', passwordHash: 'hash-two' },
  ];
  const compare = async (candidate: string, hash: string) =>
    candidate === `password-for-${hash}`;

  assert.equal(
    (await findAdminByPassword(admins, 'password-for-hash-two', compare))?.id,
    'admin-two',
    'the matching admin account is selected by its password',
  );
  assert.equal(
    await findAdminByPassword(admins, 'wrong-password', compare),
    null,
    'a password that matches no active admin is rejected',
  );
  assert.equal(
    await findAdminByPassword(
      admins,
      'password-for-hash-one',
      async () => true,
    ),
    null,
    'ambiguous passwords do not choose an arbitrary admin account',
  );
  console.log('Admin login account resolution tests passed.');
}

void run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
