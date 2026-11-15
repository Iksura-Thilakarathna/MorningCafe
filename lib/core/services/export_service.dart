import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../utils/formatters.dart';

class ExportService {
  /// Generates a CSV file and shares it via native share dialog
  static Future<String> exportCsv(Map<String, dynamic> data) async {
    final period = data['period'] as Map<String, dynamic>;
    final sDate = period['start_date'] as String;
    final eDate = period['end_date'] as String;

    final rows = <List<dynamic>>[];
    rows.add(['MORNING CAFE BUSINESS MANAGER - FINANCIAL STATEMENT']);
    rows.add(['Reporting Period', '$sDate to $eDate']);
    rows.add(['Currency', 'LKR']);
    rows.add(['Timezone', 'Asia/Colombo']);
    rows.add([]);

    rows.add(['KEY FINANCIAL METRICS', 'AMOUNT (LKR)']);
    rows.add(['Sales Revenue', data['sales_revenue']]);
    rows.add(['Additional Income', data['additional_income']]);
    rows.add(['Total Business Income', data['total_business_income']]);
    rows.add(['Cost of Products Sold (COGS)', data['cogs']]);
    rows.add(['Gross Profit', data['gross_profit']]);
    rows.add(['Stock Wastage Cost', data['wastage_cost']]);
    rows.add(['Additional Operating Expenses', data['operating_expenses']]);
    rows.add(['Net Operating Profit', data['net_profit']]);
    rows.add(['Profit Margin (%)', '${(data['profit_margin'] as num).toStringAsFixed(2)}%']);
    rows.add(['Total Ingredient Purchases', data['total_purchases']]);
    rows.add(['Opening Inventory Valuation', data['opening_inventory_value']]);
    rows.add(['Closing Inventory Valuation', data['closing_inventory_value']]);
    rows.add(['Cash Inflows', data['cash_inflows']]);
    rows.add(['Cash Outflows', data['cash_outflows']]);
    rows.add(['Net Cash Flow', data['net_cash_flow']]);
    rows.add([]);

    rows.add(['DAILY BREAKDOWN']);
    rows.add(['Date', 'Day', 'Sales Revenue', 'COGS', 'Gross Profit', 'Wastage', 'Expenses', 'Purchases', 'Net Profit']);

    final daily = (data['daily_breakdown'] as List<dynamic>?) ?? [];
    for (final d in daily) {
      final map = d as Map<String, dynamic>;
      rows.add([
        map['date'],
        map['day_name'],
        map['sales_revenue'],
        map['cogs'],
        map['gross_profit'],
        map['wastage_cost'],
        map['operating_expenses'],
        map['purchases'],
        map['net_profit'],
      ]);
    }

    final csvContent = csv.encode(rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Morning_Cafe_Report_${sDate}_to_$eDate.csv');
    await file.writeAsString(csvContent);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Morning Cafe Financial Statement ($sDate to $eDate)',
      subject: 'Morning Cafe Financial Statement',
    );

    return file.path;
  }

  /// Generates a PDF file and shares it via native share dialog
  static Future<String> exportPdf(Map<String, dynamic> data) async {
    final period = data['period'] as Map<String, dynamic>;
    final sDate = period['start_date'] as String;
    final eDate = period['end_date'] as String;

    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
      logoImage = pw.MemoryImage(logoBytes);
    } catch (_) {}

    const espressoColor = PdfColor.fromInt(0xFF381A0B);
    const goldAccent = PdfColor.fromInt(0xFFE5A328);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 44, height: 44),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Morning Cafe', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: espressoColor)),
                          pw.Text('Piliyandala, Sri Lanka • Business Management Statement', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Period: $sDate to $eDate', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Currency: LKR', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ),
            pw.Container(height: 2, color: goldAccent, margin: const pw.EdgeInsets.only(top: 8, bottom: 12)),
            pw.Text('1. Executive Financial Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: espressoColor)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                _buildPdfRow('Total Sales Revenue', Formatters.currency(data['sales_revenue'])),
                _buildPdfRow('Additional Business Income', Formatters.currency(data['additional_income'])),
                _buildPdfRow('Total Business Income', Formatters.currency(data['total_business_income']), isBold: true),
                _buildPdfRow('Cost of Products Sold (COGS - FIFO)', '- ${Formatters.currency(data['cogs'])}'),
                _buildPdfRow('Gross Profit', Formatters.currency(data['gross_profit']), isBold: true),
                _buildPdfRow('Stock Wastage Cost', '- ${Formatters.currency(data['wastage_cost'])}'),
                _buildPdfRow('Additional Operating Expenses', '- ${Formatters.currency(data['operating_expenses'])}'),
                _buildPdfRow('OPERATIONAL NET PROFIT', Formatters.currency(data['net_profit']), isBold: true, highlight: true),
                _buildPdfRow('Profit Margin (%)', '${(data['profit_margin'] as num).toStringAsFixed(2)}%'),
                _buildPdfRow('Total Ingredient Purchases (Asset)', Formatters.currency(data['total_purchases'])),
                _buildPdfRow('Opening Inventory Valuation', Formatters.currency(data['opening_inventory_value'])),
                _buildPdfRow('Closing Inventory Valuation', Formatters.currency(data['closing_inventory_value'])),
                _buildPdfRow('NET CASH FLOW', Formatters.currency(data['net_cash_flow']), isBold: true),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('2. Daily Operations Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: espressoColor)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: espressoColor),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Date', 'Day', 'Revenue', 'COGS', 'Gross', 'Wastage', 'Expenses', 'Purchases', 'Net Profit'],
              data: [
                for (final d in (data['daily_breakdown'] as List<dynamic>? ?? []))
                  [
                    d['date'],
                    d['day_name'],
                    Formatters.currency(d['sales_revenue']),
                    Formatters.currency(d['cogs']),
                    Formatters.currency(d['gross_profit']),
                    Formatters.currency(d['wastage_cost']),
                    Formatters.currency(d['operating_expenses']),
                    Formatters.currency(d['purchases']),
                    Formatters.currency(d['net_profit']),
                  ]
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Generated by Morning Cafe Business Manager • Local Offline Architecture', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ];
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Morning_Cafe_Statement_${sDate}_to_$eDate.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Morning Cafe Financial Statement ($sDate to $eDate)',
      subject: 'Morning Cafe Statement',
    );

    return file.path;
  }

  static pw.TableRow _buildPdfRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return pw.TableRow(
      decoration: highlight ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAF2ED)) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 10 : 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: isBold ? 10 : 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: highlight ? const PdfColor.fromInt(0xFF381A0B) : PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }
}
