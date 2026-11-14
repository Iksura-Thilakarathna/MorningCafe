import 'package:flutter/material.dart';
import '../../../core/services/export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../finance/data/finance_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FinanceService _financeService = FinanceService();

  late DateTime _startDate;
  late DateTime _endDate;
  String _activeFilter = 'This Week';
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isFinalized = false;

  @override
  void initState() {
    super.initState();
    _applyFilter('This Week');
  }

  void _applyFilter(String filter) {
    _activeFilter = filter;
    final now = DateTime.now();

    switch (filter) {
      case 'Today':
        _startDate = now;
        _endDate = now;
        break;
      case 'Yesterday':
        final y = now.subtract(const Duration(days: 1));
        _startDate = y;
        _endDate = y;
        break;
      case 'Last 7 Days':
        _startDate = now.subtract(const Duration(days: 6));
        _endDate = now;
        break;
      case 'This Week':
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _endDate = now;
        break;
      case 'Previous Week':
        final lastMon = now.subtract(Duration(days: now.weekday + 6));
        _startDate = lastMon;
        _endDate = lastMon.add(const Duration(days: 6));
        break;
    }

    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final sStr = Formatters.date(_startDate);
    final eStr = Formatters.date(_endDate);
    final report = await _financeService.calculate(sStr, eStr);
    final fin = await _financeService.getFinalizedPeriod(sStr, eStr);

    if (mounted) {
      setState(() {
        _data = report;
        _isFinalized = fin != null;
        _isLoading = false;
      });
    }
  }

  void _showFinalizeDialog() {
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize Reporting Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Period: ${Formatters.date(_startDate)} to ${Formatters.date(_endDate)}'),
            const SizedBox(height: 8),
            const Text(
              'Finalizing archives the current profit calculation in the permanent audit ledger. Any subsequent edits will be tracked as amendments.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Finalization Notes (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Lock & Finalize'),
            onPressed: () async {
              await _financeService.finalizeReport(
                Formatters.date(_startDate),
                Formatters.date(_endDate),
                notesCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              _loadReport();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Period finalized and archived!'), backgroundColor: AppColors.success),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Financial Statements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export CSV / Share',
            onPressed: _data == null
                ? null
                : () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating CSV export...')));
                    await ExportService.exportCsv(_data!);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF / Share',
            onPressed: _data == null
                ? null
                : () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF statement...')));
                    await ExportService.exportPdf(_data!);
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateFilterRow(),
                  const SizedBox(height: 14),
                  if (_isFinalized)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.lock, size: 16, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('This reporting period is finalized and archived.', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  _buildStatementCard(),
                  const SizedBox(height: 16),
                  _buildInventoryReconciliationCard(),
                  const SizedBox(height: 16),
                  _buildProductBreakdownCard(),
                  const SizedBox(height: 16),
                  _buildDailyBreakdownCard(),
                  const SizedBox(height: 24),
                  if (!_isFinalized)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Finalize This Reporting Period'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: _showFinalizeDialog,
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildDateFilterRow() {
    final filters = ['This Week', 'Last 7 Days', 'Previous Week', 'Today'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...filters.map((f) {
            final sel = _activeFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                selected: sel,
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                onSelected: (v) {
                  if (v) _applyFilter(f);
                },
              ),
            );
          }),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 14),
            label: const Text('Custom Range', style: TextStyle(fontSize: 12)),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
              );
              if (range != null) {
                setState(() {
                  _startDate = range.start;
                  _endDate = range.end;
                  _activeFilter = 'Custom';
                });
                _loadReport();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatementCard() {
    if (_data == null) return const SizedBox.shrink();
    final d = _data!;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${Formatters.date(_startDate)} to ${Formatters.date(_endDate)}', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            const Divider(height: 20),
            _buildRow('Sales Revenue', Formatters.currency(d['sales_revenue'])),
            _buildRow('Additional Business Income', '+ ${Formatters.currency(d['additional_income'])}', color: AppColors.success),
            _buildRow('Total Business Income', Formatters.currency(d['total_business_income']), isBold: true),
            const Divider(height: 16),
            _buildRow('Cost of Products Sold (COGS - FIFO)', '- ${Formatters.currency(d['cogs'])}', color: AppColors.danger),
            _buildRow('Gross Profit', Formatters.currency(d['gross_profit']), isBold: true),
            const Divider(height: 16),
            _buildRow('Stock Wastage Cost', '- ${Formatters.currency(d['wastage_cost'])}', color: AppColors.warning),
            _buildRow('Additional Operating Expenses', '- ${Formatters.currency(d['operating_expenses'])}', color: AppColors.danger),
            const Divider(height: 20, thickness: 1.5),
            _buildRow(
              'OPERATIONAL NET PROFIT',
              Formatters.currency(d['net_profit']),
              isBold: true,
              fontSize: 16,
              color: (d['net_profit'] as num) >= 0 ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(height: 4),
            _buildRow(
              'Profit Margin (% of Sales)',
              '${(d['profit_margin'] as num).toStringAsFixed(2)}%',
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryReconciliationCard() {
    if (_data == null) return const SizedBox.shrink();
    final d = _data!;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventory Asset Reconciliation (Section 18.7 & 20)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Purchases are capitalized as inventory assets and deducted via COGS as consumed.', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            const Divider(height: 16),
            _buildRow('Opening Inventory Valuation', Formatters.currency(d['opening_inventory_value'])),
            _buildRow('Total Ingredient Purchases in Period', '+ ${Formatters.currency(d['total_purchases'])}', color: AppColors.info),
            _buildRow('Cost of Ingredients Consumed (COGS)', '- ${Formatters.currency(d['cogs'])}', color: AppColors.danger),
            _buildRow('Stock Wastage Cost in Period', '- ${Formatters.currency(d['wastage_cost'])}', color: AppColors.warning),
            const Divider(height: 16),
            _buildRow('Closing Inventory Valuation', Formatters.currency(d['closing_inventory_value']), isBold: true, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildProductBreakdownCard() {
    if (_data == null) return const SizedBox.shrink();
    final prods = (_data!['product_breakdown'] as List<dynamic>?) ?? [];

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Sales Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(height: 16),
            if (prods.isEmpty)
              const Text('No product sales recorded in this period.', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))
            else
              ...prods.map((p) {
                final sold = (p['units_sold'] as num).toInt();
                final rev = (p['revenue'] as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${p['name']} ($sold units)', style: const TextStyle(fontSize: 13)),
                      Text(Formatters.currency(rev), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBreakdownCard() {
    if (_data == null) return const SizedBox.shrink();
    final daily = (_data!['daily_breakdown'] as List<dynamic>?) ?? [];

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Breakdown Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Revenue')),
                  DataColumn(label: Text('COGS')),
                  DataColumn(label: Text('Wastage')),
                  DataColumn(label: Text('Expenses')),
                  DataColumn(label: Text('Net Profit')),
                ],
                rows: daily.map((d) {
                  final net = (d['net_profit'] as num).toDouble();
                  return DataRow(cells: [
                    DataCell(Text(d['date'].toString().substring(5))),
                    DataCell(Text(Formatters.currency(d['sales_revenue']))),
                    DataCell(Text(Formatters.currency(d['cogs']))),
                    DataCell(Text(Formatters.currency(d['wastage_cost']))),
                    DataCell(Text(Formatters.currency(d['operating_expenses']))),
                    DataCell(Text(
                      Formatters.currency(net),
                      style: TextStyle(fontWeight: FontWeight.bold, color: net >= 0 ? AppColors.success : AppColors.danger),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.darkText : AppColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isBold ? AppColors.darkText : AppColors.darkText),
            ),
          ),
        ],
      ),
    );
  }
}
