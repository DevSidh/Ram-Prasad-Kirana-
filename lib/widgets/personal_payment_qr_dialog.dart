import 'package:flutter/material.dart';

Future<void> showPersonalPaymentQrDialog(
  BuildContext context, {
  required double amount,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Pay by bank QR'),
      content: _PersonalQrContent(amount: amount),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<bool?> confirmPersonalPaymentQrDialog(
  BuildContext context, {
  required double amount,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Verify bank payment'),
      content: _PersonalQrContent(amount: amount),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Payment received'),
        ),
      ],
    ),
  );
}

class _PersonalQrContent extends StatelessWidget {
  const _PersonalQrContent({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/personal_bank_qr.jpeg',
                width: 260,
                height: 260,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 260,
                  height: 260,
                  child: Center(child: Text('Could not load the bank QR.')),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Amount to pay',
                style: Theme.of(context).textTheme.titleSmall),
            Text(
              'Rs. ${amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is a static personal QR. Enter the amount shown above in your banking app. For a bill, confirm the transfer in your bank account before marking it as paid.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
