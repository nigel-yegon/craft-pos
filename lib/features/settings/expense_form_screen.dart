import 'package:flutter/material.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/theme/app_theme.dart';

class ExpenseFormScreen extends StatefulWidget {
  final ExpenseProvider provider;
  final bool isRecurring;

  const ExpenseFormScreen({
    super.key,
    required this.provider,
    this.isRecurring = false,
  });

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _category = 'general';
  String _period = 'monthly';
  String _status = 'pending';
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount =
    ((double.tryParse(_amountController.text) ?? 0) * 100).toInt();

    if (widget.isRecurring) {
      if (_dueDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a first due date')),
        );
        return;
      }
      await widget.provider.addRecurring(
        name: _nameController.text.trim(),
        amountMinor: amount,
        category: _category,
        period: _period,
        nextDueDate: _dueDate,
      );
    } else {
      await widget.provider.addExpense(
        name: _nameController.text.trim(),
        amountMinor: amount,
        category: _category,
        status: _status,
        dueDate: _dueDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isRecurring ? 'New Recurring Expense' : 'New Expense',
        ),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Name ───
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Expense Name *',
                hintText: 'e.g. Rent, Electricity, Salary',
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ─── Amount ───
            TextFormField(
              controller: _amountController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (KSh) *',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a positive amount';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ─── Category ───
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'rent', child: Text('Rent')),
                DropdownMenuItem(value: 'salary', child: Text('Salary')),
                DropdownMenuItem(value: 'utility', child: Text('Utility')),
                DropdownMenuItem(value: 'supplies', child: Text('Supplies')),
                DropdownMenuItem(value: 'transport', child: Text('Transport')),
                DropdownMenuItem(value: 'general', child: Text('General')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'general'),
            ),
            const SizedBox(height: 12),

            // ─── Recurring-only fields ───
            if (widget.isRecurring) ...[
              DropdownButtonFormField<String>(
                initialValue: _period,
                decoration: const InputDecoration(labelText: 'Repeats'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (v) => setState(() => _period = v ?? 'monthly'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today,
                    color: AppTheme.primaryGreen),
                title: Text(
                  _dueDate == null
                      ? 'First due date (required)'
                      : 'First due: ${_dueDate!.toLocal().toString().split(' ')[0]}',
                ),
                trailing: _dueDate == null
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dueDate = null),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate:
                    DateTime.now().subtract(const Duration(days: 365)),
                    lastDate:
                    DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
            ]

            // ─── One-off-only fields ───
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'pending'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today,
                    color: AppTheme.primaryGreen),
                title: Text(
                  _dueDate == null
                      ? 'Due date (optional)'
                      : 'Due: ${_dueDate!.toLocal().toString().split(' ')[0]}',
                ),
                trailing: _dueDate == null
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dueDate = null),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate:
                    DateTime.now().subtract(const Duration(days: 365)),
                    lastDate:
                    DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration:
                const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}