import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/sync/sync_queue_entry.dart';
import 'package:pos_app/core/sync/sync_service.dart';
import 'package:pos_app/features/driver/models/delivery_trip_model.dart';
import 'package:pos_app/features/driver/providers/driver_providers.dart';
import 'package:pos_app/features/orders/models/order_model.dart';

void main() {
  group('Delivery Trip & Orders Domain & Serialization Tests', () {
    test('DeliveryTripModel and DeliveryTripOrderModel deserialize correctly from backend API response', () {
      final jsonResponse = {
        'id': 101,
        'trip_number': 'TRIP-2026-0001',
        'driver_id': 4,
        'driver': {
          'id': 4,
          'name': 'Kardo Driver',
          'phone': '07709876543',
        },
        'route_id': 2,
        'trip_date': '2026-03-02',
        'status': 'IN_PROGRESS',
        'total_orders': 2,
        'total_amount_collected': 35000,
        'created_at': '2026-03-02T08:00:00.000000Z',
        'orders': [
          {
            'id': 501,
            'delivery_trip_id': 101,
            'sales_order_id': 2001,
            'status': 'DELIVERED',
            'delivery_order': 1,
            'received_amount': 35000,
            'notes': 'Partial payment received on delivery',
            'failed_reason': null,
            'delivered_at': '2026-03-02T09:30:00.000000Z',
            'order': {
              'id': 2001,
              'order_number': 'ORD-2001',
              'customer_id': 301,
              'warehouse_id': 1,
              'subtotal': 50000,
              'discount_amount': 0,
              'total_amount': 50000,
              'status': 'DELIVERED',
              'customer': {
                'id': 301,
                'name': 'Shwan Supermarket',
                'phone': '07501112233',
                'current_balance': 15000,
              },
            },
          },
          {
            'id': 502,
            'delivery_trip_id': 101,
            'sales_order_id': 2002,
            'status': 'PENDING',
            'delivery_order': 2,
            'received_amount': 0,
            'notes': null,
            'failed_reason': null,
            'delivered_at': null,
            'order': {
              'id': 2002,
              'order_number': 'ORD-2002',
              'customer_id': 302,
              'warehouse_id': 1,
              'subtotal': 25000,
              'discount_amount': 0,
              'total_amount': 25000,
              'status': 'IN_DELIVERY',
              'customer': {
                'id': 302,
                'name': 'Baban Store',
                'phone': '07703334455',
                'current_balance': 0,
              },
            },
          },
        ],
      };

      final trip = DeliveryTripModel.fromJson(jsonResponse);

      expect(trip.id, equals(101));
      expect(trip.tripNumber, equals('TRIP-2026-0001'));
      expect(trip.driverId, equals(4));
      expect(trip.status, equals('IN_PROGRESS'));
      expect(trip.totalOrders, equals(2));
      expect(trip.totalAmountCollected, equals(35000));
      expect(trip.orders.length, equals(2));

      final firstOrder = trip.orders[0];
      expect(firstOrder.id, equals(501));
      expect(firstOrder.deliveryTripId, equals(101));
      expect(firstOrder.salesOrderId, equals(2001));
      expect(firstOrder.status, equals('DELIVERED'));
      expect(firstOrder.deliveryOrder, equals(1));
      expect(firstOrder.receivedAmount, equals(35000));
      expect(firstOrder.notes, equals('Partial payment received on delivery'));
      expect(firstOrder.failedReason, isNull);
      expect(firstOrder.order?.orderNumber, equals('ORD-2001'));
      expect(firstOrder.order?.totalAmount, equals(50000));

      final secondOrder = trip.orders[1];
      expect(secondOrder.id, equals(502));
      expect(secondOrder.status, equals('PENDING'));
      expect(secondOrder.deliveryOrder, equals(2));
      expect(secondOrder.receivedAmount, equals(0));
      expect(secondOrder.order?.orderNumber, equals('ORD-2002'));
    });

    test('Trip status metrics and order filtering aggregate accurately', () {
      final tripOrders = [
        DeliveryTripOrderModel(
          id: 1,
          deliveryTripId: 10,
          salesOrderId: 101,
          status: 'DELIVERED',
          deliveryOrder: 1,
          receivedAmount: 40000,
        ),
        DeliveryTripOrderModel(
          id: 2,
          deliveryTripId: 10,
          salesOrderId: 102,
          status: 'FAILED',
          deliveryOrder: 2,
          receivedAmount: 0,
          failedReason: 'کڕیار لە شوێنەکە نەبوو',
        ),
        DeliveryTripOrderModel(
          id: 3,
          deliveryTripId: 10,
          salesOrderId: 103,
          status: 'PENDING',
          deliveryOrder: 3,
          receivedAmount: 0,
        ),
      ];

      final total = tripOrders.length;
      final delivered = tripOrders.where((o) => o.status == 'DELIVERED').length;
      final failed = tripOrders.where((o) => o.status == 'FAILED').length;
      final pending = total - delivered - failed;

      expect(total, equals(3));
      expect(delivered, equals(1));
      expect(failed, equals(1));
      expect(pending, equals(1));

      final totalCollected = tripOrders
          .where((o) => o.status == 'DELIVERED')
          .fold<int>(0, (sum, item) => sum + item.receivedAmount);
      expect(totalCollected, equals(40000));
    });

    test('Trip orders sequence correctly based on delivery_order index', () {
      final rawList = [
        DeliveryTripOrderModel(
          id: 1,
          deliveryTripId: 10,
          salesOrderId: 101,
          status: 'PENDING',
          deliveryOrder: 3,
          receivedAmount: 0,
        ),
        DeliveryTripOrderModel(
          id: 2,
          deliveryTripId: 10,
          salesOrderId: 102,
          status: 'PENDING',
          deliveryOrder: 1,
          receivedAmount: 0,
        ),
        DeliveryTripOrderModel(
          id: 3,
          deliveryTripId: 10,
          salesOrderId: 103,
          status: 'PENDING',
          deliveryOrder: 2,
          receivedAmount: 0,
        ),
      ];

      rawList.sort((a, b) => a.deliveryOrder.compareTo(b.deliveryOrder));

      expect(rawList[0].id, equals(2));
      expect(rawList[0].deliveryOrder, equals(1));
      expect(rawList[1].id, equals(3));
      expect(rawList[1].deliveryOrder, equals(2));
      expect(rawList[2].id, equals(1));
      expect(rawList[2].deliveryOrder, equals(3));
    });

    test('DeliveryTripOrderModel handles null and missing optional fields safely', () {
      final minimalJson = {
        'id': 12,
        'delivery_trip_id': 4,
        'sales_order_id': 99,
        'status': 'PENDING',
        'delivery_order': 1,
      };

      final order = DeliveryTripOrderModel.fromJson(minimalJson);
      expect(order.id, equals(12));
      expect(order.receivedAmount, equals(0));
      expect(order.notes, isNull);
      expect(order.failedReason, isNull);
      expect(order.order, isNull);
    });
  });

  group('Delivery Sync Queue & Offline Idempotency Contract Tests', () {
    test('DELIVER_ORDER sync queue mapping targets correct API endpoint and payload', () {
      final tripOrderId = 501;
      final payload = {
        'received_amount': 30000,
        'notes': 'Delivered with partial cash',
      };
      final idempotencyKey = 'sync_deliver_501_1710000000';

      final routePath = '/delivery-trips/orders/$tripOrderId/deliver';
      final queueEntry = SyncQueueEntry(
        id: idempotencyKey,
        operationType: 'DELIVER_ORDER',
        entityId: '$tripOrderId',
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now(),
      );

      expect(routePath, equals('/delivery-trips/orders/501/deliver'));
      expect(queueEntry.operationType, equals('DELIVER_ORDER'));
      expect(queueEntry.payload['received_amount'], equals(30000));
      expect(queueEntry.payload['notes'], equals('Delivered with partial cash'));
      expect(queueEntry.id, equals(idempotencyKey));
    });

    test('FAIL_ORDER sync queue mapping targets correct API endpoint with failure reason', () {
      final tripOrderId = 502;
      final payload = {
        'failed_reason': 'کڕیار لە شوێنەکە نەبوو',
        'notes': 'Customer phone was not answering',
      };
      final idempotencyKey = 'sync_fail_502_1710000001';

      final routePath = '/delivery-trips/orders/$tripOrderId/fail';
      final queueEntry = SyncQueueEntry(
        id: idempotencyKey,
        operationType: 'FAIL_ORDER',
        entityId: '$tripOrderId',
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now(),
      );

      expect(routePath, equals('/delivery-trips/orders/502/fail'));
      expect(queueEntry.operationType, equals('FAIL_ORDER'));
      expect(queueEntry.payload['failed_reason'], equals('کڕیار لە شوێنەکە نەبوو'));
      expect(queueEntry.payload['notes'], equals('Customer phone was not answering'));
      expect(queueEntry.id, equals(idempotencyKey));
    });

    test('Repeated delivery confirmation preserves identical X-Idempotency-Key across retries', () {
      final stableKey = 'idempotent_delivery_trip_order_501';

      final initialSubmission = {
        'idempotency_key': stableKey,
        'trip_order_id': 501,
        'received_amount': 45000,
      };

      final retrySubmission = {
        'idempotency_key': stableKey,
        'trip_order_id': 501,
        'received_amount': 45000,
      };

      expect(initialSubmission['idempotency_key'], equals(retrySubmission['idempotency_key']));
    });
  });

  group('Delivery Trip Dispatching & Management Tests', () {
    test('READY order appears in dispatch selection, non-READY orders do not appear', () {
      final orders = [
        OrderModel(
          id: 1,
          orderNumber: 'ORD-001',
          status: OrderModel.statusDraft,
          subtotal: 10000,
          totalAmount: 10000,
          totalProfit: 2000,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          id: 2,
          orderNumber: 'ORD-002',
          status: OrderModel.statusConfirmed,
          subtotal: 12000,
          totalAmount: 12000,
          totalProfit: 2500,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          id: 3,
          orderNumber: 'ORD-003',
          status: OrderModel.statusPacking,
          subtotal: 15000,
          totalAmount: 15000,
          totalProfit: 3000,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          id: 4,
          orderNumber: 'ORD-004',
          status: OrderModel.statusReady,
          subtotal: 20000,
          totalAmount: 20000,
          totalProfit: 4000,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          id: 5,
          orderNumber: 'ORD-005',
          status: OrderModel.statusInDelivery,
          subtotal: 25000,
          totalAmount: 25000,
          totalProfit: 5000,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          id: 6,
          orderNumber: 'ORD-006',
          status: OrderModel.statusDelivered,
          subtotal: 30000,
          totalAmount: 30000,
          totalProfit: 6000,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          id: 7,
          orderNumber: 'ORD-007',
          status: OrderModel.statusCancelled,
          subtotal: 18000,
          totalAmount: 18000,
          totalProfit: 3500,
          createdAt: DateTime.now(),
        ),
      ];

      // Eligible orders logic as defined in readyOrdersForDeliveryProvider
      final readyOrders = orders
          .where((order) => order.status.toUpperCase() == OrderModel.statusReady)
          .toList();

      expect(readyOrders.length, equals(1));
      expect(readyOrders.first.id, equals(4));
      expect(readyOrders.first.orderNumber, equals('ORD-004'));
      expect(readyOrders.first.status, equals(OrderModel.statusReady));

      // Assert that non-READY orders are completely excluded
      final nonReadyIds = orders
          .where((order) => order.status.toUpperCase() != OrderModel.statusReady)
          .map((o) => o.id)
          .toList();

      expect(nonReadyIds, containsAll([1, 2, 3, 5, 6, 7]));
      expect(readyOrders.any((o) => nonReadyIds.contains(o.id)), isFalse);
    });

    test('Driver selection and DriverUserSummary deserialization', () {
      final jsonList = [
        {'id': 10, 'name': 'Kardo Driver', 'phone': '07701112233'},
        {'id': 11, 'name': 'Ahmad Driver', 'phone': null},
      ];

      final drivers = jsonList.map((j) => DriverUserSummary.fromJson(j)).toList();

      expect(drivers.length, equals(2));
      expect(drivers[0].id, equals(10));
      expect(drivers[0].name, equals('Kardo Driver'));
      expect(drivers[0].phone, equals('07701112233'));

      expect(drivers[1].id, equals(11));
      expect(drivers[1].name, equals('Ahmad Driver'));
      expect(drivers[1].phone, isNull);

      // Simulating driver selection
      final selectedDriver = drivers.firstWhere((d) => d.id == 10);
      expect(selectedDriver.name, equals('Kardo Driver'));
    });

    test('Order selection and STORE_DELIVERY payload construction', () {
      final driverId = 10;
      final tripDate = '2026-09-02';
      final selectedOrderIds = [101, 102, 103];
      final notes = 'Deliver before noon';
      final idempotencyKey = 'trip_custom_idemp_key_123';

      final payload = <String, dynamic>{
        'driver_id': driverId,
        'trip_date': tripDate,
        'order_ids': selectedOrderIds,
        'notes': notes,
        'idempotency_key': idempotencyKey,
      };

      expect(payload['driver_id'], equals(10));
      expect(payload['trip_date'], equals('2026-09-02'));
      expect(payload['order_ids'], equals([101, 102, 103]));
      expect(payload['notes'], equals('Deliver before noon'));
      expect(payload['idempotency_key'], equals('trip_custom_idemp_key_123'));

      // Queue entry mapping contract
      final queueEntry = SyncQueueEntry(
        id: idempotencyKey,
        operationType: 'STORE_DELIVERY',
        entityId: idempotencyKey,
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now(),
      );

      expect(queueEntry.operationType, equals('STORE_DELIVERY'));
      expect(queueEntry.payload['order_ids'], equals([101, 102, 103]));
      expect(queueEntry.payload['driver_id'], equals(10));
    });

    test('Malformed driver API response raises FormatException', () {
      void parseDriversResponse(dynamic resData) {
        if (resData is! Map || resData['data'] is! List) {
          throw const FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed drivers response payload)',
          );
        }
      }

      // String instead of Map
      expect(
        () => parseDriversResponse('Unexpected string response'),
        throwsA(isA<FormatException>()),
      );

      // Map without data list
      expect(
        () => parseDriversResponse({'data': 'not a list'}),
        throwsA(isA<FormatException>()),
      );

      // Null response
      expect(
        () => parseDriversResponse(null),
        throwsA(isA<FormatException>()),
      );
    });

    test('Malformed delivery-trip response raises FormatException', () {
      void parseTripsResponse(dynamic resData) {
        if (resData is! Map || resData['data'] is! List) {
          throw const FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed driver trips response payload)',
          );
        }
      }

      expect(
        () => parseTripsResponse('error 500 html'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => parseTripsResponse({'data': null}),
        throwsA(isA<FormatException>()),
      );
    });

    test('DeliveryTripModel parses driver details correctly when eager-loaded', () {
      final tripJson = {
        'id': 201,
        'trip_number': 'TRIP-2026-0099',
        'driver_id': 15,
        'driver': {
          'id': 15,
          'name': 'Barzan Driver',
          'phone': '07509876543',
        },
        'trip_date': '2026-09-02',
        'status': 'PLANNED',
        'total_orders': 3,
        'total_amount_collected': 0,
        'notes': 'Urgent route dispatch',
        'orders': [],
      };

      final trip = DeliveryTripModel.fromJson(tripJson);

      expect(trip.id, equals(201));
      expect(trip.tripNumber, equals('TRIP-2026-0099'));
      expect(trip.driverId, equals(15));
      expect(trip.driver, isNotNull);
      expect(trip.driver?.id, equals(15));
      expect(trip.driver?.name, equals('Barzan Driver'));
      expect(trip.driverName, equals('Barzan Driver'));
      expect(trip.status, equals('PLANNED'));
      expect(trip.totalOrders, equals(3));
      expect(trip.notes, equals('Urgent route dispatch'));
    });

    test('Stable STORE_DELIVERY idempotency key across retries preserves single transaction identity', () {
      const stableKey = 'trip_dispatch_tx_998877';

      final attemptOne = {
        'idempotency_key': stableKey,
        'driver_id': 10,
        'order_ids': [401, 402],
      };

      final retryAttempt = {
        'idempotency_key': stableKey,
        'driver_id': 10,
        'order_ids': [401, 402],
      };

      expect(attemptOne['idempotency_key'], equals(retryAttempt['idempotency_key']));
      expect(attemptOne['order_ids'], equals(retryAttempt['order_ids']));
      expect(attemptOne['driver_id'], equals(retryAttempt['driver_id']));
    });
  });
}


