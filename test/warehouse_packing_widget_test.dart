import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/features/warehouse/views/orders_to_pack_screen.dart';
import 'package:pos_app/features/warehouse/views/stock_list_screen.dart';
import 'package:pos_app/features/warehouse/providers/warehouse_provider.dart';
import 'package:pos_app/features/warehouse/models/warehouse_order_model.dart';
import 'package:pos_app/features/warehouse/models/warehouse_stock_model.dart';


void main() {
  testWidgets('OrdersToPackScreen shows empty state when no orders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersToPackProvider.overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: OrdersToPackScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('هیچ پسوڵەیەک نییە بۆ پاکەتکردن'), findsOneWidget);
  });

  testWidgets('OrdersToPackScreen lists orders correctly', (WidgetTester tester) async {
    final mockOrders = [
      WarehouseOrderModel(
        id: 1,
        orderNumber: 'ORD-12345',
        status: 'CONFIRMED',
        createdAt: '2026-08-29T10:00:00Z',
        customerName: 'مارکێتی ئەحمەد',
        items: [
          WarehouseOrderItemModel(
            id: 10,
            productId: 101,
            productName: 'شامپۆ',
            quantity: 5,
            isPacked: false,
          )
        ],
      )
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersToPackProvider.overrideWith((ref) => mockOrders),
        ],
        child: const MaterialApp(
          home: OrdersToPackScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('پسوڵەی #ORD-12345'), findsOneWidget);
    expect(find.textContaining('مارکێتی ئەحمەد'), findsOneWidget);
  });

  testWidgets('StockListScreen displays stock items from warehouseStocksProvider', (WidgetTester tester) async {
    final mockStocks = [
      WarehouseStockModel(
        id: 1,
        warehouseId: 10,
        warehouseName: 'کۆگای سەرەکی',
        productId: 101,
        productName: 'شامپۆی برۆکس',
        barcode: '12345678',
        quantity: 15,
        reservedQuantity: 2,
      )
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          warehouseStocksProvider.overrideWith((ref) => mockStocks),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StockListScreen(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('شامپۆی برۆکس'), findsOneWidget);
    expect(find.textContaining('ستۆک: 15'), findsOneWidget);
    expect(find.textContaining('کۆگای سەرەکی • حجزکراو: 2'), findsOneWidget);
  });
}

