import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/features/admin/models/purchase_requirement_model.dart';
import 'package:pos_app/features/admin/providers/purchase_provider.dart';
import 'package:pos_app/core/api_client.dart';

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
          'data': {'id': 1, 'status': 'CONVERTED'}
        },
        statusCode: 200,
      ));
    }
  }
}

void main() {
  group('Purchase Requirement Model Parsing Tests', () {
    test('A. Full backend payload parsing works correctly with all fields', () {
      final json = {
        'id': 12,
        'product_id': 45,
        'product': {'name': 'Soft Drink'},
        'warehouse_id': 3,
        'warehouse': {'name': 'Slemani Warehouse'},
        'supplier_id': 7,
        'supplier': {'name': 'Nawzad Supplier'},
        'required_quantity': 150,
        'current_stock': 25,
        'suggested_quantity': 125,
        'is_urgent': true,
        'status': 'PENDING',
        'sales_order_id': 88,
        'purchase_order_id': 99,
        'creator': {'name': 'Karwan Admin'},
      };

      final req = PurchaseRequirementModel.fromJson(json);

      expect(req.id, equals(12));
      expect(req.productId, equals(45));
      expect(req.productName, equals('Soft Drink'));
      expect(req.warehouseId, equals(3));
      expect(req.warehouseName, equals('Slemani Warehouse'));
      expect(req.supplierId, equals(7));
      expect(req.supplierName, equals('Nawzad Supplier'));
      expect(req.requiredQuantity, equals(150));
      expect(req.currentStock, equals(25));
      expect(req.suggestedQuantity, equals(125));
      expect(req.isUrgent, isTrue);
      expect(req.status, equals('PENDING'));
      expect(req.salesOrderId, equals(88));
      expect(req.purchaseOrderId, equals(99));
      expect(req.createdByName, equals('Karwan Admin'));
    });

    test('B. Missing suggested_quantity defaults to 0 safely', () {
      final json = {
        'id': 12,
        'product_id': 45,
        'warehouse_id': 3,
        'required_quantity': 150,
        'current_stock': 25,
        'is_urgent': false,
        'status': 'OPEN',
      };

      final req = PurchaseRequirementModel.fromJson(json);
      expect(req.suggestedQuantity, equals(0));
    });

    test('C. Missing/null purchase_order_id remains null safely', () {
      final json = {
        'id': 12,
        'product_id': 45,
        'warehouse_id': 3,
        'required_quantity': 150,
        'current_stock': 25,
        'is_urgent': false,
        'status': 'OPEN',
        'purchase_order_id': null,
      };

      final req = PurchaseRequirementModel.fromJson(json);
      expect(req.purchaseOrderId, isNull);
    });

    test('D. Existing required_quantity, current_stock, and status parsing still works', () {
      final json = {
        'id': 15,
        'product_id': 46,
        'warehouse_id': 4,
        'required_quantity': 200,
        'current_stock': 15,
        'is_urgent': 1,
        'status': 'OPEN',
      };

      final req = PurchaseRequirementModel.fromJson(json);
      expect(req.requiredQuantity, equals(200));
      expect(req.currentStock, equals(15));
      expect(req.isUrgent, isTrue);
      expect(req.status, equals('OPEN'));
    });

    test('E. Malformed or unexpected payload does not silently fabricate invalid values', () {
      final json = <String, dynamic>{};
      
      // We expect it to parse safely fallback defaults
      final req = PurchaseRequirementModel.fromJson(json);
      expect(req.requiredQuantity, equals(0));
      expect(req.currentStock, equals(0));
      expect(req.suggestedQuantity, equals(0));
      expect(req.isUrgent, isFalse);
      expect(req.status, equals('OPEN'));
    });
  });

  group('PurchaseActions convertRequirementsToPO Idempotency and Payload Tests', () {
    late ProviderContainer container;
    late MockInterceptor mockInterceptor;
    late ApiClient apiClient;

    setUp(() {
      mockInterceptor = MockInterceptor();
      apiClient = ApiClient();
      // Inject mock interceptor into ApiClient's dio
      apiClient.client.interceptors.clear();
      apiClient.client.interceptors.add(mockInterceptor);

      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('4. convertRequirementsToPO sends the expected payload', () async {
      final actions = container.read(purchaseActionsProvider);
      final reqIds = [10, 20, 30];
      final notes = 'Standard restock requirements';

      await actions.convertRequirementsToPO(
        requirementIds: reqIds,
        notes: notes,
      );

      final lastRequest = mockInterceptor.lastRequest;
      expect(lastRequest, isNotNull);
      expect(lastRequest!.path, equals('/purchase-requirements/convert'));
      expect(lastRequest.data, isA<Map<String, dynamic>>());
      
      final data = lastRequest.data as Map<String, dynamic>;
      expect(data['requirement_ids'], equals(reqIds));
      expect(data['notes'], equals(notes));
    });

    test('5. convert operation includes stable, deterministic idempotency key and header', () async {
      final actions = container.read(purchaseActionsProvider);
      final reqIds = [30, 10, 20];
      final notes = 'Testing stable idempotency';

      // First call
      await actions.convertRequirementsToPO(
        requirementIds: reqIds,
        notes: notes,
      );

      final firstRequest = mockInterceptor.lastRequest;
      expect(firstRequest, isNotNull);
      final firstKey = firstRequest!.headers['X-Idempotency-Key'];
      expect(firstKey, isNotNull);
      expect(firstKey, isNotEmpty);

      // Second call (with same params) should produce the same deterministic key
      await actions.convertRequirementsToPO(
        requirementIds: reqIds,
        notes: notes,
      );

      final secondRequest = mockInterceptor.lastRequest;
      expect(secondRequest, isNotNull);
      final secondKey = secondRequest!.headers['X-Idempotency-Key'];
      expect(secondKey, equals(firstKey));

      // Call with different notes or IDs should produce a different key
      await actions.convertRequirementsToPO(
        requirementIds: reqIds,
        notes: 'Testing stable idempotency - different notes',
      );

      final thirdRequest = mockInterceptor.lastRequest;
      expect(thirdRequest, isNotNull);
      final thirdKey = thirdRequest!.headers['X-Idempotency-Key'];
      expect(thirdKey, isNot(equals(firstKey)));
    });

    test('5b. convert operation accepts explicit idempotencyKey and preserves it', () async {
      final actions = container.read(purchaseActionsProvider);
      final reqIds = [1, 2];
      const customKey = 'explicit-custom-key-9999';

      await actions.convertRequirementsToPO(
        requirementIds: reqIds,
        idempotencyKey: customKey,
      );

      final request = mockInterceptor.lastRequest;
      expect(request, isNotNull);
      expect(request!.headers['X-Idempotency-Key'], equals(customKey));
    });

    test('6. Existing purchase provider error handling remains intact', () async {
      mockInterceptor.shouldFail = true;
      mockInterceptor.failStatusCode = 422;
      mockInterceptor.failMessage = 'Validation error occurred';

      final actions = container.read(purchaseActionsProvider);

      expect(
        () => actions.convertRequirementsToPO(requirementIds: [1, 2]),
        throwsException,
      );
    });

    test('A. Same requirement set in different input orders produces the same canonical payload and same generated key', () async {
      final actions = container.read(purchaseActionsProvider);
      
      // Order 1
      await actions.convertRequirementsToPO(
        requirementIds: [30, 10, 20],
        notes: 'deterministic notes',
      );
      final req1 = mockInterceptor.lastRequest;
      expect(req1, isNotNull);
      final key1 = req1!.headers['X-Idempotency-Key'];
      final payload1 = req1.data['requirement_ids'] as List<int>;

      // Order 2
      await actions.convertRequirementsToPO(
        requirementIds: [20, 30, 10],
        notes: 'deterministic notes',
      );
      final req2 = mockInterceptor.lastRequest;
      expect(req2, isNotNull);
      final key2 = req2!.headers['X-Idempotency-Key'];
      final payload2 = req2.data['requirement_ids'] as List<int>;

      expect(key1, equals(key2));
      expect(payload1, equals([10, 20, 30]));
      expect(payload2, equals([10, 20, 30]));
    });

    test('B. Different requirement sets produce different keys', () async {
      final actions = container.read(purchaseActionsProvider);

      await actions.convertRequirementsToPO(
        requirementIds: [1, 2, 3],
        notes: 'some notes',
      );
      final key1 = mockInterceptor.lastRequest!.headers['X-Idempotency-Key'];

      await actions.convertRequirementsToPO(
        requirementIds: [1, 2, 4],
        notes: 'some notes',
      );
      final key2 = mockInterceptor.lastRequest!.headers['X-Idempotency-Key'];

      expect(key1, isNot(equals(key2)));
    });

    test('C. Different notes produce different keys', () async {
      final actions = container.read(purchaseActionsProvider);

      await actions.convertRequirementsToPO(
        requirementIds: [1, 2, 3],
        notes: 'note A',
      );
      final key1 = mockInterceptor.lastRequest!.headers['X-Idempotency-Key'];

      await actions.convertRequirementsToPO(
        requirementIds: [1, 2, 3],
        notes: 'note B',
      );
      final key2 = mockInterceptor.lastRequest!.headers['X-Idempotency-Key'];

      expect(key1, isNot(equals(key2)));
    });

    test('D. Explicit idempotency key is preserved exactly', () async {
      final actions = container.read(purchaseActionsProvider);
      const customKey = 'explicit-custom-key-9999';

      await actions.convertRequirementsToPO(
        requirementIds: [1, 2],
        idempotencyKey: customKey,
      );

      final key = mockInterceptor.lastRequest!.headers['X-Idempotency-Key'];
      expect(key, equals(customKey));
    });

    test('E. Request payload uses the same canonical sorted requirement ID list represented by the generated key', () async {
      final actions = container.read(purchaseActionsProvider);
      final inputIds = [5, 2, 9, 1];

      await actions.convertRequirementsToPO(
        requirementIds: inputIds,
        notes: 'payload check',
      );

      final req = mockInterceptor.lastRequest;
      expect(req, isNotNull);
      final sentPayload = req!.data['requirement_ids'] as List<int>;
      expect(sentPayload, equals([1, 2, 5, 9]));

      final generatedKey = req.headers['X-Idempotency-Key'] as String;
      expect(generatedKey, contains('1_2_5_9'));
    });

    test('F. Existing confirm/cancel idempotency behavior remains intact', () async {
      final actions = container.read(purchaseActionsProvider);

      // Confirm purchase order
      await actions.confirmPurchaseOrder(123);
      final confirmReq = mockInterceptor.lastRequest;
      expect(confirmReq, isNotNull);
      expect(confirmReq!.headers['X-Idempotency-Key'], equals('confirm_po_123'));

      // Confirm purchase order with explicit key
      await actions.confirmPurchaseOrder(123, idempotencyKey: 'custom_confirm');
      expect(mockInterceptor.lastRequest!.headers['X-Idempotency-Key'], equals('custom_confirm'));

      // Cancel purchase order
      await actions.cancelPurchaseOrder(456);
      final cancelReq = mockInterceptor.lastRequest;
      expect(cancelReq, isNotNull);
      expect(cancelReq!.headers['X-Idempotency-Key'], equals('cancel_po_456'));

      // Cancel purchase order with explicit key
      await actions.cancelPurchaseOrder(456, idempotencyKey: 'custom_cancel');
      expect(mockInterceptor.lastRequest!.headers['X-Idempotency-Key'], equals('custom_cancel'));
    });
  });
}
