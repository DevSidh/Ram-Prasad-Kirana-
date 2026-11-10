import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Offline XLSX creation. All strings are literal cells, never Excel formulas.
/// Called in an isolate by the export service, away from checkout/printing.
Uint8List buildBillingWorkbook(Map<String, List<List<Object?>>> sheets) {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  String xml(Object? value) => (value?.toString() ?? '')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  String column(int index) {
    var number = index + 1;
    var name = '';
    while (number > 0) {
      number--;
      name = String.fromCharCode(65 + number % 26) + name;
      number ~/= 26;
    }
    return name;
  }

  const declaration = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  const mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const relNs = 'http://schemas.openxmlformats.org/package/2006/relationships';
  const docRel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  add(
      '[Content_Types].xml',
      '$declaration<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
          '${List.generate(sheets.length, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}'
          '</Types>');
  add('_rels/.rels',
      '$declaration<Relationships xmlns="$relNs"><Relationship Id="rId1" Type="$docRel/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  add(
      'xl/workbook.xml',
      '$declaration<workbook xmlns="$mainNs" xmlns:r="$docRel"><sheets>'
          '${sheets.keys.toList().asMap().entries.map((e) => '<sheet name="${xml(e.value)}" sheetId="${e.key + 1}" r:id="rId${e.key + 1}"/>').join()}'
          '</sheets></workbook>');
  add(
      'xl/_rels/workbook.xml.rels',
      '$declaration<Relationships xmlns="$relNs">'
          '${List.generate(sheets.length, (i) => '<Relationship Id="rId${i + 1}" Type="$docRel/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join()}'
          '<Relationship Id="styles" Type="$docRel/styles" Target="styles.xml"/></Relationships>');
  add('xl/styles.xml', '''$declaration<styleSheet xmlns="$mainNs">
<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF203F60"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment vertical="center" wrapText="1"/></xf><xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyProtection="1"><protection locked="0"/></xf></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''');
  var sheetIndex = 0;
  for (final rows in sheets.values) {
    sheetIndex++;
    final count = rows.isEmpty ? 1 : rows.first.length;
    final priceSheet = rows.isNotEmpty &&
        rows.first.contains('Product ID') &&
        rows.first.contains('Price NPR');
    final priceColumn = rows.isEmpty ? -1 : rows.first.indexOf('Price NPR');
    final body = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      final lines = rows[r].fold<int>(1, (maxLines, value) {
        final length = value?.toString().length ?? 0;
        final needed = (length / 24).ceil().clamp(1, 8);
        return needed > maxLines ? needed : maxLines;
      });
      body.write(
          '<row r="${r + 1}" ht="${r == 0 ? 30 : lines * 16 + 6}" customHeight="1">');
      for (var c = 0; c < rows[r].length; c++) {
        final value = rows[r][c];
        final ref = '${column(c)}${r + 1}';
        if (r > 0 && value is num && value.isFinite) {
          body.write(
              '<c r="$ref" s="${priceSheet && c == priceColumn ? 3 : 2}"><v>$value</v></c>');
        } else {
          body.write(
              '<c r="$ref" s="${r == 0 ? 1 : 0}" t="inlineStr"><is><t xml:space="preserve">${xml(value)}</t></is></c>');
        }
      }
      body.write('</row>');
    }
    final end = '${column(count - 1)}${rows.isEmpty ? 1 : rows.length}';
    add(
        'xl/worksheets/sheet$sheetIndex.xml',
        '$declaration<worksheet xmlns="$mainNs">'
            '<dimension ref="A1:$end"/><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
            '<sheetFormatPr defaultRowHeight="22"/><cols><col min="1" max="$count" width="24" customWidth="1"/></cols>'
            '<sheetData>$body</sheetData>${priceSheet ? '<sheetProtection sheet="1" objects="1" scenarios="1" autoFilter="0"/>' : ''}<autoFilter ref="A1:$end"/>'
            '<pageMargins left="0.25" right="0.25" top="0.5" bottom="0.5" header="0.2" footer="0.2"/>'
            '<pageSetup orientation="landscape" paperSize="9" fitToWidth="1" fitToHeight="0"/></worksheet>');
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
