import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads Excel's inline/shared strings and numeric cells. Formula prices are
/// rejected: a cached formula result is not a confirmed editable price.
List<Map<String, Object>> readCataloguePrices(Uint8List bytes) {
  if (bytes.length > 10 * 1024 * 1024) {
    throw const FormatException(
        'The price workbook must be smaller than 10 MB.');
  }
  final zip = ZipDecoder().decodeBytes(bytes);
  if (zip.files.length > 500 ||
      zip.files.fold<int>(0, (n, f) => n + f.size) > 50 * 1024 * 1024) {
    throw const FormatException('The price workbook is too large.');
  }
  XmlDocument document(ArchiveFile file) =>
      XmlDocument.parse(utf8.decode(file.content));
  final sharedFile = zip.findFile('xl/sharedStrings.xml');
  final shared = sharedFile == null
      ? <String>[]
      : [
          for (final si in document(sharedFile).findAllElements('si'))
            si.findAllElements('t').map((t) => t.innerText).join()
        ];
  String value(XmlElement cell) {
    if (cell.getAttribute('t') == 'inlineStr') {
      return cell.findAllElements('t').map((e) => e.innerText).join();
    }
    final raw = cell.getElement('v')?.innerText ?? '';
    if (cell.getAttribute('t') == 's') {
      final index = int.tryParse(raw);
      if (index == null || index < 0 || index >= shared.length) {
        throw const FormatException('Invalid Excel text cell.');
      }
      return shared[index];
    }
    return raw;
  }

  final prices = <Map<String, Object>>[];
  final seen = <String>{};
  var foundSheets = 0;
  for (final file in zip.files
      .where((f) => RegExp(r'^xl/worksheets/[^/]+\.xml$').hasMatch(f.name))) {
    final rows = document(file).findAllElements('row').toList();
    if (rows.isEmpty) continue;
    Map<String, XmlElement> cells(XmlElement row) => {
          for (final cell in row.findElements('c'))
            (cell.getAttribute('r') ?? '').replaceAll(RegExp(r'\d'), ''): cell,
        };
    final header = cells(rows.first);
    String? idColumn, priceColumn;
    for (final entry in header.entries) {
      if (value(entry.value) == 'Product ID') idColumn = entry.key;
      if (value(entry.value) == 'Price NPR') priceColumn = entry.key;
    }
    if (idColumn == null || priceColumn == null) continue;
    foundSheets++;
    if (rows.length > 100001) {
      throw const FormatException('Too many price rows.');
    }
    for (final row in rows.skip(1)) {
      final fields = cells(row);
      final idCell = fields[idColumn];
      final priceCell = fields[priceColumn];
      final id = idCell == null ? '' : value(idCell).trim();
      if (id.isEmpty && fields.values.every((c) => value(c).trim().isEmpty)) {
        continue;
      }
      if (id.isEmpty ||
          priceCell == null ||
          idCell!.getElement('f') != null ||
          priceCell.getElement('f') != null) {
        throw const FormatException(
            'Keep Product ID and enter a numeric price, without formulas.');
      }
      final price = double.tryParse(value(priceCell).trim());
      if (price == null ||
          !price.isFinite ||
          price < 0 ||
          price > 999999999 ||
          (price * 100 - (price * 100).round()).abs() > .0001) {
        throw FormatException(
            'Invalid price for $id. Use NPR with at most two decimal places.');
      }
      if (!seen.add(id)) {
        throw FormatException('Duplicate Product ID: $id. No prices imported.');
      }
      prices.add({'id': id, 'price': price});
    }
  }
  if (foundSheets != 3) {
    throw const FormatException(
        'Keep the three price sheets and their Product ID / Price NPR headers.');
  }
  return prices;
}
