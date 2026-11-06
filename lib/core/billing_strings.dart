import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Captures preserve names, addresses, IDs and other business data verbatim.
class BillingStrings {
  static String languageCode = 'en';
  static final Map<String, String> _catalog = {};
  static final Map<String, String> _caseFolded = {};
  static final Map<String, String> _cache = {};
  static final List<({RegExp expression, String value, String prefix})>
      _templates = [];
  static Future<void>? _loading;
  static bool get isNepali => languageCode == 'ne';
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    await initializeDateFormatting('ne');
    final source = jsonDecode(
            await rootBundle.loadString('assets/translations/billing_ne.json'))
        as Map<String, dynamic>;
    _catalog.addAll(source.map((key, value) => MapEntry(key, value as String)));
    _caseFolded.addAll({
      for (final entry in _catalog.entries) entry.key.toLowerCase(): entry.value
    });
    final templates = _catalog.entries
        .where((entry) => entry.key.contains(RegExp(r'\{\d+\}')))
        .toList()
      ..sort((a, b) => b.key
          .replaceAll(RegExp(r'\{\d+\}'), '')
          .length
          .compareTo(a.key.replaceAll(RegExp(r'\{\d+\}'), '').length));
    for (final entry in templates) {
      if (entry.key.replaceAll(RegExp(r'\{\d+\}'), '').trim().isEmpty) continue;
      var index = 0;
      final pattern = StringBuffer('^');
      for (final match in RegExp(r'\{\d+\}').allMatches(entry.key)) {
        pattern.write(RegExp.escape(entry.key.substring(index, match.start)));
        pattern.write('(.*?)');
        index = match.end;
      }
      pattern.write(RegExp.escape(entry.key.substring(index)));
      pattern.write(r'$');
      _templates.add((
        expression:
            RegExp(pattern.toString(), dotAll: true, caseSensitive: false),
        value: entry.value,
        prefix: entry.key.substring(0, entry.key.indexOf('{')).toLowerCase()
      ));
    }
    _cache.clear();
  }

  static String tr(String text) {
    if (!isNepali || text.isEmpty) return text;
    return _translate(text, 0);
  }

  static String _translate(String text, int depth) {
    if (depth > 4 || text.isEmpty) return text;
    final exact = _catalog[text] ?? _caseFolded[text.toLowerCase()];
    if (exact != null) return exact;
    final cached = _cache[text];
    if (cached != null) return cached;
    final folded = text.toLowerCase();
    for (final template in _templates) {
      if (template.prefix.isNotEmpty && !folded.startsWith(template.prefix)) {
        continue;
      }
      final match = template.expression.firstMatch(text);
      if (match == null) continue;
      final translated =
          template.value.replaceAllMapped(RegExp(r'\{(\d+)\}'), (token) {
        final captured = match.group(int.parse(token[1]!) + 1) ?? '';
        // A name/code with no catalog entry stays byte-for-byte unchanged.
        return _translate(captured, depth + 1);
      });
      if (_cache.length > 3000) _cache.clear();
      return _cache[text] = translated;
    }
    for (final separator in ['\n', ' · ', ' • ', ': ']) {
      if (text.contains(separator)) {
        final translated = text
            .split(separator)
            .map((part) => _translate(part, depth + 1))
            .join(separator);
        if (translated != text) return translated;
      }
    }
    if (_cache.length > 3000) _cache.clear();
    return _cache[text] = text;
  }

  static String? optional(String? value) => value == null ? null : tr(value);
}
