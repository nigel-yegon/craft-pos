import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class SalesProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  final _uuid = const Uuid();

  SalesProvider(this.db, this.businessId);

  /// Completes a sale with the chosen payment method.
  ///
  /// [payments] describes how the total was paid. If empty, a single split
  /// is synthesized from [paymentMethod] so legacy call sites keep working.
  /// The sum of `payments.amountMinor` must equal [totalAmountMinor].
  Future<void> completeSale({
    required List<CartItem> cart,
    required int totalAmountMinor,
    required String paymentMethod,
    List<SalePaymentSplit> payments = const [],
  }) async {
    // Backwards-compatible: synthesize a single-component split when the
    // caller didn't supply one (cash-only / mpesa-only paths).
    final effectivePayments = payments.isNotEmpty
        ? payments
        : [SalePaymentSplit(paymentMethod, totalAmountMinor)];

    final paidSum =
    effectivePayments.fold<int>(0, (s, p) => s + p.amountMinor);
    if (paidSum != totalAmountMinor) {
      throw ArgumentError(
        'Payment split total ($paidSum minor) does not match '
            'sale total ($totalAmountMinor minor)',
      );
    }

    final saleId = _uuid.v4();

    await db.transaction(() async {
      // 1. Sale row
      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          businessId: businessId,
          totalAmountMinor: drift.Value(totalAmountMinor),
          paymentMethod: drift.Value(paymentMethod),
        ),
      );

      // 2. ⭐ Split-payment rows
      for (final split in effectivePayments) {
        await db.into(db.salePayments).insert(
          SalePaymentsCompanion.insert(
            id: _uuid.v4(),
            saleId: saleId,
            method: split.method,
            amountMinor: split.amountMinor,
            reference: drift.Value(split.reference),
          ),
        );
      }

      // 3. Sale items + stock movements (unchanged)
      for (final item in cart) {
        await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: saleId,
            productId: item.product.id,
            quantityMilli: item.quantityMilli,
            unitPriceMinor: item.product.sellingPriceMinor,
            costPriceMinor:
            drift.Value(item.product.costPriceMinor),
            lineTotalMinor:
            (item.quantityMilli * item.product.sellingPriceMinor) ~/
                1000,
          ),
        );

        await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: _uuid.v4(),
            businessId: businessId,
            productId: item.product.id,
            type: 'sale',
            quantityMilli: -item.quantityMilli,
            referenceId: drift.Value(saleId),
          ),
        );
      }
    });

    notifyListeners();
  }

  /// Holds a cart for later payment.
  Future<String> holdOrder({
    required List<CartItem> cart,
    required int totalAmountMinor,
    String? note,
  }) async {
    final id = _uuid.v4();
    final json = jsonEncode(cart.map((i) => {
      'productId': i.product.id,
      'quantityMilli': i.quantityMilli,
    }).toList());

    await db.into(db.heldOrders).insert(
      HeldOrdersCompanion.insert(
        id: id,
        businessId: businessId,
        cartJson: json,
        totalAmountMinor: drift.Value(totalAmountMinor),
        note: drift.Value(note),
      ),
    );
    notifyListeners();
    return id;
  }

  /// Reactive stream of held orders, newest first.
  Stream<List<HeldOrder>> get heldOrdersStream =>
      (db.select(db.heldOrders)
        ..where((h) => h.businessId.equals(businessId))
        ..orderBy([(h) => drift.OrderingTerm.desc(h.createdAt)]))
          .watch();

  /// Rehydrates a held order into a cart.
  Future<List<CartItem>> loadHeldOrder(HeldOrder order) async {
    final list = jsonDecode(order.cartJson) as List<dynamic>;
    final items = <CartItem>[];

    for (final entry in list) {
      final map = entry as Map<String, dynamic>;
      final productId = map['productId'] as String;
      final product = await (db.select(db.products)
        ..where((p) => p.id.equals(productId)))
          .getSingleOrNull();
      if (product == null) continue;

      items.add(CartItem(
        product: product,
        quantityMilli: map['quantityMilli'] as int,
      ));
    }
    return items;
  }

  /// Removes a held order (after resume or cancel).
  Future<void> deleteHeldOrder(String id) async {
    await (db.delete(db.heldOrders)..where((h) => h.id.equals(id))).go();
    notifyListeners();
  }
}

class CartItem {
  final Product product;
  int quantityMilli;

  CartItem({required this.product, this.quantityMilli = 1000});

  int get lineTotalMinor =>
      product.sellingPriceMinor * quantityMilli ~/ 1000;
}

/// ⭐ One component of a split payment.
///
/// `method` is the payment channel (`'cash'` or `'mpesa'`). `reference`
/// carries any channel-specific identifier (e.g. M-Pesa receipt number)
/// and is nullable.
class SalePaymentSplit {
  final String method;
  final int amountMinor;
  final String? reference;

  const SalePaymentSplit(
      this.method,
      this.amountMinor, {
        this.reference,
      });

  @override
  String toString() =>
      'SalePaymentSplit(method: $method, amountMinor: $amountMinor, '
          'reference: $reference)';
}