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
    final currencyFormat = NumberFormat.currency(
        symbol: 'KSh ', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) =>
        [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Sales Report', style: pw.TextStyle(
                    fontSize: 16, color: PdfColors.grey700)),
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
                pw.Text('Summary', style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                _summaryRow('Total Sales',
                    currencyFormat.format((summary['sales'] ?? 0) / 100)),
                _summaryRow('Total Profit',
                    currencyFormat.format((summary['profit'] ?? 0) / 100)),
                _summaryRow('Stock Valuation',
                    currencyFormat.format((summary['stockValue'] ?? 0) / 100)),
                _summaryRow('Total Transactions', '${sales.length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Transactions', style: pw.TextStyle(
              fontSize: 16, fontWeight: pw.FontWeight.bold)),
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
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerCellDecoration: const pw.BoxDecoration(color: PdfColors.teal),
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text(
            'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(
                DateTime.now())}',
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
    final currencyFormat = NumberFormat.currency(
        symbol: 'KSh ', decimalDigits: 2);

    int totalIn = 0,
        totalOut = 0,
        totalBalance = 0;
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
        build: (context) =>
        [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Inventory Summary', style: pw.TextStyle(
                    fontSize: 16, color: PdfColors.grey700)),
                pw.Text('Generated on: ${dateFormat.format(DateTime.now())}',
                    style: pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600)),
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
                pw.Text('Totals', style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                _summaryRow('Total Stock In',
                    '${(totalIn / 1000).toStringAsFixed(0)} units'),
                _summaryRow('Total Stock Out',
                    '${(totalOut / 1000).toStringAsFixed(0)} units'),
                _summaryRow('Total Balance',
                    '${(totalBalance / 1000).toStringAsFixed(0)} units'),
                _summaryRow(
                    'Total Stock Value', currencyFormat.format(totalValue)),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Product Breakdown', style: pw.TextStyle(
              fontSize: 16, fontWeight: pw.FontWeight.bold)),
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
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerCellDecoration: const pw.BoxDecoration(
                color: PdfColors.green800),
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
          pw.Text('Generated by Craft POS',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
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
    final currencyFormat = NumberFormat.currency(
        symbol: 'KSh ', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) =>
        [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Stock Ledger', style: pw.TextStyle(
                    fontSize: 16, color: PdfColors.grey700)),
                pw.Text('Filter: $filterDescription', style: pw.TextStyle(
                    fontSize: 12, color: PdfColors.grey600)),
                pw.Text('Generated: ${dateFormat.format(DateTime.now())}',
                    style: pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Product', 'Type', 'Qty', 'Unit Cost'],
            data: movements.map((m) {
              final isIn = m.quantityMilli > 0;
              final qty = (m.quantityMilli / 1000.0).toStringAsFixed(
                  m.quantityMilli % 1000 == 0 ? 0 : 2);
              final cost = m.unitCostMinor != null ? currencyFormat.format(
                  m.unitCostMinor! / 100.0) : '-';

              return [
                dateFormat.format(m.createdAt),
                productNames[m.productId] ?? '(Deleted)',
                m.type.replaceAll('_', ' ').toUpperCase(),
                '${isIn ? '+' : ''}$qty',
                cost,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerCellDecoration: const pw.BoxDecoration(
                color: PdfColors.grey800),
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
          pw.Text('End of Ledger. Total entries: ${movements.length}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. TRANSACTIONS REPORT PDF (with filters + split breakdown) ⭐ NEW
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> generateTransactionsReport({
    required String businessName,
    required List<Sale> sales,
    required String filterDescription,
    required DateTime generatedAt,
    Map<String, List<SalePayment>>? paymentBreakdown,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM, HH:mm');
    final currencyFormat =
    NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);

    final totalMinor =
    sales.fold<int>(0, (s, x) => s + x.totalAmountMinor);

    // Per-method totals from the split breakdown (when supplied).
    int cashMinor = 0;
    int mpesaMinor = 0;
    if (paymentBreakdown != null) {
      for (final entry in paymentBreakdown.values) {
        for (final p in entry) {
          if (p.method == 'cash') {
            cashMinor += p.amountMinor;
          } else if (p.method == 'mpesa') {
            mpesaMinor += p.amountMinor;
          }
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) =>
        [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName,
                    style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Transactions Report',
                    style: pw.TextStyle(
                        fontSize: 16, color: PdfColors.grey700)),
                pw.Text('Filter: $filterDescription',
                    style: pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600)),
                pw.Text(
                    'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(
                        generatedAt)}',
                    style: pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Summary ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                _summaryRow('Total Transactions', '${sales.length}'),
                _summaryRow('Total Amount',
                    currencyFormat.format(totalMinor / 100)),
                _summaryRow('Cash Collected',
                    currencyFormat.format(cashMinor / 100)),
                _summaryRow('M-Pesa Collected',
                    currencyFormat.format(mpesaMinor / 100)),
              ],
            ),
          ),

          pw.SizedBox(height: 24),
          pw.Text('Transactions',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),

          if (sales.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Center(
                child: pw.Text('No transactions match the filters.',
                    style: pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey600)),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Method', 'Amount', 'Split'],
              data: sales.map((s) {
                final splits = paymentBreakdown?[s.id];
                final splitLabel = (splits != null && splits.length > 1)
                    ? splits
                    .map((p) =>
                '${_prettyMethod(p.method)}: ${currencyFormat.format(
                    p.amountMinor / 100)}'
                    '${p.reference != null ? ' (${p.reference})' : ''}')
                    .join('\n')
                    : '—';

                return [
                  dateFormat.format(s.createdAt),
                  _prettyMethod(s.paymentMethod ?? 'cash'),
                  currencyFormat.format(s.totalAmountMinor / 100),
                  splitLabel,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration:
              const pw.BoxDecoration(color: PdfColors.indigo800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerCellDecoration:
              const pw.BoxDecoration(color: PdfColors.indigo800),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(3),
              },
            ),

          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text('Generated by Craft POS',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ─── Helper: pretty payment-method labels ───
  static String _prettyMethod(String m) {
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'mpesa':
        return 'M-Pesa';
      case 'cash+mpesa':
        return 'Cash + M-Pesa';
      default:
        return m;
    }
  }

  // ─── Helper: summary row ───
  static pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(value, style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════
// 5. REPORTS SCREEN SUMMARY PDF (full snapshot of Reports screen)
// ═══════════════════════════════════════════════════════════════════
  static Future<void> generateReportsSummary({
    required String businessName,
    required String periodLabel,
    required DateTime start,
    required DateTime end,
    required Map<String, int> summary,
    required List<Map<String, dynamic>> trend,
    required List<Sale> sales,
    required Map<String, List<SalePayment>> paymentBreakdown,
    required int cashTotalMinor,
    required int mpesaTotalMinor,
    required int expensePaidMinor,
    required int expensePendingMinor,
    required List<HeldOrder> heldOrders,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('dd MMM yyyy, HH:mm');
    final currencyFormat =
    NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);

    final netMinor = (summary['sales'] ?? 0) - expensePaidMinor;

// Aggregate held-order values (they aren't sales yet, but they're money
// pending collection — useful context on a summary report).
    final heldTotalMinor =
    heldOrders.fold<int>(0, (s, h) => s + h.totalAmountMinor);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) =>
        [
// ── Header ───────────────────────────────────────────
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName,
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Reports Summary',
                    style: pw.TextStyle(
                        fontSize: 16, color: PdfColors.grey700)),
                pw.Text(
                  'Period: $periodLabel  •  '
                      '${dateFormat.format(start)} – ${dateFormat.format(end)}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
                pw.Text('Generated: ${timeFormat.format(DateTime.now())}',
                    style:
                    pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

// ── Top-line metrics (mirrors 2×2 metric cards) ──────
          pw.Row(
            children: [
              pw.Expanded(
                child: _metricBox(
                  'Sales',
                  currencyFormat.format((summary['sales'] ?? 0) / 100),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _metricBox(
                  'Profit',
                  currencyFormat.format((summary['profit'] ?? 0) / 100),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _metricBox(
                  'Stock Value',
                  currencyFormat.format((summary['stockValue'] ?? 0) / 100),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _metricBox('Transactions', '${sales.length}'),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

// ── Money Position ───────────────────────────────────
          _sectionCard(
            title: 'MONEY POSITION',
            children: [
              _summaryRow('Money In (Sales)',
                  currencyFormat.format((summary['sales'] ?? 0) / 100)),
              _summaryRow('Money Out (Paid)',
                  currencyFormat.format(expensePaidMinor / 100)),
              _summaryRow('Pending Balances',
                  currencyFormat.format(expensePendingMinor / 100)),
              _summaryRow(
                  'Cash Collected',
                  currencyFormat.format(cashTotalMinor / 100)),
              _summaryRow('M-Pesa Collected',
                  currencyFormat.format(mpesaTotalMinor / 100)),
              pw.Divider(),
              _summaryRow(
                'Net Position',
                currencyFormat.format(netMinor / 100),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                netMinor >= 0
                    ? 'You are cash-positive for this period.'
                    : 'You are cash-negative for this period.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: netMinor >= 0
                      ? PdfColors.green800
                      : PdfColors.orange800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

// ── Sales Trend ──────────────────────────────────────
          pw.Text('Sales Trend (Last 7 Days)',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Day', 'Total'],
            data: trend
                .map((e) =>
            [
              '${e['label']}',
              currencyFormat.format((e['total'] as int) / 100),
            ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration:
            const pw.BoxDecoration(color: PdfColors.teal700),
            headerCellDecoration:
            const pw.BoxDecoration(color: PdfColors.teal700),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
            },
          ),
          pw.SizedBox(height: 20),

// ── Held Orders snapshot ─────────────────────────────
          if (heldOrders.isNotEmpty) ...[
            pw.Text('Held Orders (awaiting payment)',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                border: pw.Border.all(color: PdfColors.orange200, width: 0.5),
                borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${heldOrders.length} held order(s) totalling '
                        '${currencyFormat.format(heldTotalMinor / 100)}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'These are not included in the sales totals above. '
                        'Resume or cancel them from Sales → Held Orders.',
                    style:
                    pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

// ── Transactions (same 20 shown on screen) ───────────
          pw.Text('Transactions',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (sales.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Center(
                child: pw.Text('No transactions for this period.',
                    style: pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey600)),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Method', 'Amount', 'Split'],
              data: sales.map((s) {
                final splits = paymentBreakdown[s.id];
                final splitLabel = (splits != null && splits.length > 1)
                    ? splits
                    .map((p) =>
                '${_prettyMethod(p.method)}: '
                    '${currencyFormat.format(p.amountMinor / 100)}'
                    '${p.reference != null ? ' (${p.reference})' : ''}')
                    .join('\n')
                    : '—';

                return [
                  timeFormat.format(s.createdAt),
                  _prettyMethod(s.paymentMethod ?? 'cash'),
                  currencyFormat.format(s.totalAmountMinor / 100),
                  splitLabel,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
              const pw.BoxDecoration(color: PdfColors.indigo800),
              headerCellDecoration:
              const pw.BoxDecoration(color: PdfColors.indigo800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(3),
              },
            ),

          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text('Generated by Craft POS',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

// ─── Small helpers used only by the reports summary ───

  static pw.Widget _metricBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              letterSpacing: 1.0,
              color: PdfColors.grey700,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionCard({
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}