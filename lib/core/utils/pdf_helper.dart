import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class PdfHelper {
  // ═══════════════════════════════════════════════════════════════════
  // 1. SALES REPORT PDF
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> generateSalesReport({
    required String businessName,
    required List<Sale> sales,
    required Map<String, int> summary,
    required DateTime start,
    required DateTime end,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Sales Report', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                pw.Text(
                  '${dateFormat.format(start)} - ${dateFormat.format(end)}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                _summaryRow('Total Sales', currencyFormat.format((summary['sales'] ?? 0) / 100)),
                _summaryRow('Total Profit', currencyFormat.format((summary['profit'] ?? 0) / 100)),
                _summaryRow('Stock Valuation', currencyFormat.format((summary['stockValue'] ?? 0) / 100)),
                _summaryRow('Total Transactions', '${sales.length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Transactions', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Payment', 'Status', 'Amount'],
            data: sales.map((s) {
              return [
                dateFormat.format(s.createdAt),
                s.paymentMethod ?? 'Unknown',
                s.status,
                currencyFormat.format(s.totalAmountMinor / 100),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerCellDecoration: const pw.BoxDecoration(color: PdfColors.teal),
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text(
            'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. INVENTORY SUMMARY PDF
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> generateStockReport({
    required String businessName,
    required List<Map<String, dynamic>> stockRows,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);

    int totalIn = 0, totalOut = 0, totalBalance = 0;
    double totalValue = 0;
    for (final r in stockRows) {
      totalIn += r['totalIn'] as int;
      totalOut += r['totalOut'] as int;
      totalBalance += r['balance'] as int;
      totalValue += (r['valueMinor'] as int) / 100.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Inventory Summary', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                pw.Text('Generated on: ${dateFormat.format(DateTime.now())}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Totals', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                _summaryRow('Total Stock In', '${(totalIn / 1000).toStringAsFixed(0)} units'),
                _summaryRow('Total Stock Out', '${(totalOut / 1000).toStringAsFixed(0)} units'),
                _summaryRow('Total Balance', '${(totalBalance / 1000).toStringAsFixed(0)} units'),
                _summaryRow('Total Stock Value', currencyFormat.format(totalValue)),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Product Breakdown', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'In', 'Out', 'Balance', 'Avg Cost', 'Value'],
            data: stockRows.map((r) {
              final p = r['product'] as Product;
              final balance = (r['balance'] as int) / 1000.0;
              final avgCost = (r['avgCostMinor'] as int) / 100.0;
              final value = (r['valueMinor'] as int) / 100.0;

              return [
                p.name,
                (r['totalIn'] as int) ~/ 1000,
                (r['totalOut'] as int) ~/ 1000,
                balance.toStringAsFixed(2),
                currencyFormat.format(avgCost),
                currencyFormat.format(value),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerCellDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text('Generated by Craft POS', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. STOCK LEDGER PDF (With Filters)
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> generateLedgerReport({
    required String businessName,
    required List<StockMovement> movements,
    required Map<String, String> productNames,
    required String filterDescription,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Stock Ledger', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                pw.Text('Filter: $filterDescription', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                pw.Text('Generated: ${dateFormat.format(DateTime.now())}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Product', 'Type', 'Qty', 'Unit Cost'],
            data: movements.map((m) {
              final isIn = m.quantityMilli > 0;
              final qty = (m.quantityMilli / 1000.0).toStringAsFixed(m.quantityMilli % 1000 == 0 ? 0 : 2);
              final cost = m.unitCostMinor != null ? currencyFormat.format(m.unitCostMinor! / 100.0) : '-';

              return [
                dateFormat.format(m.createdAt),
                productNames[m.productId] ?? '(Deleted)',
                m.type.replaceAll('_', ' ').toUpperCase(),
                '${isIn ? '+' : ''}$qty',
                cost,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerCellDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.5),
            },
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text('End of Ledger. Total entries: ${movements.length}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ─── Helper ───
  static pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}