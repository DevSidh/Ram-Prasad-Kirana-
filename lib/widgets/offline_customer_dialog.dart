import 'package:flutter/material.dart';
import '../core/nepal_phone.dart';
import '../services/billing_excel_export_service.dart';

class OfflineCustomerDialog extends StatefulWidget {
  const OfflineCustomerDialog({super.key});

  @override
  State<OfflineCustomerDialog> createState() => _OfflineCustomerDialogState();
}

class _OfflineCustomerDialogState extends State<OfflineCustomerDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _phone, _address, _email]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BillingExcelExportService.saveCustomer(
          name: _name.text,
          phone: _phone.text,
          address: _address.text,
          email: _email.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save customer: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('New offline customer'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 120,
                          decoration:
                              const InputDecoration(labelText: 'Customer name'),
                          validator: (value) => value?.trim().isNotEmpty == true
                              ? null
                              : 'Enter the customer name.'),
                      TextFormField(
                          controller: _phone,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          inputFormatters: nepalPhoneInputFormatters,
                          decoration:
                              const InputDecoration(labelText: 'Phone number'),
                          validator: validateNepalPhone),
                      TextFormField(
                          controller: _address,
                          enabled: !_saving,
                          maxLength: 500,
                          minLines: 2,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'Address'),
                          validator: (value) => value?.trim().isNotEmpty == true
                              ? null
                              : 'Enter the address.'),
                      TextFormField(
                          controller: _email,
                          enabled: !_saving,
                          maxLength: 254,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Email (optional)'),
                          validator: (value) =>
                              (value?.trim().isEmpty ?? true) ||
                                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(value!.trim())
                                  ? null
                                  : 'Enter a valid email address.'),
                      const Text(
                          'Saved on this computer only. An existing phone number updates that customer.'),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save customer'))
        ],
      ));
}
