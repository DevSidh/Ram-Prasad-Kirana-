import 'package:flutter/services.dart';

List<TextInputFormatter> get nepalPhoneInputFormatters => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10),
    ];

String? validateNepalPhone(String? value, {bool optional = false}) {
  final phone = value?.trim() ?? '';
  if (optional && phone.isEmpty) return null;
  return RegExp(r'^9[78]\d{8}$').hasMatch(phone)
      ? null
      : 'Enter 10 digits starting with 97 or 98.';
}
