import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/warehouse_order_model.dart';

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
        data: {
          'order_item_id': itemId,
          'packed': packed,
        },
      );
      ref.invalidate(ordersToPackProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> markOrderReady(int orderId) async {
    try {
      await api.client.post(
        '/warehouse/mark-ready',
        data: {
          'order_id': orderId,
        },
      );
      ref.invalidate(ordersToPackProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
