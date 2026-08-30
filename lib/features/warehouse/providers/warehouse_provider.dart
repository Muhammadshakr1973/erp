import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/warehouse_order_model.dart';
import '../models/warehouse_stock_model.dart';

final ordersToPackProvider = FutureProvider<List<WarehouseOrderModel>>((
  ref,
) async {
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

final warehouseStocksProvider = FutureProvider<List<WarehouseStockModel>>((
  ref,
) async {
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
  return WarehouseActions(api, ref);
});

class WarehouseActions {
  final ApiClient api;
  final Ref ref;

  WarehouseActions(this.api, this.ref);

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
    required String type,
    String? notes,
  }) async {
    try {
      await api.client.post(
        '/warehouses/$warehouseId/stock/$productId/adjust',
        data: {'quantity_change': quantityChange, 'type': type, 'notes': notes},
      );
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
}
