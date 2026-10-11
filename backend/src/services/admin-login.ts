export async function findAdminByPassword<T extends { passwordHash: string }>(
  admins: readonly T[],
  password: string,
  comparePassword: (candidate: string, hash: string) => Promise<boolean>,
): Promise<T | null> {
  const matches: T[] = [];
  for (const admin of admins) {
    if (await comparePassword(password, admin.passwordHash)) {
      matches.push(admin);
    }
  }
  return matches.length === 1 ? matches[0] : null;
}
