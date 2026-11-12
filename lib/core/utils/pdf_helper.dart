import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import 'package:printing/printing.dart';

class PdfHelper {
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
          // Header
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

          // Summary
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
                _summaryRow('Total Sales', currencyFormat.format(summary['sales']! / 100)),
                _summaryRow('Total Profit', currencyFormat.format(summary['profit']! / 100)),
                _summaryRow('Stock Valuation', currencyFormat.format(summary['stockValue']! / 100)),
                _summaryRow('Total Transactions', '${sales.length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Transactions Table
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