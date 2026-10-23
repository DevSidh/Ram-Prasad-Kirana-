import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../models/product.dart';

Future<int?> showWeightQuantityDialog(
  BuildContext context,
  Product product, {
  int initialGrams = 1000,
}) async {
  final controller = TextEditingController(
    text: (initialGrams / 1000)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), ''),
  );
  final formKey = GlobalKey<FormState>();
  final availableKg = product.availableWeightGrams / 1000;
  final selectedKg = await showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text('Choose ${product.name} weight'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              autofocus: false,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,3}'),
                ),
              ],
              decoration: InputDecoration(
                labelText: 'Weight in kg',
                helperText: 'Price: ${AppConstants.currencySymbol}'
                    '${product.price.toStringAsFixed(2)} per kg',
                suffixText: 'kg',
              ),
              validator: (value) {
                final kg = double.tryParse(value?.trim() ?? '');
                if (kg == null || !kg.isFinite || kg <= 0) {
                  return 'Enter a weight greater than 0 kg.';
                }
                if (kg > availableKg) {
                  return 'Only ${availableKg.toStringAsFixed(3)} kg is available.';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, double.parse(controller.text));
                }
              },
            ),
            const SizedBox(height: 8),
            Text('Available: ${availableKg.toStringAsFixed(3)} kg'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, double.parse(controller.text));
            }
          },
          child: const Text('Add weight'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (selectedKg == null) return null;
  final grams = (selectedKg * 1000).round();
  return grams > 0 ? grams : null;
}
