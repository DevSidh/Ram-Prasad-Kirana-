import assert from 'node:assert/strict';
import {
  displayInventoryQuantity,
  inventoryQuantityForUnit,
  isWeightUnitLabel,
  validateProductSalePrice,
  validateProductUnit,
} from '../src/services/product-validation.js';
import { isExcludedCustomerCategory } from '../src/services/customer-catalog.js';

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
assert.equal(isWeightUnitLabel('1 kg'), true);
assert.equal(isWeightUnitLabel('500 g'), true);
assert.equal(isWeightUnitLabel('1 pack'), false);
assert.equal(inventoryQuantityForUnit(1.25, '1 kg'), 1250);
assert.equal(inventoryQuantityForUnit(2, '1 pc'), 2);
assert.equal(displayInventoryQuantity(1250, '1 kg'), 1.25);
assert.equal(displayInventoryQuantity(2, '1 pc'), 2);
assert.equal(isExcludedCustomerCategory('Fruits & Vegetables', 'fruit-vegetables'), true);
assert.equal(isExcludedCustomerCategory('Dairy & Eggs', 'dairy-eggs'), true);
assert.equal(isExcludedCustomerCategory('Rice & Grains', 'rice-grains'), true);
assert.equal(isExcludedCustomerCategory('Fresh Fruit', 'fresh-fruit'), false);
console.log('Product validation and customer catalog exclusion tests passed.');
