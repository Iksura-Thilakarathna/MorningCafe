import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../income_expense/data/income_expense_service.dart';
import '../data/finance_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IncomeExpenseService _incomeExpenseService = IncomeExpenseService();
  final FinanceService _financeService = FinanceService();

  List<Map<String, dynamic>> _incomeList = [];
  List<Map<String, dynamic>> _expenseList = [];
  Map<String, dynamic>? _cashFlowData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final sDate = Formatters.date(startOfWeek);
    final eDate = Formatters.date(now);

    final inc = await _incomeExpenseService.getIncomeList();
    final exp = await _incomeExpenseService.getExpensesList();
    final cf = await _financeService.calculate(sDate, eDate);

    if (mounted) {
      setState(() {
        _incomeList = inc;
        _expenseList = exp;
        _cashFlowData = cf;
        _isLoading = false;
      });
    }
  }

  void _showAddIncomeModal() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = AppConstants.incomeCategories.first;
    String status = 'received';
    DateTime txDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Additional Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Income Category'),
                      items: AppConstants.incomeCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setModalState(() => category = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Catering 20 snack boxes'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (LKR)', prefixText: 'LKR '),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Payment Status'),
                      items: const [
                        DropdownMenuItem(value: 'received', child: Text('Received (Cash Collected)')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending (Receivable)')),
                      ],
                      onChanged: (v) => setModalState(() => status = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        child: const Text('Save Income', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final amt = Formatters.parseDouble(amtCtrl.text);
                          if (amt <= 0 || descCtrl.text.trim().isEmpty) return;
                          await _incomeExpenseService.recordAdditionalIncome(
                            transactionDate: Formatters.date(txDate),
                            category: category,
                            description: descCtrl.text.trim(),
                            amount: amt,
                            paymentStatus: status,
                            notes: notesCtrl.text.trim(),
                          );
                          Navigator.pop(ctx);
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddExpenseModal() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = AppConstants.expenseCategories.first;
    String status = 'paid';
    DateTime expDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Operating Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Expense Category'),
                      items: AppConstants.expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setModalState(() => category = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Litro Gas Cylinder refill'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (LKR)', prefixText: 'LKR '),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Payment Status'),
                      items: const [
                        DropdownMenuItem(value: 'paid', child: Text('Paid (Cash Outflow)')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending (Payable)')),
                      ],
                      onChanged: (v) => setModalState(() => status = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        child: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final amt = Formatters.parseDouble(amtCtrl.text);
                          if (amt <= 0 || descCtrl.text.trim().isEmpty) return;
                          await _incomeExpenseService.recordAdditionalExpense(
                            expenseDate: Formatters.date(expDate),
                            category: category,
                            description: descCtrl.text.trim(),
                            amount: amt,
                            paymentStatus: status,
                            notes: notesCtrl.text.trim(),
                          );
                          Navigator.pop(ctx);
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Operations'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Cash Flow'),
            Tab(text: 'Income'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCashFlowTab(),
                _buildIncomeTab(),
                _buildExpensesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          if (_tabController.index == 1) {
            _showAddIncomeModal();
          } else {
            _showAddExpenseModal();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCashFlowTab() {
    if (_cashFlowData == null) return const SizedBox.shrink();
    final d = _cashFlowData!;
    final inflows = (d['cash_inflows'] as num).toDouble();
    final outflows = (d['cash_outflows'] as num).toDouble();
    final netCash = (d['net_cash_flow'] as num).toDouble();
    final netProfit = (d['net_profit'] as num).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This Week Cash Flow Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Cash Inflows (Collections):', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                      Text(Formatters.currency(inflows), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Cash Outflows (Payments):', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                      Text('- ${Formatters.currency(outflows)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('NET CASH FLOW:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        Formatters.currency(netCash),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: netCash >= 0 ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFEFF6FF),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash Flow vs Net Profit (Section 19)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark)),
                  const SizedBox(height: 6),
                  Text(
                    'Operational Net Profit (${Formatters.currency(netProfit)}) represents business value generated from food sales minus actual consumed ingredients.\nNet Cash Flow (${Formatters.currency(netCash)}) tracks real cash collected minus purchases & bills paid.',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeTab() {
    if (_incomeList.isEmpty) {
      return const Center(child: Text('No additional income recorded. Tap + to add.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _incomeList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = _incomeList[idx];
        final amt = (item['amount'] as num).toDouble();
        final status = item['payment_status'] as String;
        return Card(
          color: Colors.white,
          child: ListTile(
            title: Text(item['description'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${item['category']} • ${item['transaction_date']} • Status: $status'),
            trailing: Text(
              Formatters.currency(amt),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 15),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensesTab() {
    if (_expenseList.isEmpty) {
      return const Center(child: Text('No operating expenses recorded. Tap + to add.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _expenseList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = _expenseList[idx];
        final amt = (item['amount'] as num).toDouble();
        final status = item['payment_status'] as String;
        return Card(
          color: Colors.white,
          child: ListTile(
            title: Text(item['description'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${item['category']} • ${item['expense_date']} • Status: $status'),
            trailing: Text(
              '- ${Formatters.currency(amt)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 15),
            ),
          ),
        );
      },
    );
  }
}
