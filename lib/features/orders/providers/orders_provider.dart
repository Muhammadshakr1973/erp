import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../../shared/models/customer.dart';
import '../../shared/providers/customer_provider.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/products_provider.dart';
import '../models/order_model.dart';

// Provide local orders box
final localOrdersBoxProvider = Provider<Box<String>>((ref) {
  return Hive.box<String>('local_orders');
});

bool _isNetworkError(dynamic e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    if (e.response == null) {
      return true;
    }
    return false;
  }
  final errStr = e.toString().toLowerCase();
  if (errStr.contains('socketexception') ||
      errStr.contains('networkisunreachable') ||
      errStr.contains('connection refused')) {
    return true;
  }
  return false;
}

final ordersListProvider = FutureProvider<List<OrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final localBox = ref.watch(localOrdersBoxProvider);
  final syncBox = ref.watch(syncQueueBoxProvider);

  try {
    final response = await api.client.get('/orders');
    if (response.statusCode == 200) {
      final resData = response.data['data'] ?? response.data;
      if (resData is! List) {
        throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response payload)');
      }
      final List data = resData;
      final onlineOrders = data
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Update local cache: clear server-cached entries (keys not starting with 'local_')
      // Only delete if there is no pending/failed/syncing operation in the sync queue
      final keysToDelete = localBox.keys
          .where((k) {
            final keyStr = k.toString();
            if (keyStr.startsWith('local_')) return false;
            final hasPendingOp = syncBox.values.any(
              (entry) =>
                  entry.entityId == keyStr &&
                  (entry.status == 'PENDING' ||
                      entry.status == 'FAILED' ||
                      entry.status == 'SYNCING'),
            );
            return !hasPendingOp;
          })
          .toList();
      for (final key in keysToDelete) {
        await localBox.delete(key);
      }

      // Write new online orders, preserving those that have pending mutations in the sync queue
      for (var i = 0; i < data.length; i++) {
        final order = onlineOrders[i];
        final rawJson = data[i];
        if (rawJson is Map) {
          final Map<String, dynamic> castedJson = Map<String, dynamic>.from(
            rawJson,
          );
          // Only overwrite if it is NOT pending/syncing/failed in the sync queue
          final hasPendingOp = syncBox.values.any(
            (entry) =>
                entry.entityId == order.id.toString() &&
                (entry.status == 'PENDING' ||
                    entry.status == 'FAILED' ||
                    entry.status == 'SYNCING'),
          );
          if (!hasPendingOp) {
            await localBox.put(order.id.toString(), jsonEncode(castedJson));
          }
        }
      }

      // Replace online orders with their local optimistic versions if they are pending sync
      final List<OrderModel> finalOnlineOrders = [];
      for (final order in onlineOrders) {
        final hasPendingOp = syncBox.values.any(
          (entry) =>
              entry.entityId == order.id.toString() &&
              (entry.status == 'PENDING' ||
                  entry.status == 'FAILED' ||
                  entry.status == 'SYNCING'),
        );
        if (hasPendingOp) {
          final localJsonStr = localBox.get(order.id.toString());
          if (localJsonStr != null) {
            try {
              final Map<String, dynamic> localJson = jsonDecode(localJsonStr);
              finalOnlineOrders.add(OrderModel.fromJson(localJson));
              continue;
            } catch (_) {}
          }
        }
        finalOnlineOrders.add(order);
      }

      // Read remaining local optimistic orders
      final remainingLocalOrders = <OrderModel>[];
      final freshLocalKeys = localBox.keys
          .where((k) => k.toString().startsWith('local_'))
          .toList();
      for (final key in freshLocalKeys) {
        final jsonStr = localBox.get(key);
        if (jsonStr != null) {
          try {
            final Map<String, dynamic> json = jsonDecode(jsonStr);
            final localOrder = OrderModel.fromJson(json);

            // Duplicate prevention: check if online orders contain this local order (by sharedKey, mappedServerId, or ID)
            Box<String>? idMappingsBox;
            try {
              idMappingsBox = Hive.box<String>('id_mappings');
            } catch (_) {}

            final mappedServerIdStr = idMappingsBox?.get(key);
            final mappedServerId = mappedServerIdStr != null
                ? int.tryParse(mappedServerIdStr)
                : null;

            final alreadySynced = finalOnlineOrders.any(
              (o) =>
                  (o.sharedKey != null &&
                      localOrder.sharedKey != null &&
                      o.sharedKey == localOrder.sharedKey) ||
                  (mappedServerId != null && o.id == mappedServerId) ||
                  (localOrder.id > 0 && o.id == localOrder.id),
            );

            if (alreadySynced) {
              await localBox.delete(
                key,
              ); // Safe sweep: Synced order found, clean up local key
            } else {
              // Check if it still has a pending create operation
              final hasPendingOp = syncBox.values.any(
                (entry) =>
                    entry.entityId == key &&
                    entry.operationType == 'CREATE_ORDER' &&
                    (entry.status == 'PENDING' ||
                        entry.status == 'FAILED' ||
                        entry.status == 'SYNCING'),
              );

              if (hasPendingOp) {
                remainingLocalOrders.add(localOrder);
              } else {
                final isCompleted = syncBox.values.any(
                  (entry) =>
                      entry.entityId == key &&
                      entry.operationType == 'CREATE_ORDER' &&
                      entry.status == 'COMPLETED',
                );
                if (isCompleted) {
                  // Keep it to prevent a flash of disappearing order before next synchronization loop syncs up fully
                  remainingLocalOrders.add(localOrder);
                } else {
                  // Truly orphaned local record (no corresponding sync queue entry), clean it up
                  await localBox.delete(key);
                }
              }
            }
          } catch (_) {}
        }
      }

      // Merge and return
      return [...finalOnlineOrders, ...remainingLocalOrders];
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
    if (_isNetworkError(e)) {
      // Return cached orders on genuine network error
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
      throw Exception(
        'پەیوەندی هێڵ لەدەستدراوە و هیچ پسوڵەیەکی پاشەکەوتکراو نییە (No network connection and no cached orders)',
      );
    }
    if (e is DioException) {
      throw Exception(api.parseError(e));
    }
    rethrow;
  }
});

final singleOrderProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  orderId,
) async {
  final api = ref.watch(apiClientProvider);
  final localBox = ref.watch(localOrdersBoxProvider);
  final pusher = ref.watch(pusherServiceProvider);

  // If orderId is a real server ID (not a local temporary one)
  final parsedId = int.tryParse(orderId);
  if (parsedId != null && parsedId > 0) {
    // Subscribe to Pusher channel when this provider is active
    pusher.subscribeToOrder(parsedId, (eventData) {
      debugPrint("Realtime update for order $orderId: $eventData");

      // Check for pending local mutations before applying realtime update
      final syncBox = ref.read(syncQueueBoxProvider);
      final hasPendingOp = syncBox.values.any(
        (entry) =>
            entry.entityId == orderId &&
            (entry.status == 'PENDING' ||
                entry.status == 'FAILED' ||
                entry.status == 'SYNCING'),
      );
      if (hasPendingOp) {
        debugPrint("Preserving still-valid pending offline mutations. Skipping realtime update overwrite.");
        return;
      }

      final eventVersion = int.tryParse(eventData['version']?.toString() ?? '') ?? 0;

      // Read current local authoritative order from cache to do version comparison
      final cachedStr = localBox.get(orderId);
      if (cachedStr != null) {
        try {
          final Map<String, dynamic> cachedJson = jsonDecode(cachedStr);
          final currentVersion = int.tryParse(cachedJson['version']?.toString() ?? '1') ?? 1;

          // Version Comparison Logic:
          // Ignore older versions (preventing race conditions)
          if (eventVersion < currentVersion) {
            debugPrint("Ignoring stale realtime update (event version $eventVersion < current version $currentVersion)");
            return;
          }

          // Equal version is a duplicate/no-op
          if (eventVersion == currentVersion) {
            debugPrint("Realtime update version is equal to current version ($eventVersion). No-op.");
            return;
          }

          // Check if it's the next expected version (currentVersion + 1)
          if (eventVersion == currentVersion + 1) {
            debugPrint("Accepting next expected version $eventVersion");
            if (eventData['authoritative_signal'] == 'refetch') {
              ref.invalidateSelf();
              ref.invalidate(ordersListProvider);
            }
          } else {
            // Version skipped (eventVersion > currentVersion + 1)
            // Trigger a full server refetch to heal state.
            debugPrint("Version skipped (event version $eventVersion > expected ${currentVersion + 1}). Invalidating self to refetch.");
            ref.invalidateSelf();
            ref.invalidate(ordersListProvider);
          }
        } catch (e) {
          ref.invalidateSelf();
          ref.invalidate(ordersListProvider);
        }
      } else {
        // No local cache yet, refetch
        ref.invalidateSelf();
        ref.invalidate(ordersListProvider);
      }
    });

    // Unsubscribe when provider is disposed to clean subscription lifecycle (PRV-001)
    ref.onDispose(() {
      pusher.unsubscribeFromOrder(parsedId);
    });
  }

  try {
    final response = await api.client.get('/orders/$orderId');
    if (response.statusCode == 200) {
      final data = response.data['data'] ?? response.data;
      if (data is! Map) {
        throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response payload)');
      }
      final order = OrderModel.fromJson(Map<String, dynamic>.from(data));
      final Map<String, dynamic> castedJson = Map<String, dynamic>.from(data);
      await localBox.put(order.id.toString(), jsonEncode(castedJson));
      return order;
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
    if (_isNetworkError(e)) {
      final cachedStr = localBox.get(orderId);
      if (cachedStr != null) {
        try {
          final Map<String, dynamic> json = jsonDecode(cachedStr);
          return OrderModel.fromJson(json);
        } catch (_) {
          // Safe fallback - don't crash
        }
      }
    }
    if (e is DioException) {
      throw Exception(api.parseError(e));
    }
    rethrow;
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

    Customer? customer;
    for (final c in customers) {
      if (c.id == customerId) {
        customer = c;
        break;
      }
    }

    final products = ref.read(productsListProvider).value ?? [];
    final itemsData = data['items'] ?? [];

    double subtotal = 0.0;
    double totalProfit = 0.0;
    final List<Map<String, dynamic>> resolvedItems = [];

    for (final item in itemsData) {
      final int prodId = item['product_id'] ?? 0;
      final double qty =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;

      ProductModel? prod;
      for (final p in products) {
        if (p.id == prodId) {
          prod = p;
          break;
        }
      }

      String productName = 'کاڵا';
      double unitPrice = 0.0;
      double costPrice = 0.0;

      if (prod != null) {
        productName = prod.name;
        costPrice = prod.costPrice;
        final priceType = customer?.priceType ?? 'N2';
        if (priceType == 'N1') {
          unitPrice = prod.priceN1;
        } else if (priceType == 'N3') {
          unitPrice = prod.priceN3;
        } else {
          unitPrice = prod.priceN2;
        }
      }

      final double itemSubtotal = qty * unitPrice;
      subtotal += itemSubtotal;

      final double profit = (unitPrice - costPrice) * qty;
      totalProfit += profit;

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

    // 1. Permanent Customer Discount
    final double permDiscountPercent = customer?.permanentDiscount ?? 0.0;
    double permDiscountAmount = 0.0;
    if (permDiscountPercent > 0.0) {
      permDiscountAmount = (subtotal * permDiscountPercent / 100.0)
          .roundToDouble();
    }
    final double amountAfterPermDiscount = max(
      0.0,
      subtotal - permDiscountAmount,
    );

    // 2. Invoice / Order Discount (matching exact php logic)
    final String discountType = (data['discount_type'] ?? 'PERCENT')
        .toString()
        .toUpperCase();
    double invoiceDiscountPercent = 0.0;
    double invoiceDiscountAmount = 0.0;

    if (discountType == 'FIXED' ||
        (data['discount_amount'] != null &&
            double.tryParse(data['discount_amount'].toString()) != null &&
            double.parse(data['discount_amount'].toString()) > 0.0 &&
            data['discount_percent'] == null)) {
      final double fixedAmount =
          double.tryParse(data['discount_amount']?.toString() ?? '0') ?? 0.0;
      invoiceDiscountAmount = min(
        amountAfterPermDiscount,
        max(0.0, fixedAmount),
      );
    } else {
      invoiceDiscountPercent =
          double.tryParse(data['discount_percent']?.toString() ?? '0') ?? 0.0;
      invoiceDiscountAmount =
          (amountAfterPermDiscount * invoiceDiscountPercent / 100.0)
              .roundToDouble();
    }

    final double totalAmount = max(
      0.0,
      amountAfterPermDiscount - invoiceDiscountAmount,
    );

    final orderNumber =
        existingOrderNumber ??
        "LOCAL_${idStr.replaceAll('local_', '').substring(0, min(6, idStr.replaceAll('local_', '').length))}";

    return {
      'id': intId,
      'order_number': orderNumber,
      'shared_key': data['shared_key'],
      'version': data['version'] ?? 1,
      'customer_id': customerId,
      'salesman_id': data['salesman_id'] ?? 0,
      'warehouse_id': data['warehouse_id'],
      'subtotal': subtotal,
      'permanent_discount_percent': permDiscountPercent,
      'permanent_discount_amount': permDiscountAmount,
      'discount_amount': invoiceDiscountAmount,
      'discount_percent': invoiceDiscountPercent,
      'discount_type': discountType,
      'total_amount': totalAmount,
      'total_profit': totalProfit,
      'status': status,
      'notes': data['notes'],
      'created_at': DateTime.now().toIso8601String(),
      'customer': customer != null
          ? {'id': customer.id, 'name': customer.name}
          : null,
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

    String keyToUse = entityId;
    String? existingStr = localBox.get(entityId);
    if (existingStr == null && orderId < 0) {
      // Find the local_ key that corresponds to this negative ID
      for (final key in localBox.keys) {
        if (key.toString().startsWith('local_')) {
          final str = localBox.get(key);
          if (str != null) {
            try {
              final Map<String, dynamic> parsed = jsonDecode(str);
              if (parsed['id'] == orderId) {
                keyToUse = key.toString();
                existingStr = str;
                break;
              }
            } catch (_) {}
          }
        }
      }
    }

    if (existingStr != null) {
      try {
        final Map<String, dynamic> existingJson = Map<String, dynamic>.from(
          jsonDecode(existingStr),
        );

        final mergedData = <String, dynamic>{...existingJson};
        for (final key in data.keys) {
          mergedData[key] = data[key];
        }

        final updatedJson = _buildOptimisticOrderJson(
          idStr: keyToUse,
          intId: orderId,
          data: mergedData,
          ref: ref,
          status: existingJson['status'] ?? 'DRAFT',
          existingOrderNumber: existingJson['order_number'],
        );

        // Retain and preserve fields from existing order specifically matching instructions
        updatedJson['id'] = existingJson['id'] ?? orderId;
        updatedJson['order_number'] =
            existingJson['order_number'] ?? updatedJson['order_number'];
        updatedJson['shared_key'] =
            data['shared_key'] ?? existingJson['shared_key'];
        updatedJson['version'] =
            data['version'] ?? existingJson['version'] ?? 1;
        updatedJson['customer_id'] =
            data['customer_id'] ?? existingJson['customer_id'];
        updatedJson['salesman_id'] =
            data['salesman_id'] ?? existingJson['salesman_id'];
        updatedJson['warehouse_id'] =
            data['warehouse_id'] ?? existingJson['warehouse_id'];
        updatedJson['created_at'] =
            existingJson['created_at'] ?? updatedJson['created_at'];

        if (data['customer'] != null) {
          updatedJson['customer'] = data['customer'];
        } else if (existingJson['customer'] != null) {
          updatedJson['customer'] = existingJson['customer'];
        }

        if (data['salesman'] != null) {
          updatedJson['salesman'] = data['salesman'];
        } else if (existingJson['salesman'] != null) {
          updatedJson['salesman'] = existingJson['salesman'];
        }

        if (data['warehouse'] != null) {
          updatedJson['warehouse'] = data['warehouse'];
        } else if (existingJson['warehouse'] != null) {
          updatedJson['warehouse'] = existingJson['warehouse'];
        }

        if (data['items'] == null) {
          updatedJson['items'] = existingJson['items'];
          updatedJson['subtotal'] = existingJson['subtotal'];
          updatedJson['discount_amount'] = existingJson['discount_amount'];
          updatedJson['discount_percent'] = existingJson['discount_percent'];
          updatedJson['discount_type'] = existingJson['discount_type'];
          updatedJson['total_amount'] = existingJson['total_amount'];
          updatedJson['total_profit'] = existingJson['total_profit'];
        }

        updatedJson['pending_sync'] = true;

        await localBox.put(keyToUse, jsonEncode(updatedJson));
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

    // Optimistically update status in Hive cache preserving everything else
    final localBox = ref.read(localOrdersBoxProvider);

    String keyToUse = orderId;
    String? existingStr = localBox.get(orderId);
    final isNegativeId =
        int.tryParse(orderId) != null && int.parse(orderId) < 0;
    if (existingStr == null && isNegativeId) {
      final orderIntId = int.parse(orderId);
      for (final key in localBox.keys) {
        if (key.toString().startsWith('local_')) {
          final str = localBox.get(key);
          if (str != null) {
            try {
              final Map<String, dynamic> parsed = jsonDecode(str);
              if (parsed['id'] == orderIntId) {
                keyToUse = key.toString();
                existingStr = str;
                break;
              }
            } catch (_) {}
          }
        }
      }
    }

    if (existingStr != null) {
      try {
        final Map<String, dynamic> existingJson = Map<String, dynamic>.from(
          jsonDecode(existingStr),
        );
        existingJson['status'] = newStatus.toUpperCase();
        existingJson['pending_sync'] = true;
        await localBox.put(keyToUse, jsonEncode(existingJson));
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
      final resData = response.data;
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed sales returns list payload)',
        );
      }
      return resData['data'] as List<dynamic>;
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final singleSalesReturnProvider = FutureProvider.family<dynamic, String>((
  ref,
  id,
) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/sales-returns/$id');
    if (response.statusCode == 200) {
      final resData = response.data;
      final data = (resData is Map && resData.containsKey('data')) ? resData['data'] : resData;
      if (data is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed sales return detail payload)',
        );
      }
      return data;
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

class SalesReturnActions {
  final SyncService syncService;
  final ApiClient api;
  final Ref ref;

  SalesReturnActions(this.syncService, this.api, this.ref);

  Future<void> createSalesReturn(Map<String, dynamic> data) async {
    final String returnEntityId =
        data['idempotency_key'] ??
        data['local_id'] ??
        'return_${DateTime.now().microsecondsSinceEpoch}';

    final payload = Map<String, dynamic>.from(data)
      ..['idempotency_key'] = returnEntityId;

    await syncService.enqueueOperation(
      entityId: returnEntityId,
      operationType: 'CREATE_SALES_RETURN',
      payload: payload,
    );

    if (payload['sales_order_id'] != null) {
      ref.invalidate(singleOrderProvider(payload['sales_order_id'].toString()));
    }
    ref.invalidate(ordersListProvider);
    ref.invalidate(salesReturnsListProvider);
  }
}

final salesReturnActionsProvider = Provider<SalesReturnActions>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final api = ref.watch(apiClientProvider);
  return SalesReturnActions(syncService, api, ref);
});

/// پسوڵە ئامادەکراوەکان بۆ دابەشکردن و دروستکردنی گەشتی شۆفێر
/// تەنها ئەو پسوڵانە دەگرێتەوە کە لە دۆخی READY دان
final readyOrdersForDeliveryProvider = FutureProvider<List<OrderModel>>((ref) async {
  final orders = await ref.watch(ordersListProvider.future);
  return orders
      .where((order) => order.status.toUpperCase() == OrderModel.statusReady)
      .toList();
});

