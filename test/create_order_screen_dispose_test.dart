import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/orders/models/order_model.dart';
import 'package:pos_app/features/salesman/views/create_order_screen.dart';

void main() {
  testWidgets(
    'CreateOrderScreen can dispose without using ref after disposal',
    (tester) async {
      final order = OrderModel(
        id: 83,
        orderNumber: 'ORD-83',
        sharedKey: 'shared-83',
        version: 2,
        customerId: 1,
        salesmanId: 1,
        warehouseId: 1,
        subtotal: 0,
        discountAmount: 0,
        discountPercent: 0,
        totalAmount: 0,
        totalProfit: 0,
        status: OrderModel.statusDraft,
        createdAt: DateTime.now().toIso8601String(),
        items: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: CreateOrderScreen(existingOrder: order)),
        ),
      );

      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    },
  );
}
