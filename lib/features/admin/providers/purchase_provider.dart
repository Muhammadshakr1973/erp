import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../models/purchase_requirement_model.dart';
import '../models/purchase_order_model.dart';

final purchaseRequirementsProvider =
    FutureProvider<List<PurchaseRequirementModel>>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      try {
        final response = await apiClient.client.get('/purchase-requirements');
        final List<dynamic> data = response.data['data'] ?? [];
        return data
            .map((json) => PurchaseRequirementModel.fromJson(json))
            .toList();
      } catch (e) {
        throw Exception(apiClient.parseError(e));
      }
    });


final purchaseRequirementsGroupProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.client.get('/purchase-requirements/group');
    return response.data['data'] ?? [];
  } catch (e) {
    throw Exception(apiClient.parseError(e));
  }
});

final purchaseOrdersProvider = FutureProvider<List<PurchaseOrderModel>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.client.get('/purchase-orders');
    final List<dynamic> data = response.data['data'] ?? [];
    return data.map((json) => PurchaseOrderModel.fromJson(json)).toList();
  } catch (e) {
    throw Exception(apiClient.parseError(e));
  }
});

final purchaseActionsProvider = Provider<PurchaseActions>((ref) {
  return PurchaseActions(ref);
});

class PurchaseActions {
  final Ref _ref;

  PurchaseActions(this._ref);

  Future<void> convertRequirementsToPO({
    required List<int> requirementIds,
    String? notes,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.client.post(
        '/purchase-requirements/convert',
        data: {'requirement_ids': requirementIds, 'notes': notes},
      );
      // Invalidate the lists to trigger a refresh
      _ref.invalidate(purchaseRequirementsProvider);
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> receivePurchaseOrder(int orderId, {List<Map<String, dynamic>>? items}) async {
    final apiClient = _ref.read(apiClientProvider);
    final syncService = _ref.read(syncServiceProvider);
    try {
      final payload = <String, dynamic>{};
      if (items != null && items.isNotEmpty) {
        payload['items'] = items;
      }
      await syncService.enqueueOperation(
        entityId: orderId.toString(),
        operationType: 'PURCHASE_RECEIVE',
        payload: payload,
      );
      await syncService.syncPendingOperations();
      // Invalidate purchase orders provider to refresh list
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> cancelPurchaseOrder(int orderId) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.client.post('/purchase-orders/$orderId/cancel');
      // Invalidate both lists
      _ref.invalidate(purchaseOrdersProvider);
      _ref.invalidate(purchaseRequirementsProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }
}
