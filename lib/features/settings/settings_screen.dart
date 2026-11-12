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
    // Materialize any due recurring expenses
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

  // ═══ TAB 1: One-off expenses ═══
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
            final isPaid = e.status == 'paid';
            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isPaid ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.check_circle
                        : Icons.schedule,
                    color: isPaid ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${e.category} • ${isPaid ? 'Paid' : 'Pending'}'
                      '${e.dueDate != null ? '\nDue: ${DateFormat('dd MMM').format(e.dueDate!)}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: e.dueDate != null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatKsh(e.amountMinor),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (!isPaid)
                      IconButton(
                        icon: const Icon(Icons.payments_outlined,
                            color: AppTheme.primaryGreen, size: 20),
                        tooltip: 'Mark as paid',
                        onPressed: () => widget.provider.markPaid(e.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                onLongPress: () => _confirmDelete(e),
              ),
            );
          },
        );
      },
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) widget.provider.deleteExpense(e.id);
  }

  // ═══ TAB 2: Recurring ═══
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
            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.repeat,
                      color: AppTheme.primaryGreen, size: 20),
                ),
                title: Text(
                  r.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${r.category} • Every ${r.period}',
                  style: const TextStyle(fontSize: 12),
                ),
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