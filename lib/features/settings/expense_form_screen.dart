import 'package:flutter/material.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/clean_field.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isRecurring ? 'New recurring' : 'New expense',
          style: const TextStyle(
            color: AppTheme.inkBlack,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppTheme.brightGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            CleanField(
              label: 'Name',
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Rent, electricity, salary...',
                ),
                style: const TextStyle(
                  color: AppTheme.inkBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 24),

            CleanField(
              label: 'Amount (KES)',
              child: TextFormField(
                controller: _amountController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  color: AppTheme.inkBlack,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),

            CleanField(
              label: 'Category',
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: Colors.white,
                iconEnabledColor: AppTheme.inkBlack.withValues(alpha: 0.6),
                decoration: const InputDecoration(),
                style: const TextStyle(
                  color: AppTheme.inkBlack,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                items: const [
                  DropdownMenuItem(value: 'rent', child: Text('Rent')),
                  DropdownMenuItem(value: 'salary', child: Text('Salary')),
                  DropdownMenuItem(value: 'utility', child: Text('Utility')),
                  DropdownMenuItem(value: 'supplies', child: Text('Supplies')),
                  DropdownMenuItem(value: 'transport', child: Text('Transport')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (v) =>
                    setState(() => _category = v ?? 'general'),
              ),
            ),

            if (widget.isRecurring) ...[
              const SizedBox(height: 24),
              CleanField(
                label: 'Repeats',
                child: DropdownButtonFormField<String>(
                  initialValue: _period,
                  dropdownColor: Colors.white,
                  iconEnabledColor: AppTheme.inkBlack.withValues(alpha: 0.6),
                  decoration: const InputDecoration(),
                  style: const TextStyle(
                    color: AppTheme.inkBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (v) =>
                      setState(() => _period = v ?? 'monthly'),
                ),
              ),
              const SizedBox(height: 24),
              CleanField(
                label: 'First due date',
                child: _buildDateRow(
                  label: _dueDate == null
                      ? 'Select date'
                      : _formatDate(_dueDate!),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                    }
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              CleanField(
                label: 'Status',
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  dropdownColor: Colors.white,
                  iconEnabledColor: AppTheme.inkBlack.withValues(alpha: 0.6),
                  decoration: const InputDecoration(),
                  style: const TextStyle(
                    color: AppTheme.inkBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (v) =>
                      setState(() => _status = v ?? 'pending'),
                ),
              ),
              const SizedBox(height: 24),
              CleanField(
                label: 'Due date (optional)',
                child: _buildDateRow(
                  label: _dueDate == null
                      ? 'Select date'
                      : _formatDate(_dueDate!),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              CleanField(
                label: 'Note (optional)',
                child: TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppTheme.inkBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Add a note...',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: AppTheme.inkBlack.withValues(alpha: 0.55)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.inkBlack.withValues(
                  alpha: label == 'Select date' ? 0.4 : 1.0,
                ),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 18,
                color: AppTheme.inkBlack.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}