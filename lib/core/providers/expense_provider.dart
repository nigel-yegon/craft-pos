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

  Future<void> updateExpense({
    required String id,
    required String name,
    required int amountMinor,
    required String category,
    required String status,
    DateTime? dueDate,
    String? note,
  }) async {
    await (db.update(db.expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        name: drift.Value(name.trim()),
        amountMinor: drift.Value(amountMinor),
        category: drift.Value(category),
        status: drift.Value(status),
        dueDate: drift.Value(dueDate),
        note: drift.Value(note),
        paidAt: status == 'paid'
            ? drift.Value(DateTime.now())
            : const drift.Value.absent(),
      ),
    );
    notifyListeners();
  }

  Future<void> markPaid(String id) async {
    await (db.update(db.expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
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
  }) async {
    await db.into(db.recurringExpenses).insert(
      RecurringExpensesCompanion.insert(
        id: _uuid.v4(),
        businessId: businessId,
        name: name.trim(),
        amountMinor: drift.Value(amountMinor),
        category: drift.Value(category),
        period: drift.Value(period),
      ),
    );
    notifyListeners();
  }

  Future<void> deleteRecurring(String id) async {
    await (db.delete(db.recurringExpenses)..where((r) => r.id.equals(id))).go();
    notifyListeners();
  }

  Future<void> toggleRecurringActive(String id, bool isActive) async {
    await (db.update(db.recurringExpenses)..where((r) => r.id.equals(id))).write(
      RecurringExpensesCompanion(isActive: drift.Value(isActive)),
    );
    notifyListeners();
  }

  /// Materialize any due recurring expenses into real expenses.
  /// Call this from Settings when the user opens the page.
  Future<void> generateDueRecurringExpenses() async {
    final now = DateTime.now();
    final recurring = await (db.select(db.recurringExpenses)
      ..where((r) => r.businessId.equals(businessId))
      ..where((r) => r.isActive.equals(true)))
        .get();

    for (final r in recurring) {
      bool due = false;
      if (r.lastChargedAt == null) {
        due = true;
      } else {
        final last = r.lastChargedAt!;
        switch (r.period) {
          case 'daily':
            due = now.difference(last).inDays >= 1;
            break;
          case 'weekly':
            due = now.difference(last).inDays >= 7;
            break;
          case 'monthly':
            due = now.month != last.month || now.year != last.year;
            break;
          case 'yearly':
            due = now.year != last.year;
            break;
        }
      }
      if (due) {
        await addExpense(
          name: '${r.name} (recurring)',
          amountMinor: r.amountMinor,
          category: r.category,
          status: 'pending',
          dueDate: now,
        );
        await (db.update(db.recurringExpenses)..where((x) => x.id.equals(r.id)))
            .write(RecurringExpensesCompanion(
          lastChargedAt: drift.Value(now),
        ));
      }
    }
  }

  // ═══ Aggregates for Reports ═══
  Future<Map<String, int>> getExpenseSummary(
      DateTime start, DateTime end) async {
    final paidQuery = db.customSelect(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS total
      FROM expenses
      WHERE business_id = ? AND status = 'paid'
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
      SELECT COALESCE(SUM(amount_minor), 0) AS total
      FROM expenses
      WHERE business_id = ? AND status = 'pending'
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