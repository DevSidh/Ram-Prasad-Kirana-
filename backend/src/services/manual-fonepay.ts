export const manualFonepayNotePrefix = 'FASTSTORE_MANUAL_FONEPAY_V1:';

export function manualFonepayNote(reference: string, cashierId: string, amount: number, verifiedAt: Date, provider = 'FONEPAY'): string {
  return manualFonepayNotePrefix + JSON.stringify({
    verificationMethod: 'MANUAL', transactionReference: reference,
    provider,
    referenceType: reference.startsWith('CASHIER-') ? 'CASHIER_CONFIRMATION' : 'MERCHANT_TRANSACTION',
    verifiedById: cashierId, verifiedAt: verifiedAt.toISOString(), amount, currency: 'NPR',
  });
}

export function manualPaymentProvider(note: string | null): 'ESEWA' | 'FONEPAY' | null {
  if (!note?.startsWith(manualFonepayNotePrefix)) return null;
  try {
    const data = JSON.parse(note.slice(manualFonepayNotePrefix.length));
    if (data.verificationMethod !== 'MANUAL') return null;
    return data.provider === 'ESEWA' ? 'ESEWA' : 'FONEPAY';
  } catch { return null; }
}

export function manualFonepayReference(note: string | null): string | null {
  if (!note?.startsWith(manualFonepayNotePrefix)) return null;
  try {
    const data = JSON.parse(note.slice(manualFonepayNotePrefix.length));
    return data.verificationMethod === 'MANUAL' && typeof data.transactionReference === 'string'
      ? data.transactionReference : null;
  } catch { return null; }
}
