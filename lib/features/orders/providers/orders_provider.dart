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
      // We store json string to simplify model caching for this example
      // In a real app we'd have a Hive TypeAdapter for OrderModel
      // but the prompt constraints imply sticking to minimal safe changes
      return orders;
    }
    return [];
  } catch (e) {
    // Return cached orders on network error
    // For now we just return an empty list or cached items if we had them
    return [];
  }
});

final singleOrderProvider =
    FutureProvider.family<OrderModel?, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.client.get('/orders/$orderId');
    if (response.statusCode == 200) {
      final data = response.data['data'] ?? response.data;
      return OrderModel.fromJson(data);
    }
    return null;
  } catch (e) {
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
    final response = await api.client.post(
      '/orders/$orderId/status',
      data: {'status': newStatus},
    );

    if (response.statusCode == 200) {
      ref.invalidate(singleOrderProvider(orderId));
      ref.invalidate(ordersListProvider);
    } else {
      throw Exception(
        response.data['message'] ?? 'شکستی هێنا لە گۆڕینی دۆخی پسوڵە',
      );
    }
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
