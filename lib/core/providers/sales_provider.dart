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
  Future<void> completeSale({
    required List<CartItem> cart,
    required int totalAmountMinor,
    required String paymentMethod,
  }) async {
    final saleId = _uuid.v4();

    await db.transaction(() async {
      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          businessId: businessId,
          totalAmountMinor: drift.Value(totalAmountMinor),
          paymentMethod: drift.Value(paymentMethod),
        ),
      );

      for (final item in cart) {
        await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: saleId,
            productId: item.product.id,
            quantityMilli: item.quantityMilli,
            unitPriceMinor: item.product.sellingPriceMinor,
            costPriceMinor: drift.Value(item.product.costPriceMinor),
            lineTotalMinor:
            (item.quantityMilli * item.product.sellingPriceMinor) ~/ 1000,
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