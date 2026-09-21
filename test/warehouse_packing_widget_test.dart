import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/features/warehouse/views/orders_to_pack_screen.dart';
import 'package:pos_app/features/warehouse/views/stock_list_screen.dart';
import 'package:pos_app/features/warehouse/views/warehouse_dashboard_screen.dart';
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
        minStockLevel: 0,
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

  testWidgets('OrdersToPackScreen shows error state and handles retry', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersToPackProvider.overrideWith((ref) => throw Exception('پەیوەندی بە سێرڤەرەوە پچڕا.')),
        ],
        child: const MaterialApp(
          home: OrdersToPackScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('کێشەیەک ڕوویدا لە بارکردنی پسوڵەکان'), findsOneWidget);
    expect(find.text('پەیوەندی بە سێرڤەرەوە پچڕا.'), findsOneWidget);
    expect(find.text('دووبارە هەوڵبدەرەوە'), findsOneWidget);
  });

  testWidgets('WarehouseDashboardScreen renders dynamic statistics and orders from warehouseDashboardProvider', (WidgetTester tester) async {
    final mockData = WarehouseDashboardData(
      warehouseId: 10,
      warehouseName: 'کۆگای هەولێر',
      pendingPackingCount: 7,
      readyTodayCount: 19,
      lowStockCount: 3,
      recentOrders: [
        WarehouseOrderModel(
          id: 55,
          orderNumber: 'ORD-9988',
          status: 'PACKING',
          createdAt: '2026-09-21T08:00:00Z',
          customerName: 'مارکێتی ژیان',
          items: [
            WarehouseOrderItemModel(
              id: 1,
              productId: 10,
              productName: 'ڕۆنی زەیتوون',
              quantity: 4,
              isPacked: true,
            ),
          ],
        ),
      ],
      lowStockItems: [
        WarehouseStockModel(
          id: 88,
          warehouseId: 10,
          warehouseName: 'کۆگای هەولێر',
          productId: 202,
          productName: 'برنجی کوردی',
          barcode: '99887766',
          quantity: 2,
          reservedQuantity: 0,
          minStockLevel: 10,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          warehouseDashboardProvider.overrideWith((ref) => mockData),
        ],
        child: const MaterialApp(
          home: WarehouseDashboardScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify dynamic warehouse name
    expect(find.text('کۆگای هەولێر'), findsOneWidget);

    // Verify dynamic KPI counts
    expect(find.text('7'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Verify recent order details
    expect(find.text('پسوڵەی #ORD-9988'), findsOneWidget);
    expect(find.text('مارکێتی ژیان'), findsOneWidget);
    expect(find.text('لە پاکەتکردندایە'), findsOneWidget);

    // Verify low stock item details
    expect(find.text('برنجی کوردی'), findsOneWidget);
    expect(find.text('مەوجوود: 2'), findsOneWidget);
    expect(find.text('ئاستی کەمینە: 10'), findsOneWidget);
  });

  testWidgets('WarehouseDashboardScreen displays error state with retry on failure', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          warehouseDashboardProvider.overrideWith((ref) => throw Exception('هەڵە لە پەیوەندی سێرڤەر')),
        ],
        child: const MaterialApp(
          home: WarehouseDashboardScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('کێشەیەک ڕوویدا لە بارکردنی ئامارەکانی کۆگا'), findsOneWidget);
    expect(find.text('هەڵە لە پەیوەندی سێرڤەر'), findsOneWidget);
    expect(find.text('دووبارە هەوڵبدەرەوە'), findsOneWidget);
  });
}

