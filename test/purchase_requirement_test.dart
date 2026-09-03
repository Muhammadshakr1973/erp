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
  });
}
