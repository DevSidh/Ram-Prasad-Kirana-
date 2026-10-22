export function formatUserDisplayId(userNumber: bigint): string {
  if (userNumber < 1n) {
    throw new RangeError('User number must be a positive database sequence value.');
  }
  return `USR-${userNumber.toString().padStart(6, '0')}`;
}
