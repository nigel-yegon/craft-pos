import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/theme/app_theme.dart';
import 'expense_form_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ExpenseProvider provider;
  const SettingsScreen({super.key, required this.provider});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.generateDueRecurringExpenses();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatKsh(int minor) => 'KSh ${(minor / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Settings'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textLight,
          tabs: const [
            Tab(text: 'One-off Expenses'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOneOffTab(),
          _buildRecurringTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Add Expense' : 'Add Recurring'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseFormScreen(
                provider: widget.provider,
                isRecurring: _tabController.index == 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOneOffTab() {
    return StreamBuilder<List<Expense>>(
      stream: widget.provider.expensesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final expenses = snapshot.data!;
        if (expenses.isEmpty) {
          return const Center(
            child: Text('No expenses recorded yet.',
                style: TextStyle(color: AppTheme.textLight)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final e = expenses[index];
            final balance = e.amountMinor - e.paidAmountMinor;
            final isPaid = e.status == 'paid';
            final isPartial = e.status == 'partial';

            final leadingColor = isPaid
                ? Colors.green
                : isPartial
                ? Colors.blue
                : Colors.orange;
            final leadingIcon = isPaid
                ? Icons.check_circle
                : isPartial
                ? Icons.pie_chart
                : Icons.schedule;

            return Card(
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: leadingColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(leadingIcon, color: leadingColor, size: 20),
                ),
                title: Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${e.category} • ${isPaid ? 'Paid' : isPartial ? 'Partial' : 'Pending'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatKsh(e.amountMinor),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark),
                    ),
                    if (!isPaid)
                      Text(
                        'Bal: ${_formatKsh(balance)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: leadingColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _detailRow('Total', _formatKsh(e.amountMinor)),
                  _detailRow('Paid', _formatKsh(e.paidAmountMinor),
                      color: Colors.green),
                  _detailRow('Balance', _formatKsh(balance),
                      color: leadingColor, bold: true),
                  if (e.dueDate != null)
                    _detailRow('Due',
                        DateFormat('dd MMM yyyy').format(e.dueDate!)),
                  if (e.paidAt != null)
                    _detailRow(
                        'Last payment',
                        DateFormat('dd MMM yyyy, HH:mm')
                            .format(e.paidAt!)),
                  if (e.note != null) _detailRow('Note', e.note!),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isPaid)
                        TextButton.icon(
                          onPressed: () =>
                              _showPaymentDialog(e, balance),
                          icon: const Icon(Icons.payments_outlined,
                              size: 18, color: AppTheme.primaryGreen),
                          label: const Text('Record Payment'),
                        ),
                      if (!isPaid)
                        TextButton.icon(
                          onPressed: () =>
                              widget.provider.markPaid(e.id),
                          icon: const Icon(Icons.check,
                              size: 18, color: Colors.green),
                          label: const Text('Mark Paid'),
                        ),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(e),
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textLight)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color ?? AppTheme.textDark,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentDialog(Expense e, int balance) async {
    final controller = TextEditingController(
      text: (balance / 100).toStringAsFixed(2),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment — ${e.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remaining balance: ${_formatKsh(balance)}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount paid (KSh)',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final amount = ((double.tryParse(controller.text) ?? 0) * 100).toInt();
    if (amount <= 0) return;

    await widget.provider.recordPayment(
      expenseId: e.id,
      amountMinor: amount,
    );
  }

  Future<void> _confirmDelete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${e.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) widget.provider.deleteExpense(e.id);
  }

  Widget _buildRecurringTab() {
    return StreamBuilder<List<RecurringExpense>>(
      stream: widget.provider.recurringStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final recurring = snapshot.data!;
        if (recurring.isEmpty) {
          return const Center(
            child: Text('No recurring expenses set.',
                style: TextStyle(color: AppTheme.textLight)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: recurring.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final r = recurring[index];
            final overdue = r.nextDueDate != null &&
                r.nextDueDate!.isBefore(DateTime.now());
            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (overdue ? Colors.red : AppTheme.primaryGreen)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.repeat,
                      color:
                      overdue ? Colors.red : AppTheme.primaryGreen,
                      size: 20),
                ),
                title: Text(
                  r.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${r.category} • Every ${r.period}'
                      '${r.nextDueDate != null ? '\nNext due: ${DateFormat('dd MMM').format(r.nextDueDate!)}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: overdue ? Colors.red : null),
                ),
                isThreeLine: r.nextDueDate != null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatKsh(r.amountMinor),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark),
                    ),
                    Switch(
                      value: r.isActive,
                      onChanged: (v) => widget.provider
                          .toggleRecurringActive(r.id, v),
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
}