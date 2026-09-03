import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:pos_app/features/admin/models/purchase_order_model.dart';
import 'package:pos_app/features/admin/providers/purchase_provider.dart';
import 'package:pos_app/core/api_client.dart';
import 'package:pos_app/core/sync/sync_service.dart';
import 'package:pos_app/core/sync/sync_queue_entry.dart';

class MockInterceptor extends Interceptor {
  RequestOptions? lastRequest;
  bool shouldFail = false;
  int failStatusCode = 400;
  String failMessage = 'Error occurred';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    if (shouldFail) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: failStatusCode,
          data: {'message': failMessage},
        ),
        type: DioExceptionType.badResponse,
      ));
    } else {
      handler.resolve(Response(
        requestOptions: options,
        data: {
          'message': 'Success',
          'data': {'id': 1}
        },
        statusCode: 200,
      ));
    }
  }
}

class FakeSyncService implements SyncService {
  final List<Map<String, dynamic>> enqueued = [];
  bool syncCalled = false;

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Box<SyncQueueEntry> get box => throw UnimplementedError();

  @override
  Ref get ref => throw UnimplementedError();

  @override
  void dispose() {}

  @override
  Future<void> enqueueOperation({
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    enqueued.add({
      'entityId': entityId,
      'operationType': operationType,
      'payload': payload,
    });
  }

  @override
  Future<void> syncPendingOperations() async {
    syncCalled = true;
  }
}

void main() {
  group('PurchaseOrderModel & PurchaseOrderItemModel Contract Parsing Tests', () {
    test('Verify model parses all backend fields correctly', () {
      final json = {
        'id': 100,
        'order_number': 'PO-2026-0001',
        'supplier_id': 5,
        'supplier': {'name': 'Nawzad Corp'},
        'warehouse_id': 2,
        'warehouse': {'name': 'Erbil Central'},
        'status': 'CONFIRMED',
        'total_amount': 250000,
        'notes': 'Urgent restock',
        'received_at': '2026-09-03T12:00:00Z',
        'items': [
          {
            'id': 401,
            'purchase_order_id': 100,
            'product_id': 15,
            'product': {'name': 'Pepsi 250ml'},
            'quantity': 100,
            'received_quantity': 30,
            'unit_cost': 1500,
            'total_cost': 150000,
          },
          {
            'id': 402,
            'purchase_order_id': 100,
            'product_id': 16,
            'product': {'name': 'Coca Cola 250ml'},
            'quantity': 50,
            'received_quantity': 50,
            'unit_cost': 2000,
            'total_cost': 100000,
          }
        ]
      };

      final order = PurchaseOrderModel.fromJson(json);

      expect(order.id, equals(100));
      expect(order.orderNumber, equals('PO-2026-0001'));
      expect(order.supplierId, equals(5));
      expect(order.supplierName, equals('Nawzad Corp'));
      expect(order.warehouseId, equals(2));
      expect(order.warehouseName, equals('Erbil Central'));
      expect(order.status, equals('CONFIRMED'));
      expect(order.totalAmount, equals(250000));
      expect(order.notes, equals('Urgent restock'));
      expect(order.receivedAt, equals(DateTime.parse('2026-09-03T12:00:00Z')));
      expect(order.itemsCount, equals(2));
      expect(order.items.length, equals(2));

      // Verify items
      final item1 = order.items[0];
      expect(item1.id, equals(401));
      expect(item1.purchaseOrderId, equals(100));
      expect(item1.productId, equals(15));
      expect(item1.productName, equals('Pepsi 250ml'));
      expect(item1.quantity, equals(100));
      expect(item1.receivedQuantity, equals(30));
      expect(item1.remainingQuantity, equals(70));
      expect(item1.unitCost, equals(1500));
      expect(item1.totalCost, equals(150000));

      final item2 = order.items[1];
      expect(item2.remainingQuantity, equals(0)); // fully received
    });

    test('Verify status values match backend constants', () {
      expect(PurchaseOrderModel.fromJson({'id': 1, 'status': 'DRAFT'}).status, equals('DRAFT'));
      expect(PurchaseOrderModel.fromJson({'id': 1, 'status': 'CONFIRMED'}).status, equals('CONFIRMED'));
      expect(PurchaseOrderModel.fromJson({'id': 1, 'status': 'RECEIVED'}).status, equals('RECEIVED'));
      expect(PurchaseOrderModel.fromJson({'id': 1, 'status': 'CANCELLED'}).status, equals('CANCELLED'));
    });
  });

  group('PurchaseProvider Operation Tests', () {
    late ProviderContainer container;
    late MockInterceptor mockInterceptor;
    late ApiClient apiClient;
    late FakeSyncService fakeSyncService;

    setUp(() {
      mockInterceptor = MockInterceptor();
      apiClient = ApiClient();
      apiClient.client.interceptors.clear();
      apiClient.client.interceptors.add(mockInterceptor);
      fakeSyncService = FakeSyncService();

      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          syncServiceProvider.overrideWithValue(fakeSyncService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('confirmPurchaseOrder sends post with stable default idempotency key', () async {
      final actions = container.read(purchaseActionsProvider);
      await actions.confirmPurchaseOrder(100);

      final req = mockInterceptor.lastRequest;
      expect(req, isNotNull);
      expect(req!.path, equals('/purchase-orders/100/confirm'));
      expect(req.headers['X-Idempotency-Key'], equals('confirm_po_100'));
    });

    test('confirmPurchaseOrder supports custom explicit idempotency key', () async {
      final actions = container.read(purchaseActionsProvider);
      await actions.confirmPurchaseOrder(100, idempotencyKey: 'explicit-key-123');

      final req = mockInterceptor.lastRequest;
      expect(req!.headers['X-Idempotency-Key'], equals('explicit-key-123'));
    });

    test('cancelPurchaseOrder sends post with stable default idempotency key', () async {
      final actions = container.read(purchaseActionsProvider);
      await actions.cancelPurchaseOrder(100);

      final req = mockInterceptor.lastRequest;
      expect(req, isNotNull);
      expect(req!.path, equals('/purchase-orders/100/cancel'));
      expect(req.headers['X-Idempotency-Key'], equals('cancel_po_100'));
    });

    test('cancelPurchaseOrder supports custom explicit idempotency key', () async {
      final actions = container.read(purchaseActionsProvider);
      await actions.cancelPurchaseOrder(100, idempotencyKey: 'explicit-cancel-abc');

      final req = mockInterceptor.lastRequest;
      expect(req!.headers['X-Idempotency-Key'], equals('explicit-cancel-abc'));
    });

    test('receivePurchaseOrder enqueues PURCHASE_RECEIVE full receive operation', () async {
      final actions = container.read(purchaseActionsProvider);
      await actions.receivePurchaseOrder(100);

      expect(fakeSyncService.enqueued.length, equals(1));
      final op = fakeSyncService.enqueued.first;
      expect(op['entityId'], equals('100'));
      expect(op['operationType'], equals('PURCHASE_RECEIVE'));
      expect(op['payload'], isEmpty);
      expect(fakeSyncService.syncCalled, isTrue);
    });

    test('receivePurchaseOrder enqueues PURCHASE_RECEIVE partial receive operation', () async {
      final actions = container.read(purchaseActionsProvider);
      final items = [
        {'item_id': 401, 'product_id': 15, 'quantity': 10}
      ];
      await actions.receivePurchaseOrder(100, items: items);

      expect(fakeSyncService.enqueued.length, equals(1));
      final op = fakeSyncService.enqueued.first;
      expect(op['entityId'], equals('100'));
      expect(op['operationType'], equals('PURCHASE_RECEIVE'));
      expect(op['payload']['items'], equals(items));
      expect(fakeSyncService.syncCalled, isTrue);
    });
  });
}
