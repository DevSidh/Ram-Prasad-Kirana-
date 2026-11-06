import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/constants.dart';
import '../core/billing_strings.dart';

typedef ReadableBillLine = ({String item, String quantity, double amount});

/// Flutter/Skia shapes Devanagari conjuncts and vowel marks before embedding
/// high-resolution lossless rows. The PDF library alone cannot shape Indic text.
/// Rows, rather than a single enormous image, allow A4 pagination and bound memory.
class ReadableBillPdf {
  static Future<void>? _font;
  static Future<void> _loadFont() => _font ??= () async {
        final loader = FontLoader('FastStoreDevanagari')
          ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'));
        await loader.load();
      }();

  static bool needsShaping(Iterable<String?> values) =>
      BillingStrings.isNepali ||
      values.any(
          (text) => text != null && RegExp(r'[\u0900-\u097f]').hasMatch(text));

  static Future<Uint8List> create({
    required String number,
    required DateTime date,
    required String? customerName,
    required String? customerPhone,
    required List<ReadableBillLine> items,
    required double subtotal,
    required double discount,
    required double vat,
    required double total,
    required String method,
    required String status,
    double? paid,
    double? due,
    double other = 0,
    int? paperWidthMm,
    pw.Widget? paymentInstructions,
  }) async {
    if (paperWidthMm != null && paperWidthMm != 58 && paperWidthMm != 80) {
      throw ArgumentError.value(paperWidthMm, 'paperWidthMm');
    }
    await _loadFont();
    await BillingStrings.load();
    final nepali = BillingStrings.isNepali;
    String label(String en, String ne) => nepali ? ne : en;
    final thermal = paperWidthMm != null;
    final margin = thermal ? 3 * PdfPageFormat.mm : 32.0;
    final width =
        (thermal ? paperWidthMm * PdfPageFormat.mm : PdfPageFormat.a4.width) -
            margin * 2;
    final fontSize = thermal ? (paperWidthMm == 58 ? 10.0 : 11.5) : 16.0;
    final rows = <({pw.Widget widget, double height})>[];
    Future<void> text(String value,
        {bool bold = false, bool center = false, double? size}) async {
      final paragraph = ui.ParagraphBuilder(ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
        textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
        fontFamily: 'FastStoreDevanagari',
        fontSize: size ?? fontSize,
        fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
        height: 1.55,
      ))
        ..pushStyle(ui.TextStyle(
            color: const ui.Color(0xff000000),
            fontFamily: 'FastStoreDevanagari',
            fontSize: size ?? fontSize,
            fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400))
        ..addText(value);
      final layout = paragraph.build()
        ..layout(ui.ParagraphConstraints(width: width));
      const scale = 3.0;
      final height = layout.height.ceilToDouble() + 4;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(scale);
      canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
      canvas.drawParagraph(layout, const ui.Offset(0, 2));
      final picture = recorder.endRecording();
      final image = await picture.toImage(
          (width * scale).ceil(), (height * scale).ceil());
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Could not prepare bill text for printing.');
        }
        rows.add((
          widget: pw.Image(pw.MemoryImage(data.buffer.asUint8List()),
              width: width, height: height),
          height: height
        ));
      } finally {
        image.dispose();
        picture.dispose();
        layout.dispose();
      }
    }

    void rule() => rows.add((
          widget: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Divider(height: 1)),
          height: 11
        ));
    String money(double amount) =>
        '${label('NPR', 'रु.')} ${amount.toStringAsFixed(2)}';
    await text(label('Ram Prasad General Store', 'राम प्रसाद जनरल स्टोर'),
        bold: true, center: true, size: fontSize + 3);
    await text(label('Janakpur, Nepal', 'जनकपुर, नेपाल'), center: true);
    await text(
        '${label('PAN No.', 'प्यान नं.')} ${AppConstants.storePanNumber}',
        center: true);
    rule();
    await text(label('TAX INVOICE', 'कर बिल'), bold: true, center: true);
    await text('${label('Bill No.', 'बिल नं.')} $number');
    await text(
        '${label('Date', 'मिति')}: ${date.toLocal().toString().substring(0, 16)}');
    if (customerName?.trim().isNotEmpty == true) {
      await text('${label('Customer', 'ग्राहक')}: $customerName');
    }
    if (customerPhone?.trim().isNotEmpty == true) {
      await text('${label('Phone', 'फोन')}: $customerPhone');
    }
    rule();
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await text('${i + 1}. ${item.item}', bold: true);
      final quantity = nepali
          ? item.quantity
              .replaceAll(RegExp(r'\bkg\b'), 'किलोग्राम')
              .replaceAll(RegExp(r'\bg\b'), 'ग्राम')
          : item.quantity;
      final numeric = double.tryParse(item.quantity.split(' ').first);
      final isGrams = RegExp(r'\bg\b').hasMatch(item.quantity);
      final denominator = numeric == null || numeric == 0
          ? null
          : numeric / (isGrams ? 1000 : 1);
      await text('${label('Qty', 'परिमाण')}: $quantity'
          '${denominator == null ? '' : ' · ${label('Rate', 'दर')}: ${money(item.amount / denominator)}'}');
      await text('${label('Amount', 'जम्मा')}: ${money(item.amount)}');
      rule();
    }
    await text('${label('Subtotal', 'उपजम्मा')}: ${money(subtotal)}');
    await text('${label('Discount', 'छुट')}: ${money(discount)}');
    await text('${label('VAT', 'भ्याट')}: ${money(vat)}');
    if (other != 0) {
      await text(
          '${label('Delivery / other', 'डेलिभरी / अन्य')}: ${money(other)}');
    }
    await text(
        '${label('TOTAL PAYABLE', 'तिर्नुपर्ने जम्मा')}: ${money(total)}',
        bold: true,
        size: fontSize + 2);
    if (paid != null) await text('${label('Paid', 'तिरेको')}: ${money(paid)}');
    if (due != null && due > 0) {
      await text('${label('Balance due', 'बाँकी रकम')}: ${money(due)}',
          bold: true);
    }
    final methods = {
      'CASH': 'नगद',
      'DIGITAL': 'डिजिटल',
      'ESEWA': 'ईसेवा',
      'FONEPAY': 'फोनपे',
      'CREDIT': 'उधारो',
      'CARD': 'कार्ड'
    };
    final statuses = {
      'COMPLETED': 'भुक्तानी पूरा',
      'PAID': 'भुक्तानी पूरा',
      'PARTIAL': 'केही भुक्तानी',
      'PENDING': 'भुक्तानी बाँकी',
      'REFUNDED': 'फिर्ता भएको',
      'CANCELLED': 'रद्द भएको'
    };
    await text(
        '${label('Payment method', 'भुक्तानी विधि')}: ${nepali ? methods[method] ?? method : method}');
    await text(
        '${label('Payment status', 'भुक्तानी अवस्था')}: ${nepali ? statuses[status] ?? status : status}');
    rule();
    await text(
        label('Thank you for shopping with us!',
            'हाम्रो पसलमा आउनुभएकोमा धन्यवाद!'),
        center: true);
    final document = pw.Document();
    final widgets = [
      for (final row in rows) row.widget,
      if (paymentInstructions != null) paymentInstructions
    ];
    if (thermal) {
      final height = rows.fold<double>(0, (sum, row) => sum + row.height) +
          margin * 2 +
          (paymentInstructions == null ? 0 : 300);
      document.addPage(pw.Page(
          pageFormat: PdfPageFormat(width + margin * 2, math.max(height, 100),
              marginAll: margin),
          build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: widgets)));
    } else {
      document.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(margin),
          maxPages: 1000,
          build: (_) => widgets));
    }
    return document.save();
  }
}
