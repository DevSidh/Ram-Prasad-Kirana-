class ScannedProductBarcode {
  final String value;
  final DateTime? manufacturedAt;
  final DateTime? expiresAt;

  const ScannedProductBarcode({
    required this.value,
    this.manufacturedAt,
    this.expiresAt,
  });

  static ScannedProductBarcode? parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty || raw.length > 256) return null;

    final normalized = raw.replaceAll('\u001d', '<GS>');
    final identifierMatch = RegExp(r'^\][A-Za-z0-9]{2}').firstMatch(normalized);
    final data = identifierMatch == null
        ? normalized
        : normalized.substring(identifierMatch.end);
    final applicationIdentifiers = RegExp(r'\((\d{2,4})\)([^()]*)')
        .allMatches(data)
        .toList(growable: false);

    String? gtin;
    DateTime? manufacturedAt;
    DateTime? expiresAt;
    for (var index = 0; index < applicationIdentifiers.length; index++) {
      final match = applicationIdentifiers[index];
      final identifier = match.group(1)!;
      final value = match.group(2)!.split('<GS>').first.trim();
      switch (identifier) {
        case '01':
          if (RegExp(r'^\d{14}$').hasMatch(value)) gtin ??= value;
        case '11':
          manufacturedAt ??= _parseGs1Date(value);
        case '17':
          expiresAt ??= _parseGs1Date(value);
      }
    }

    if (gtin == null && applicationIdentifiers.isEmpty) {
      final rawGtin = RegExp(r'(?:^|[^0-9])01(\d{14})').firstMatch(data);
      if (rawGtin != null) {
        gtin = rawGtin.group(1);
        final remaining = data.substring(rawGtin.end);
        final fields = remaining.split('<GS>');
        var field = fields.first;
        while (field.length >= 2) {
          final identifier = field.substring(0, 2);
          if (field.length < 8) break;
          final date = _parseGs1Date(field.substring(2, 8));
          if (identifier == '11') manufacturedAt ??= date;
          if (identifier == '17') expiresAt ??= date;
          field = field.substring(8);
        }
        for (final separatedField in fields.skip(1)) {
          if (separatedField.startsWith('11') && separatedField.length >= 8) {
            manufacturedAt ??= _parseGs1Date(
              separatedField.substring(2, 8),
            );
          } else if (separatedField.startsWith('17') &&
              separatedField.length >= 8) {
            expiresAt ??= _parseGs1Date(separatedField.substring(2, 8));
          }
        }
      }
    }

    final value = gtin ?? raw;
    if (!RegExp(r'^[A-Za-z0-9._:/+-]{4,128}$').hasMatch(value)) {
      return null;
    }
    return ScannedProductBarcode(
      value: value,
      manufacturedAt: manufacturedAt,
      expiresAt: expiresAt,
    );
  }

  static DateTime? _parseGs1Date(String value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return null;
    final yearPart = int.parse(value.substring(0, 2));
    final year = yearPart <= 49 ? 2000 + yearPart : 1900 + yearPart;
    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4, 6));
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
