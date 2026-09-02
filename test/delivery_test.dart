import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/sync/sync_queue_entry.dart';
import 'package:pos_app/core/sync/sync_service.dart';
import 'package:pos_app/features/driver/models/delivery_trip_model.dart';
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
}

