import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../../shared/providers/customer_provider.dart';
import '../../products/providers/products_provider.dart';
import '../models/order_model.dart';

// Provide local orders box
final localOrdersBoxProvider = Provider<Box<String>>((ref) {
  return Hive.box<String>('local_orders');
});

final ordersListProvider = FutureProvider<List<OrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final localBox = ref.watch(localOrdersBoxProvider);
  final syncBox = ref.watch(syncQueueBoxProvider);

  // Self-healing sweep: remove synced/stale local orders that have no pending CREATE_ORDER ops
  final localKeys = localBox.keys.where((k) => k.toString().startsWith('local_')).toList();
  for (final key in localKeys) {
    final hasPendingOp = syncBox.values.any((entry) =>
        entry.entityId == key &&
        entry.operationType == 'CREATE_ORDER' &&
        (entry.status == 'PENDING' || entry.status == 'FAILED' || entry.status == 'SYNCING'));
    if (!hasPendingOp) {
      await localBox.delete(key);
    }
  }

  try {
    final response = await api.client.get('/orders');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      final onlineOrders = data.map((json) => OrderModel.fromJson(json)).toList();

      // Update local cache: clear server-cached entries (keys not starting with 'local_')
      final keysToDelete = localBox.keys.where((k) => !k.toString().startsWith('local_')).toList();
      for (final key in keysToDelete) {
        await localBox.delete(key);
      }

      // Write new online orders
      for (var i = 0; i < data.length; i++) {
        final order = onlineOrders[i];
        final rawJson = data[i];
        if (rawJson is Map) {
          final Map<String, dynamic> castedJson = Map<String, dynamic>.from(rawJson);
          await localBox.put(order.id.toString(), jsonEncode(castedJson));
        }
      }

      // Read remaining local optimistic orders
      final remainingLocalOrders = <OrderModel>[];
      final freshLocalKeys = localBox.keys.where((k) => k.toString().startsWith('local_')).toList();
      for (final key in freshLocalKeys) {
        final jsonStr = localBox.get(key);
        if (jsonStr != null) {
          try {
            final Map<String, dynamic> json = jsonDecode(jsonStr);
            final localOrder = OrderModel.fromJson(json);
            
            // Duplicate prevention: check if online orders contain this local order (by sharedKey)
            final alreadySynced = onlineOrders.any((o) =>
                o.sharedKey != null &&
                localOrder.sharedKey != null &&
                o.sharedKey == localOrder.sharedKey);
            
            if (alreadySynced) {
              await localBox.delete(key); // Synced order found, clean up local key
            } else {
              remainingLocalOrders.add(localOrder);
            }
          } catch (_) {}
        }
      }

      // Merge and return
      return [...onlineOrders, ...remainingLocalOrders];
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

  Map<String, dynamic> _buildOptimisticOrderJson({
    required String idStr,
    required int intId,
    required Map<String, dynamic> data,
    required Ref ref,
    required String status,
    String? existingOrderNumber,
  }) {
    final customers = ref.read(customerListProvider).value ?? [];
    final customerId = data['customer_id'] ?? 0;
    final customer = customers.firstWhere((c) => c.id == customerId, orElse: () => null);

    final products = ref.read(productsListProvider).value ?? [];
    final itemsData = data['items'] ?? [];
    
    double totalCost = 0.0;
    double subtotal = 0.0;
    final List<Map<String, dynamic>> resolvedItems = [];

    for (final item in itemsData) {
      final int prodId = item['product_id'] ?? 0;
      final double qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      
      final prod = products.firstWhere((p) => p.id == prodId, orElse: () => null);
      String productName = 'کاڵا';
      double unitPrice = 0.0;
      double costPrice = 0.0;

      if (prod != null) {
        productName = prod.name;
        costPrice = prod.costPrice;
        final priceType = customer?.priceType;
        if (priceType == 'N1') {
          unitPrice = prod.priceN1;
        } else if (priceType == 'N3') {
          unitPrice = prod.priceN3;
        } else {
          unitPrice = prod.priceN2;
        }
      }

      final itemSubtotal = qty * unitPrice;
      subtotal += itemSubtotal;
      totalCost += qty * costPrice;

      resolvedItems.add({
        'id': 0,
        'sales_order_id': intId,
        'product_id': prodId,
        'product_name': productName,
        'quantity': qty,
        'unit_price': unitPrice,
        'subtotal': itemSubtotal,
        'is_packed': false,
        'product': prod != null ? {'name': prod.name} : null,
      });
    }

    final discountType = data['discount_type'] ?? 'PERCENT';
    double discountPercent = 0.0;
    double discountAmount = 0.0;

    if (discountType == 'PERCENT') {
      discountPercent = double.tryParse(data['discount_percent']?.toString() ?? '0') ?? 0.0;
      discountAmount = subtotal * (discountPercent / 100);
    } else {
      discountAmount = double.tryParse(data['discount_amount']?.toString() ?? '0') ?? 0.0;
      discountPercent = subtotal > 0 ? (discountAmount / subtotal) * 100 : 0.0;
    }

    final totalAmount = subtotal - discountAmount;
    final totalProfit = (subtotal - totalCost) - discountAmount;

    final orderNumber = existingOrderNumber ?? "LOCAL_${idStr.replaceAll('local_', '').substring(0, min(6, idStr.replaceAll('local_', '').length))}";

    return {
      'id': intId,
      'order_number': orderNumber,
      'shared_key': data['shared_key'],
      'version': data['version'] ?? 1,
      'customer_id': customerId,
      'salesman_id': data['salesman_id'] ?? 0,
      'warehouse_id': data['warehouse_id'],
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'discount_percent': discountPercent,
      'discount_type': discountType,
      'total_amount': totalAmount,
      'total_profit': totalProfit,
      'status': status,
      'notes': data['notes'],
      'created_at': DateTime.now().toIso8601String(),
      'customer': customer != null ? {'id': customer.id, 'name': customer.name} : null,
      'items': resolvedItems,
      'pending_sync': true,
    };
  }

  Future<void> createOrder(Map<String, dynamic> data) async {
    // Local UUID for entity tracking
    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';

    // Enqueue the offline operation
    await syncService.enqueueOperation(
      entityId: localId,
      operationType: 'CREATE_ORDER',
      payload: data,
    );

    // Save optimistic representation in Hive
    final localBox = ref.read(localOrdersBoxProvider);
    final cleanStr = localId.replaceAll(RegExp(r'[^0-9]'), '');
    final val = int.tryParse(cleanStr) ?? 0;
    final intId = -1 * (val % 1000000000);

    final optimisticJson = _buildOptimisticOrderJson(
      idStr: localId,
      intId: intId,
      data: data,
      ref: ref,
      status: 'DRAFT',
    );

    await localBox.put(localId, jsonEncode(optimisticJson));

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

    // Optimistically update the existing cached order
    final localBox = ref.read(localOrdersBoxProvider);
    final existingStr = localBox.get(entityId);
    if (existingStr != null) {
      try {
        final existingJson = Map<String, dynamic>.from(jsonDecode(existingStr));
        final updatedJson = _buildOptimisticOrderJson(
          idStr: entityId,
          intId: orderId,
          data: data,
          ref: ref,
          status: existingJson['status'] ?? 'DRAFT',
          existingOrderNumber: existingJson['order_number'],
        );
        // Retain any fields from existing that are not in optimistic payload
        updatedJson['created_at'] = existingJson['created_at'] ?? updatedJson['created_at'];
        await localBox.put(entityId, jsonEncode(updatedJson));
      } catch (_) {}
    }

    ref.invalidate(singleOrderProvider(entityId));
    ref.invalidate(ordersListProvider);
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await syncService.enqueueOperation(
      entityId: orderId,
      operationType: 'UPDATE_ORDER_STATUS',
      payload: {'status': newStatus},
    );

    // Optimistically update status in Hive cache
    final localBox = ref.read(localOrdersBoxProvider);
    final existingStr = localBox.get(orderId);
    if (existingStr != null) {
      try {
        final existingJson = Map<String, dynamic>.from(jsonDecode(existingStr));
        existingJson['status'] = newStatus.toUpperCase();
        existingJson['pending_sync'] = true;
        await localBox.put(orderId, jsonEncode(existingJson));
      } catch (_) {}
    }

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
