import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../models/order_model.dart';

// Provide local orders box
final localOrdersBoxProvider = Provider<Box<String>>((ref) {
  return Hive.box<String>('local_orders');
});

final ordersListProvider = FutureProvider<List<OrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final localBox = ref.watch(localOrdersBoxProvider);

  try {
    final response = await api.client.get('/orders');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      final orders = data.map((json) => OrderModel.fromJson(json)).toList();

      // Update local cache
      // We clear the box first to ensure stale orders are removed, then put fresh entries
      await localBox.clear();
      for (var i = 0; i < data.length; i++) {
        final order = orders[i];
        final rawJson = data[i];
        if (rawJson is Map) {
          final Map<String, dynamic> castedJson = Map<String, dynamic>.from(rawJson);
          await localBox.put(order.id.toString(), jsonEncode(castedJson));
        }
      }
      return orders;
    }
    throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
  } catch (e) {
    // Return cached orders on network error
    final cachedOrders = <OrderModel>[];
    final corruptedKeys = <String>[];

    for (final key in localBox.keys) {
      final jsonStr = localBox.get(key);
      if (jsonStr != null) {
        try {
          final Map<String, dynamic> json = jsonDecode(jsonStr);
          cachedOrders.add(OrderModel.fromJson(json));
        } catch (_) {
          corruptedKeys.add(key.toString());
        }
      }
    }

    // Clean up corrupted keys if any
    for (final key in corruptedKeys) {
      await localBox.delete(key);
    }

    if (cachedOrders.isNotEmpty) {
      return cachedOrders;
    }

    // Throw specific exception if there is no network connection and no cached orders
    throw Exception('پەیوەندی هێڵ لەدەستدراوە و هیچ پسوڵەیەکی پاشەکەوتکراو نییە (No network connection and no cached orders)');
  }
});

final singleOrderProvider =
    FutureProvider.family<OrderModel?, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final localBox = ref.watch(localOrdersBoxProvider);

  try {
    final response = await api.client.get('/orders/$orderId');
    if (response.statusCode == 200) {
      final data = response.data['data'] ?? response.data;
      final order = OrderModel.fromJson(data);
      if (data is Map) {
        final Map<String, dynamic> castedJson = Map<String, dynamic>.from(data);
        await localBox.put(order.id.toString(), jsonEncode(castedJson));
      }
      return order;
    }
    return null;
  } catch (e) {
    final cachedStr = localBox.get(orderId);
    if (cachedStr != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(cachedStr);
        return OrderModel.fromJson(json);
      } catch (_) {
        // Safe fallback - don't crash
      }
    }
    return null;
  }
});

final customerOrdersProvider = FutureProvider.family<List<OrderModel>, int>((
  ref,
  customerId,
) async {
  final orders = await ref.watch(ordersListProvider.future);
  return orders.where((order) => order.customerId == customerId).toList();
});

final orderActionsProvider = Provider<OrderActions>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final api = ref.watch(apiClientProvider);
  return OrderActions(syncService, api, ref);
});

class OrderActions {
  final SyncService syncService;
  final ApiClient api;
  final Ref ref;

  OrderActions(this.syncService, this.api, this.ref);

  Future<void> createOrder(Map<String, dynamic> data) async {
    // Local UUID for entity tracking
    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';

    // Enqueue the offline operation
    await syncService.enqueueOperation(
      entityId: localId,
      operationType: 'CREATE_ORDER',
      payload: data,
    );

    // Optimistically update the UI by invalidating or updating local list
    ref.invalidate(ordersListProvider);
  }

  Future<void> updateOrder(int orderId, Map<String, dynamic> data) async {
    final entityId = orderId.toString();

    await syncService.enqueueOperation(
      entityId: entityId,
      operationType: 'UPDATE_ORDER',
      payload: data,
    );

    ref.invalidate(singleOrderProvider(entityId));
    ref.invalidate(ordersListProvider);
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await syncService.enqueueOperation(
      entityId: orderId,
      operationType: 'UPDATE_ORDER_STATUS',
      payload: {'status': newStatus},
    );

    ref.invalidate(singleOrderProvider(orderId));
    ref.invalidate(ordersListProvider);
  }
}

final salesReturnsListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/sales-returns');
    if (response.statusCode == 200) {
      return response.data['data'] ?? [];
    }
    return [];
  } catch (e) {
    return [];
  }
});

final singleSalesReturnProvider = FutureProvider.family<dynamic, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/sales-returns/$id');
    if (response.statusCode == 200) {
      return response.data['data'] ?? response.data;
    }
    return null;
  } catch (e) {
    return null;
  }
});

class SalesReturnActions {
  final SyncService syncService;
  final ApiClient api;
  final Ref ref;

  SalesReturnActions(this.syncService, this.api, this.ref);

  Future<void> createSalesReturn(Map<String, dynamic> data) async {
    final String returnEntityId = data['idempotency_key'] ??
        data['local_id'] ??
        'return_${DateTime.now().microsecondsSinceEpoch}';

    final payload = Map<String, dynamic>.from(data)
      ..['idempotency_key'] = returnEntityId;

    await syncService.enqueueOperation(
      entityId: returnEntityId,
      operationType: 'CREATE_SALES_RETURN',
      payload: payload,
    );

    ref.invalidate(salesReturnsListProvider);
  }
}

final salesReturnActionsProvider = Provider<SalesReturnActions>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final api = ref.watch(apiClientProvider);
  return SalesReturnActions(syncService, api, ref);
});
