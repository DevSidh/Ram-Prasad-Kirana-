/** Produces an owned ArrayBuffer-backed byte array accepted by Prisma's LibSQL adapter. */
export function prismaBytes(value: Uint8Array): Uint8Array<ArrayBuffer> {
  return Uint8Array.from(value);
}
