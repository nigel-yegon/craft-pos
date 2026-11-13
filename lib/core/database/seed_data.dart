import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'app_database.dart';

class SeedData {
  static const _uuid = Uuid();

  static String _hashPin(String pin) {
    final bytes = utf8.encode('craft_pos_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  /// Seeds a demo business with realistic data.
  /// Safe to call every launch — it does nothing if a business already exists.
  static Future<void> seedIfEmpty(AppDatabase db) async {
    final existingBusinesses = await db.select(db.businesses).get();
    if (existingBusinesses.isNotEmpty) {
      return; // already seeded (or user's real business)
    }

    const businessId = 'demo-business-id';
    final now = DateTime.now();

    // ─── Business ───
    await db.into(db.businesses).insert(
      BusinessesCompanion.insert(
        id: businessId,
        name: 'Craft Demo Shop',
        phone: const Value('0712 345 678'),
        email: const Value('hello@craftdemo.co.ke'),
        address: const Value('Moi Avenue, Nairobi'),
        currency: const Value('KES'),
      ),
    );

    // ─── User (owner, PIN 1234) ───
    await db.into(db.users).insert(
      UsersCompanion.insert(
        id: _uuid.v4(),
        businessId: businessId,
        name: 'Demo Owner',
        pinHash: _hashPin('1234'),
        role: const Value('owner'),
      ),
    );

    // ─── Categories ───
    final catBeverages = _uuid.v4();
    final catSnacks = _uuid.v4();
    final catHousehold = _uuid.v4();
    final catStationery = _uuid.v4();

    await db.batch((batch) {
      batch.insertAll(db.categories, [
        CategoriesCompanion.insert(
          id: catBeverages,
          businessId: businessId,
          name: 'Beverages',
          description: const Value('Sodas, water, juices'),
        ),
        CategoriesCompanion.insert(
          id: catSnacks,
          businessId: businessId,
          name: 'Snacks',
          description: const Value('Crisps, biscuits, sweets'),
        ),
        CategoriesCompanion.insert(
          id: catHousehold,
          businessId: businessId,
          name: 'Household',
          description: const Value('Soap, detergent, cleaning'),
        ),
        CategoriesCompanion.insert(
          id: catStationery,
          businessId: businessId,
          name: 'Stationery',
          description: const Value('Pens, notebooks, paper'),
        ),
      ]);
    });

    // ─── Products ───
    final prodCoke = _uuid.v4();
    final prodWater = _uuid.v4();
    final prodJuice = _uuid.v4();
    final prodCrisps = _uuid.v4();
    final prodBiscuits = _uuid.v4();
    final prodSoap = _uuid.v4();
    final prodDetergent = _uuid.v4();
    final prodPens = _uuid.v4();
    final prodNotebook = _uuid.v4();

    await db.batch((batch) {
      batch.insertAll(db.products, [
        ProductsCompanion.insert(
          id: prodCoke,
          businessId: businessId,
          categoryId: Value(catBeverages),
          name: 'Coca-Cola 500ml',
          sku: const Value('BEV-COKE-500'),
          barcode: const Value('5449000000996'),
          costPriceMinor: const Value(5000),
          sellingPriceMinor: const Value(7000),
          reorderLevelMilli: const Value(10000),
        ),
        ProductsCompanion.insert(
          id: prodWater,
          businessId: businessId,
          categoryId: Value(catBeverages),
          name: 'Dasani Water 500ml',
          sku: const Value('BEV-WATER-500'),
          costPriceMinor: const Value(3000),
          sellingPriceMinor: const Value(5000),
          reorderLevelMilli: const Value(15000),
        ),
        ProductsCompanion.insert(
          id: prodJuice,
          businessId: businessId,
          categoryId: Value(catBeverages),
          name: 'Minute Maid Orange 300ml',
          sku: const Value('BEV-JUICE-300'),
          costPriceMinor: const Value(6000),
          sellingPriceMinor: const Value(9000),
          reorderLevelMilli: const Value(8000),
        ),
        ProductsCompanion.insert(
          id: prodCrisps,
          businessId: businessId,
          categoryId: Value(catSnacks),
          name: 'Tropical Heat Crisps',
          sku: const Value('SNK-CRISPS-TH'),
          costPriceMinor: const Value(4000),
          sellingPriceMinor: const Value(6000),
          reorderLevelMilli: const Value(10000),
        ),
        ProductsCompanion.insert(
          id: prodBiscuits,
          businessId: businessId,
          categoryId: Value(catSnacks),
          name: 'Manji Digestive Biscuits',
          sku: const Value('SNK-MANJI-200'),
          costPriceMinor: const Value(3500),
          sellingPriceMinor: const Value(5500),
          reorderLevelMilli: const Value(8000),
        ),
        ProductsCompanion.insert(
          id: prodSoap,
          businessId: businessId,
          categoryId: Value(catHousehold),
          name: 'Sunlight Bar Soap 175g',
          sku: const Value('HSE-SOAP-175'),
          costPriceMinor: const Value(8000),
          sellingPriceMinor: const Value(12000),
          reorderLevelMilli: const Value(5000),
        ),
        ProductsCompanion.insert(
          id: prodDetergent,
          businessId: businessId,
          categoryId: Value(catHousehold),
          name: 'Omo Detergent 1kg',
          sku: const Value('HSE-OMO-1KG'),
          costPriceMinor: const Value(18000),
          sellingPriceMinor: const Value(24000),
          reorderLevelMilli: const Value(5000),
        ),
        ProductsCompanion.insert(
          id: prodPens,
          businessId: businessId,
          categoryId: Value(catStationery),
          name: 'Bic Ballpoint Pens (Pack of 10)',
          sku: const Value('STA-BIC-10'),
          costPriceMinor: const Value(5000),
          sellingPriceMinor: const Value(8000),
          reorderLevelMilli: const Value(3000),
        ),
        ProductsCompanion.insert(
          id: prodNotebook,
          businessId: businessId,
          categoryId: Value(catStationery),
          name: 'A4 Exercise Book 200pg',
          sku: const Value('STA-NB-A4'),
          costPriceMinor: const Value(4500),
          sellingPriceMinor: const Value(7000),
          reorderLevelMilli: const Value(5000),
        ),
      ]);
    });

    // ─── Opening stock movements ───
    final openingStock = <String, int>{
      prodCoke: 24000,
      prodWater: 36000,
      prodJuice: 12000,
      prodCrisps: 20000,
      prodBiscuits: 15000,
      prodSoap: 8000,
      prodDetergent: 6000,
      prodPens: 5000,
      prodNotebook: 10000,
    };

    final productCosts = <String, int>{
      prodCoke: 5000,
      prodWater: 3000,
      prodJuice: 6000,
      prodCrisps: 4000,
      prodBiscuits: 3500,
      prodSoap: 8000,
      prodDetergent: 18000,
      prodPens: 5000,
      prodNotebook: 4500,
    };

    await db.batch((batch) {
      openingStock.forEach((productId, qty) {
        batch.insert(
          db.stockMovements,
          StockMovementsCompanion.insert(
            id: _uuid.v4(),
            businessId: businessId,
            productId: productId,
            type: 'opening_stock',
            quantityMilli: qty,
            unitCostMinor: Value(productCosts[productId]),
          ),
        );
      });
    });

    // ─── Sample sales (last 7 days) ───
    final salesProducts = [
      (prodCoke, 7000, 5000),
      (prodWater, 5000, 3000),
      (prodJuice, 9000, 6000),
      (prodCrisps, 6000, 4000),
      (prodBiscuits, 5500, 3500),
      (prodSoap, 12000, 8000),
    ];

    final random = _SeededRandom(42);

    for (int daysAgo = 6; daysAgo >= 0; daysAgo--) {
      final saleDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysAgo));

      final salesCount = random.nextInt(3) + 2; // 2–4 sales per day

      for (int i = 0; i < salesCount; i++) {
        final saleId = _uuid.v4();
        final saleTime =
        saleDate.add(Duration(hours: 8 + random.nextInt(10)));

        final numItems = random.nextInt(3) + 1; // 1–3 line items
        final chosenProducts = <int>{};
        final items = <_SeedSaleItem>[];

        while (chosenProducts.length < numItems) {
          chosenProducts.add(random.nextInt(salesProducts.length));
        }

        int totalMinor = 0;
        for (final idx in chosenProducts) {
          final (productId, price, cost) = salesProducts[idx];
          final qty = (random.nextInt(3) + 1) * 1000; // 1–3 units
          final lineTotal = price * qty ~/ 1000;
          totalMinor += lineTotal;
          items.add(_SeedSaleItem(productId, qty, price, cost, lineTotal));
        }

        final method = random.nextBool() ? 'Cash' : 'M-Pesa';

        await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: saleId,
            businessId: businessId,
            totalAmountMinor: Value(totalMinor),
            paymentMethod: Value(method),
            createdAt: Value(saleTime),
          ),
        );

        for (final item in items) {
          await db.into(db.saleItems).insert(
            SaleItemsCompanion.insert(
              id: _uuid.v4(),
              saleId: saleId,
              productId: item.productId,
              quantityMilli: item.quantityMilli,
              unitPriceMinor: item.unitPrice,
              costPriceMinor: Value(item.costPrice),
              lineTotalMinor: item.lineTotal,
            ),
          );

          await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              id: _uuid.v4(),
              businessId: businessId,
              productId: item.productId,
              type: 'sale',
              quantityMilli: -item.quantityMilli,
              unitCostMinor: Value(item.costPrice),
              referenceId: Value(saleId),
              createdAt: Value(saleTime),
            ),
          );
        }
      }
    }

    // ─── Held orders (1 example) ───
    final heldId = _uuid.v4();
    final heldJson = jsonEncode([
      {'productId': prodCoke, 'quantityMilli': 2000},
      {'productId': prodCrisps, 'quantityMilli': 1000},
    ]);
    await db.into(db.heldOrders).insert(
      HeldOrdersCompanion.insert(
        id: heldId,
        businessId: businessId,
        cartJson: heldJson,
        totalAmountMinor: const Value(20000),
        note: const Value('Customer will pick up this evening'),
      ),
    );

    // ─── Expenses ───
    final expenseRent = _uuid.v4();
    final expenseSalary = _uuid.v4();
    final expenseUtility = _uuid.v4();
    final expenseSupplies = _uuid.v4();

    await db.batch((batch) {
      batch.insertAll(db.expenses, [
        ExpensesCompanion.insert(
          id: expenseRent,
          businessId: businessId,
          name: 'Shop rent — January',
          amountMinor: const Value(1500000),
          paidAmountMinor: const Value(1500000),
          category: const Value('rent'),
          status: const Value('paid'),
          dueDate: Value(now.subtract(const Duration(days: 20))),
          paidAt: Value(now.subtract(const Duration(days: 20))),
        ),
        ExpensesCompanion.insert(
          id: expenseSalary,
          businessId: businessId,
          name: 'Salary — Assistant',
          amountMinor: const Value(2000000),
          paidAmountMinor: const Value(1000000),
          category: const Value('salary'),
          status: const Value('partial'),
          dueDate: Value(now.add(const Duration(days: 5))),
        ),
        ExpensesCompanion.insert(
          id: expenseUtility,
          businessId: businessId,
          name: 'KPLC electricity',
          amountMinor: const Value(450000),
          category: const Value('utility'),
          status: const Value('pending'),
          dueDate: Value(now.add(const Duration(days: 10))),
        ),
        ExpensesCompanion.insert(
          id: expenseSupplies,
          businessId: businessId,
          name: 'Cleaning supplies',
          amountMinor: const Value(35000),
          paidAmountMinor: const Value(35000),
          category: const Value('supplies'),
          status: const Value('paid'),
          paidAt: Value(now.subtract(const Duration(days: 2))),
        ),
      ]);
    });

    // ─── Recurring expenses ───
    await db.into(db.recurringExpenses).insert(
      RecurringExpensesCompanion.insert(
        id: _uuid.v4(),
        businessId: businessId,
        name: 'Shop rent',
        amountMinor: const Value(1500000),
        category: const Value('rent'),
        period: const Value('monthly'),
        nextDueDate: Value(now.add(const Duration(days: 30))),
        lastChargedAt: Value(now.subtract(const Duration(days: 30))),
      ),
    );

    await db.into(db.recurringExpenses).insert(
      RecurringExpensesCompanion.insert(
        id: _uuid.v4(),
        businessId: businessId,
        name: 'Water bill',
        amountMinor: const Value(80000),
        category: const Value('utility'),
        period: const Value('monthly'),
        nextDueDate: Value(now.add(const Duration(days: 15))),
      ),
    );

    // ignore: avoid_print
    print('✅ Seed data inserted — PIN 1234 for demo owner.');
  }
}

class _SeedSaleItem {
  final String productId;
  final int quantityMilli;
  final int unitPrice;
  final int costPrice;
  final int lineTotal;

  _SeedSaleItem(
      this.productId, this.quantityMilli, this.unitPrice, this.costPrice, this.lineTotal);
}

/// Deterministic random so the demo data is the same on every fresh install.
class _SeededRandom {
  int _seed;
  _SeededRandom(this._seed);

  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % max;
  }

  bool nextBool() => nextInt(2) == 1;
}