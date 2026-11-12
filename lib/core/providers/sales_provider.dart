import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class SalesProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  SalesProvider(this.db, this.businessId);

  Future<void> completeSale({
    required List<CartItem> cart,
    required int totalAmountMinor,
    required String paymentMethod,
  }) async {
    final saleId = const Uuid().v4();

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
            id: const Uuid().v4(),
            saleId: saleId,
            productId: item.product.id,
            quantityMilli: item.quantityMilli,
            unitPriceMinor: item.product.sellingPriceMinor,
            costPriceMinor: drift.Value(item.product.costPriceMinor),
            lineTotalMinor: item.quantityMilli * item.product.sellingPriceMinor,
          ),
        );

        await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
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
}

class CartItem {
  final Product product;
  int quantityMilli;

  CartItem({required this.product, this.quantityMilli = 1000});
}