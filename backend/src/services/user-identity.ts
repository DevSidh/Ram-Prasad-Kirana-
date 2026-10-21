import type { PrismaClient } from '@prisma/client';

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function normalizePhone(phone: string | null | undefined): string | null {
  if (typeof phone !== 'string' || phone.trim().length === 0) return null;
  const digits = phone.replace(/\D/g, '');
  return digits.length > 0 ? digits : null;
}

export function normalizeSignupPhone(phone: string): string | null {
  const digits = normalizePhone(phone);
  return digits?.length === 10 ? digits : null;
}

export async function identityAlreadyInUse(
  prisma: PrismaClient,
  input: { email?: string; phone: string | null; excludeUserId?: string },
): Promise<boolean> {
  const [match] = await prisma.$queryRaw<Array<{ id: string }>>`
    SELECT "id"
    FROM "User"
    WHERE (
      (
        ${input.email ?? ''} <> ''
        AND lower("email") = ${normalizeEmail(input.email ?? '')}
      )
      OR (
        ${input.phone ?? ''} <> ''
        AND regexp_replace(COALESCE("phone", ''), '[^0-9]', '', 'g') = ${input.phone ?? ''}
      )
    )
    AND (${input.excludeUserId ?? ''} = '' OR "id" <> ${input.excludeUserId ?? ''})
    LIMIT 1
  `;
  return match !== undefined;
}
