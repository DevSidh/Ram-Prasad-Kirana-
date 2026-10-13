import assert from 'node:assert/strict';
import {
  validateProductSalePrice,
  validateProductUnit,
} from '../src/services/product-validation.js';

assert.equal(
  validateProductUnit({
    name: 'Chocolate Biscuits',
    categoryName: 'Snacks',
    unitLabel: '500 g',
  }),
  'Biscuits and cookies must use packs or pieces, not weight or volume.',
);
assert.equal(
  validateProductUnit({
    name: 'Chocolate Cookies',
    categoryName: 'Snacks',
    unitLabel: '1 pack',
  }),
  null,
);
assert.equal(
  validateProductUnit({
    name: 'Rice',
    categoryName: 'Grains',
    unitLabel: '5 kg',
  }),
  null,
);
assert.ok(
  validateProductUnit({
    name: 'Rice',
    categoryName: 'Grains',
    unitLabel: '0 kg',
  }),
);
assert.equal(validateProductSalePrice(80, 100), null);
assert.ok(validateProductSalePrice(100, 80));
console.log('Product unit and sale-price tests passed.');
