export type ProductSaleDetails = {
  name: string;
  categoryName: string;
  unitLabel: string;
};

export function isWeightUnitLabel(unitLabel: string): boolean {
  return /^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$/i.test(unitLabel);
}

export function inventoryQuantityForUnit(
  quantity: number,
  unitLabel: string,
): number {
  return isWeightUnitLabel(unitLabel)
    ? Math.round(quantity * 1000)
    : Math.round(quantity);
}

export function displayInventoryQuantity(
  quantity: number,
  unitLabel: string,
): number {
  return isWeightUnitLabel(unitLabel) ? quantity / 1000 : quantity;
}

export function validateProductUnit({
  name,
  categoryName,
  unitLabel,
}: ProductSaleDetails): string | null {
  const match = /^(\d+(?:\.\d+)?)\s*(kg|g|l|ml|pc|pcs|pack)$/i.exec(
    unitLabel.trim(),
  );
  if (!match || Number(match[1]) <= 0) {
    return 'Enter a positive quantity and a supported unit.';
  }

  const isBiscuitOrCookie =
    /\b(biscuits?|cookies?)\b/i.test(`${name} ${categoryName}`);
  if (isBiscuitOrCookie && /^(kg|g|l|ml)$/i.test(match[2])) {
    return 'Biscuits and cookies must use packs or pieces, not weight or volume.';
  }
  return null;
}

export function validateProductSalePrice(
  price: number,
  originalPrice: number | null | undefined,
): string | null {
  if (originalPrice != null && originalPrice <= price) {
    return 'Original price must be higher than the sale price.';
  }
  return null;
}
