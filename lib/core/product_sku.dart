String generateStoreSku({
  required String categorySlug,
  required String productName,
  int? uniqueValue,
}) {
  String code(String value, {required int maxLength}) {
    final normalized = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty
        ? 'ITEM'
        : normalized.substring(0, normalized.length.clamp(1, maxLength));
  }

  final suffix =
      (uniqueValue ?? DateTime.now().microsecondsSinceEpoch).toRadixString(36).toUpperCase();
  final categoryCode = categorySlug.split('-').first;
  return 'RPG-${code(categoryCode, maxLength: 8)}-'
      '${code(productName, maxLength: 24)}-$suffix';
}
