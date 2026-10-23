import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../data/models/category.dart';
import '../../data/models/item.dart';

// Uses the bundled Noto Sans (it has the ₱ sign). If the font files are
// missing, falls back to a built-in font and writes "PHP" instead of ₱.
class _PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final bool hasPesoSign;
  const _PdfFonts(this.regular, this.bold, this.hasPesoSign);

  static Future<_PdfFonts> load() async {
    try {
      final regular = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      return _PdfFonts(pw.Font.ttf(regular), pw.Font.ttf(bold), true);
    } catch (_) {
      return _PdfFonts(pw.Font.helvetica(), pw.Font.helveticaBold(), false);
    }
  }

  String money(int cents) {
    final text = Money.format(cents);
    return hasPesoSign ? text : text.replaceAll('₱', 'PHP ');
  }
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  bool right = false,
  double vPad = 3,
}) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: vPad),
    child: pw.Align(
      alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ),
  );
}

pw.Widget _pageHeader(String storeName, String title) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            storeName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Printed ${Fmt.dateTime(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      pw.Text(title, style: pw.TextStyle(fontSize: 12)),
      pw.Divider(thickness: 0.5),
    ],
  );
}

pw.Widget _pageFooter(pw.Context context) {
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      'Page ${context.pageNumber} of ${context.pagesCount}',
      style: pw.TextStyle(fontSize: 8),
    ),
  );
}

class PdfReports {
  PdfReports._();

  /// Every item, grouped by category, with stock and both prices.
  static Future<Uint8List> inventoryList({
    required List<Item> items,
    required List<ItemCategory> categories,
    required String storeName,
  }) async {
    final fonts = await _PdfFonts.load();
    final doc = pw.Document(title: 'Inventory list');

    final sections = <pw.Widget>[];
    for (final c in categories) {
      final inCategory = items.where((i) => i.categoryId == c.id).toList();
      if (inCategory.isEmpty) continue;
      sections.add(_inventorySection(c.name, inCategory, fonts));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (context) => _pageHeader(storeName, 'Inventory list'),
        footer: _pageFooter,
        build: (context) => [
          ...sections,
          pw.SizedBox(height: 12),
          pw.Text(
            '${items.length} item${items.length == 1 ? '' : 's'}',
            style: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _inventorySection(
    String name,
    List<Item> items,
    _PdfFonts fonts,
  ) {
    final line = pw.BorderSide(width: 0.4, color: PdfColors.grey500);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text(
          name,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder(
            top: line,
            bottom: line,
            horizontalInside: line,
          ),
          columnWidths: {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(1.8),
            4: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('Item', bold: true),
                _cell('Unit', bold: true),
                _cell('In stock', bold: true, right: true),
                _cell('Buying', bold: true, right: true),
                _cell('Selling', bold: true, right: true),
              ],
            ),
            for (final i in items)
              pw.TableRow(
                children: [
                  _cell(i.name),
                  _cell(i.unit.label),
                  _cell(i.inStock ? Qty.plain(i.quantity) : '0', right: true),
                  _cell(fonts.money(i.buyingPrice), right: true),
                  _cell(fonts.money(i.sellingPrice), right: true),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// Items that are out of stock or low, with a tick box and a blank
  /// "To buy" box to fill in by hand.
  static Future<Uint8List> shoppingList({
    required List<Item> items,
    required List<ItemCategory> categories,
    required int lowStockDefault,
    required String storeName,
  }) async {
    final fonts = await _PdfFonts.load();
    final doc = pw.Document(title: 'Shopping list');

    final order = {
      for (var i = 0; i < categories.length; i++) categories[i].id: i,
    };
    final names = {for (final c in categories) c.id: c.name};
    final low =
        items.where((i) => !i.inStock || i.isLowStock(lowStockDefault)).toList()
          ..sort((a, b) {
            final byCategory = (order[a.categoryId] ?? 0).compareTo(
              order[b.categoryId] ?? 0,
            );
            return byCategory != 0
                ? byCategory
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    final grid = pw.TableBorder.all(width: 0.5, color: PdfColors.grey600);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (context) =>
            _pageHeader(storeName, 'Shopping list (low and out of stock)'),
        footer: _pageFooter,
        build: (context) => [
          pw.SizedBox(height: 6),
          pw.Table(
            border: grid,
            columnWidths: {
              0: pw.FlexColumnWidth(0.6),
              1: pw.FlexColumnWidth(3.6),
              2: pw.FlexColumnWidth(2.2),
              3: pw.FlexColumnWidth(1.7),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(2.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell(''),
                  _cell('Item', bold: true),
                  _cell('Category', bold: true),
                  _cell('In stock', bold: true),
                  _cell('Alert at', bold: true, right: true),
                  _cell('To buy', bold: true),
                ],
              ),
              for (final i in low)
                pw.TableRow(
                  children: [
                    _checkboxCell(),
                    _cell(i.name, vPad: 7),
                    _cell(names[i.categoryId] ?? '', vPad: 7),
                    _cell(
                      i.inStock ? Qty.format(i.quantity, i.unit) : 'OUT',
                      bold: !i.inStock,
                      vPad: 7,
                    ),
                    _cell(
                      Qty.plain(i.lowStockThreshold ?? lowStockDefault),
                      right: true,
                      vPad: 7,
                    ),
                    _cell('', vPad: 7),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '${low.length} item${low.length == 1 ? '' : 's'} to restock',
            style: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _checkboxCell() {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 7),
      child: pw.Center(
        child: pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
        ),
      ),
    );
  }
}
