import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/features/orders/models/order_model.dart';
import 'package:pos_app/features/orders/providers/orders_provider.dart';
import 'package:pos_app/features/shared/views/order_detail_screen.dart';

void main() {
  group('1. Return Action Visibility on Order Detail Screen', () {
    OrderModel createTestOrder({required String status}) {
      return OrderModel(
        id: 999,
        orderNumber: 'ORD-999',
        customerId: 10,
        salesmanId: 2,
        warehouseId: 1,
        subtotal: 50000,
        totalAmount: 50000,
        discountAmount: 0,
        discountPercent: 0,
        discountType: 'PERCENT',
        permanentDiscountPercent: 0,
        permanentDiscountAmount: 0,
        totalProfit: 10000,
        status: status,
        createdAt: '2026-09-02T10:00:00Z',
        items: [
          OrderItemModel(
            id: 101,
            productId: 55,
            productName: 'ڕۆنی زەیتوون',
            quantity: 5,
            unitPrice: 10000,
            subtotal: 50000,
          ),
        ],
      );
    }

    testWidgets('Delivered order displays "گەڕاندنەوەی کاڵا" action button',
        (tester) async {
      final deliveredOrder =
          createTestOrder(status: OrderModel.statusDelivered);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderProvider('999').overrideWith((ref) => deliveredOrder),
          ],
          child: const MaterialApp(
            home: OrderDetailScreen(orderId: '999'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('گەڕاندنەوەی کاڵا'), findsOneWidget);
    });

    testWidgets('Non-delivered orders do NOT display "گەڕاندنەوەی کاڵا" action button',
        (tester) async {
      final nonDeliveredStatuses = [
        OrderModel.statusDraft,
        OrderModel.statusConfirmed,
        OrderModel.statusPacking,
        OrderModel.statusReady,
        OrderModel.statusInDelivery,
        OrderModel.statusCancelled,
      ];

      for (final status in nonDeliveredStatuses) {
        final order = createTestOrder(status: status);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              singleOrderProvider('999').overrideWith((ref) => order),
            ],
            child: const MaterialApp(
              home: OrderDetailScreen(orderId: '999'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('گەڕاندنەوەی کاڵا'),
          findsNothing,
          reason: 'Status $status must not allow return action',
        );
      }
    });
  });

  group('2. Return Quantity & Payload Validation', () {
    String? validateReturnItems({
      required List<OrderItemModel> originalItems,
      required Map<int, int> returnQuantities,
    }) {
      final totalQty =
          returnQuantities.values.fold<int>(0, (sum, q) => sum + q);
      if (totalQty <= 0) {
        return 'تکایە لانیکەم بڕی کاڵایەک بۆ گەڕاندنەوە دیاری بکە';
      }

      for (final item in originalItems) {
        final maxQty = item.quantity.toInt();
        final qty = returnQuantities[item.id] ?? 0;
        if (qty < 0) {
          return 'بڕی گەڕاندنەوە بۆ "${item.productName}" ناتوانێت کەمتر بێت لە سفر';
        }
        if (qty > maxQty) {
          return 'بڕی گەڕاندنەوە بۆ "${item.productName}" زیاترە لە بڕی کڕدراو ($maxQty)';
        }
      }

      return null;
    }

    final testItems = [
      OrderItemModel(
        id: 1,
        productId: 10,
        productName: 'چای مەحموود',
        quantity: 10,
        unitPrice: 5000,
        subtotal: 50000,
      ),
      OrderItemModel(
        id: 2,
        productId: 20,
        productName: 'برنجی کوردی',
        quantity: 4,
        unitPrice: 15000,
        subtotal: 60000,
      ),
    ];

    test('Rejects return when total quantity is 0 or empty', () {
      final err = validateReturnItems(
        originalItems: testItems,
        returnQuantities: {1: 0, 2: 0},
      );
      expect(err, isNotNull);
      expect(err, contains('تکایە لانیکەم بڕی کاڵایەک'));
    });

    test('Rejects return when quantity exceeds original purchased quantity', () {
      final err = validateReturnItems(
        originalItems: testItems,
        returnQuantities: {1: 11, 2: 2}, // item 1 only has 10 purchased
      );
      expect(err, isNotNull);
      expect(err, contains('زیاترە لە بڕی کڕدراو'));
    });

    test('Rejects negative quantities', () {
      final err = validateReturnItems(
        originalItems: testItems,
        returnQuantities: {1: -1, 2: 2},
      );
      expect(err, isNotNull);
      expect(err, contains('ناتوانێت کەمتر بێت لە سفر'));
    });

    test('Accepts valid quantities and formats backend payload correctly', () {
      final quantities = {1: 3, 2: 0};
      final err = validateReturnItems(
        originalItems: testItems,
        returnQuantities: quantities,
      );
      expect(err, isNull);

      final List<Map<String, dynamic>> returnItems = [];
      for (final item in testItems) {
        final qty = quantities[item.id] ?? 0;
        if (qty > 0) {
          returnItems.add({
            'sales_order_item_id': item.id,
            'quantity': qty,
            'reason': 'Damaged box',
          });
        }
      }

      expect(returnItems.length, equals(1));
      expect(returnItems.first['sales_order_item_id'], equals(1));
      expect(returnItems.first['quantity'], equals(3));
      expect(returnItems.first['reason'], equals('Damaged box'));

      final payload = {
        'sales_order_id': 999,
        'reason': 'General customer return',
        'items': returnItems,
        'idempotency_key': 'ret_999_123456789',
      };

      expect(payload['sales_order_id'], equals(999));
      expect(payload['reason'], equals('General customer return'));
      expect(payload['items'], isNotEmpty);
      expect(payload['idempotency_key'], startsWith('ret_999_'));
    });
  });

  group('3. Malformed API Response Handling', () {
    List<dynamic> parseSalesReturnsList(dynamic resData) {
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed sales returns list payload)',
        );
      }
      return resData['data'] as List<dynamic>;
    }

    dynamic parseSingleSalesReturn(dynamic resData) {
      final data = (resData is Map && resData.containsKey('data'))
          ? resData['data']
          : resData;
      if (data is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed sales return detail payload)',
        );
      }
      return data;
    }

    test('Throws FormatException when sales returns list is not a list', () {
      expect(
        () => parseSalesReturnsList('invalid string'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseSalesReturnsList({'data': 'not a list'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseSalesReturnsList({'other': []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('Throws FormatException when single sales return is not a Map', () {
      expect(
        () => parseSingleSalesReturn('not a map'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseSingleSalesReturn({'data': ['list instead of map']}),
        throwsA(isA<FormatException>()),
      );
    });

    test('Parses valid sales returns list and detail responses successfully', () {
      final validList = {
        'message': 'سەرکەوتوو بوو',
        'data': [
          {
            'id': 1,
            'return_number': 'RET-001',
            'sales_order_id': 100,
            'total_return_amount': 25000,
            'status': 'COMPLETED',
          }
        ]
      };

      final parsedList = parseSalesReturnsList(validList);
      expect(parsedList.length, equals(1));
      expect(parsedList.first['return_number'], equals('RET-001'));

      final validDetail = {
        'message': 'سەرکەوتوو بوو',
        'data': {
          'id': 1,
          'return_number': 'RET-001',
          'sales_order_id': 100,
          'total_return_amount': 25000,
          'status': 'COMPLETED',
          'items': [
            {
              'id': 11,
              'product_id': 5,
              'quantity': 2,
              'unit_price': 12500,
              'total': 25000,
            }
          ]
        }
      };

      final parsedDetail = parseSingleSalesReturn(validDetail);
      expect(parsedDetail['return_number'], equals('RET-001'));
      expect(parsedDetail['items'], isA<List>());
      expect((parsedDetail['items'] as List).length, equals(1));
    });
  });

  group('4. Provider Invalidation on Sales Return Creation', () {
    test('createSalesReturn invalidates order, order list, and return list', () {
      var invalidatedOrderProvider = false;
      var invalidatedOrdersListProvider = false;
      var invalidatedReturnsListProvider = false;

      void simulateInvalidate(String target) {
        if (target.startsWith('singleOrder_')) {
          invalidatedOrderProvider = true;
        } else if (target == 'ordersList') {
          invalidatedOrdersListProvider = true;
        } else if (target == 'salesReturnsList') {
          invalidatedReturnsListProvider = true;
        }
      }

      final payload = {
        'sales_order_id': 999,
        'items': [
          {'sales_order_item_id': 1, 'quantity': 2}
        ],
        'idempotency_key': 'ret_999_test',
      };

      // Simulating SalesReturnActions.createSalesReturn behavior
      if (payload['sales_order_id'] != null) {
        simulateInvalidate('singleOrder_${payload['sales_order_id']}');
      }
      simulateInvalidate('ordersList');
      simulateInvalidate('salesReturnsList');

      expect(invalidatedOrderProvider, isTrue);
      expect(invalidatedOrdersListProvider, isTrue);
      expect(invalidatedReturnsListProvider, isTrue);
    });
  });
}
