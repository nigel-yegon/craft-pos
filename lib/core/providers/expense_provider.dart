import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ExpenseProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  final _uuid = const Uuid();

  ExpenseProvider(this.db, this.businessId);

  // ═══ One-off expenses ═══
  Stream<List<Expense>> get expensesStream =>
      (db.select(db.expenses)
        ..where((e) => e.businessId.equals(businessId))
        ..orderBy([(e) => drift.OrderingTerm.desc(e.createdAt)]))
          .watch();

  Future<void> addExpense({
    required String name,
    required int amountMinor,
    required String category,
    String status = 'pending',
    DateTime? dueDate,
    String? note,
  }) async {
    await db.into(db.expenses).insert(
      ExpensesCompanion.insert(
        id: _uuid.v4(),
        businessId: businessId,
        name: name.trim(),
        amountMinor: drift.Value(amountMinor),
        category: drift.Value(category),
        status: drift.Value(status),
        dueDate: drift.Value(dueDate),
        note: drift.Value(note),
      ),
    );
    notifyListeners();
  }

  /// Record a partial (or full) payment against an expense.
  /// Adds [amountMinor] to the paid amount, caps it at the total,
  /// and updates the status based on the resulting balance.
  Future<void> recordPayment({
    required String expenseId,
    required int amountMinor,
  }) async {
    final expense = await (db.select(db.expenses)
      ..where((e) => e.id.equals(expenseId)))
        .getSingleOrNull();
    if (expense == null) return;

    final newPaid = (expense.paidAmountMinor + amountMinor)
        .clamp(0, expense.amountMinor);
    final isFullyPaid = newPaid >= expense.amountMinor;
    final newStatus = isFullyPaid ? 'paid' : 'partial';

    await (db.update(db.expenses)..where((e) => e.id.equals(expenseId)))
        .write(
      ExpensesCompanion(
        paidAmountMinor: drift.Value(newPaid),
        status: drift.Value(newStatus),
        paidAt: isFullyPaid
            ? drift.Value(DateTime.now())
            : const drift.Value.absent(),
      ),
    );
    notifyListeners();
  }

  Future<void> markPaid(String id) async {
    final expense = await (db.select(db.expenses)
      ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (expense == null) return;

    await (db.update(db.expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        paidAmountMinor: drift.Value(expense.amountMinor),
        status: const drift.Value('paid'),
        paidAt: drift.Value(DateTime.now()),
      ),
    );
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    await (db.delete(db.expenses)..where((e) => e.id.equals(id))).go();
    notifyListeners();
  }

  // ═══ Recurring expenses ═══
  Stream<List<RecurringExpense>> get recurringStream =>
      (db.select(db.recurringExpenses)
        ..where((r) => r.businessId.equals(businessId))
        ..orderBy([(r) => drift.OrderingTerm.desc(r.createdAt)]))
          .watch();

  Future<void> addRecurring({
    required String name,
    required int amountMinor,
    required String category,
    required String period,
    DateTime? nextDueDate,
  }) async {
    await db.into(db.recurringExpenses).insert(
      RecurringExpensesCompanion.insert(
        id: _uuid.v4(),
        businessId: businessId,
        name: name.trim(),
        amountMinor: drift.Value(amountMinor),
        category: drift.Value(category),
        period: drift.Value(period),
        nextDueDate: drift.Value(nextDueDate),
      ),
    );
    notifyListeners();
  }

  Future<void> deleteRecurring(String id) async {
    await (db.delete(db.recurringExpenses)..where((r) => r.id.equals(id))).go();
    notifyListeners();
  }

  Future<void> toggleRecurringActive(String id, bool isActive) async {
    await (db.update(db.recurringExpenses)..where((r) => r.id.equals(id)))
        .write(
      RecurringExpensesCompanion(isActive: drift.Value(isActive)),
    );
    notifyListeners();
  }

  /// Materialize due recurring expenses into real expense rows.
  Future<void> generateDueRecurringExpenses() async {
    final now = DateTime.now();
    final recurring = await (db.select(db.recurringExpenses)
      ..where((r) => r.businessId.equals(businessId))
      ..where((r) => r.isActive.equals(true)))
        .get();

    for (final r in recurring) {
      final dueDate = r.nextDueDate ?? now;
      if (dueDate.isAfter(now)) continue;

      // Create the pending expense row
      await addExpense(
        name: '${r.name} (recurring)',
        amountMinor: r.amountMinor,
        category: r.category,
        status: 'pending',
        dueDate: dueDate,
      );

      // Compute the next due date
      DateTime next;
      switch (r.period) {
        case 'daily':
          next = dueDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = dueDate.add(const Duration(days: 7));
          break;
        case 'yearly':
          next = DateTime(dueDate.year + 1, dueDate.month, dueDate.day);
          break;
        case 'monthly':
        default:
          next = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
          break;
      }

      await (db.update(db.recurringExpenses)..where((x) => x.id.equals(r.id)))
          .write(
        RecurringExpensesCompanion(
          lastChargedAt: drift.Value(now),
          nextDueDate: drift.Value(next),
        ),
      );
    }
  }

  // ═══ Aggregates for Reports ═══
  Future<Map<String, int>> getExpenseSummary(
      DateTime start, DateTime end) async {
    final paidQuery = db.customSelect(
      '''
      SELECT COALESCE(SUM(paid_amount_minor), 0) AS total
      FROM expenses
      WHERE business_id = ?
      AND created_at >= ? AND created_at < ?
      ''',
      variables: [
        drift.Variable.withString(businessId),
        drift.Variable.withDateTime(start),
        drift.Variable.withDateTime(end),
      ],
      readsFrom: {db.expenses},
    );
    final paidRow = await paidQuery.getSingleOrNull();
    final paid = paidRow?.read<int?>('total') ?? 0;

    final pendingQuery = db.customSelect(
      '''
      SELECT COALESCE(SUM(amount_minor - paid_amount_minor), 0) AS total
      FROM expenses
      WHERE business_id = ? AND status != 'paid'
      AND created_at >= ? AND created_at < ?
      ''',
      variables: [
        drift.Variable.withString(businessId),
        drift.Variable.withDateTime(start),
        drift.Variable.withDateTime(end),
      ],
      readsFrom: {db.expenses},
    );
    final pendingRow = await pendingQuery.getSingleOrNull();
    final pending = pendingRow?.read<int?>('total') ?? 0;

    return {'paid': paid, 'pending': pending};
  }
}