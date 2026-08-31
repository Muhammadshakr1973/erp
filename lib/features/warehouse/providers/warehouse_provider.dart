import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../models/warehouse_order_model.dart';
import '../models/warehouse_stock_model.dart';

final ordersToPackProvider = FutureProvider<List<WarehouseOrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/warehouse/orders-to-pack');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => WarehouseOrderModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final warehouseStocksProvider = FutureProvider<List<WarehouseStockModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/warehouse/stock');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => WarehouseStockModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final warehouseActionsProvider = Provider<WarehouseActions>((ref) {
  final api = ref.watch(apiClientProvider);
  final syncService = ref.watch(syncServiceProvider);
  return WarehouseActions(api, syncService, ref);
});

class WarehouseActions {
  final ApiClient api;
  final SyncService syncService;
  final Ref ref;

  WarehouseActions(this.api, this.syncService, this.ref);

  Future<void> packItem(int itemId, bool packed) async {
    try {
      await api.client.post(
        '/warehouse/pack-item',
        data: {'order_item_id': itemId, 'packed': packed},
      );
      ref.invalidate(ordersToPackProvider);
      ref.invalidate(warehouseStocksProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> markOrderReady(int orderId) async {
    try {
      await api.client.post(
        '/warehouse/mark-ready',
        data: {'order_id': orderId},
      );
      ref.invalidate(ordersToPackProvider);
      ref.invalidate(warehouseStocksProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> adjustStock({
    required int warehouseId,
    required int productId,
    required int quantityChange,
    String type = 'ADJUSTMENT',
    String? notes,
  }) async {
    try {
      await syncService.enqueueOperation(
        entityId: warehouseId.toString(),
        operationType: 'STOCK_ADJUSTMENT',
        payload: {
          'warehouse_id': warehouseId,
          'product_id': productId,
          'quantity_change': quantityChange,
          'type': type,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      await syncService.syncPendingOperations();
      ref.invalidate(warehouseStocksProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> reconcileStock({
    required int warehouseId,
    required int productId,
  }) async {
    try {
      await api.client.get(
        '/warehouses/$warehouseId/stock/$productId/reconcile',
      );
      ref.invalidate(warehouseStocksProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<List<dynamic>> getTransactions({int? warehouseId, int? productId, String? dateFrom}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (warehouseId != null) queryParams['warehouse_id'] = warehouseId;
      if (productId != null) queryParams['product_id'] = productId;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      
      final response = await api.client.get('/warehouse/transactions', queryParameters: queryParams);
      if (response.statusCode == 200) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
