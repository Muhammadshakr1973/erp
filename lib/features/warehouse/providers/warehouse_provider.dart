import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../salesman/providers/salesman_dashboard_provider.dart';
import '../../../core/utils/formatters.dart';
import '../models/warehouse_order_model.dart';
import '../models/warehouse_stock_model.dart';
import '../models/stock_transfer_model.dart';

final activeWarehouseIdProvider = StateProvider<int?>((ref) => null);

class OrdersToPackNotifier extends AsyncNotifier<List<WarehouseOrderModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<WarehouseOrderModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final activeWarehouseId = ref.watch(activeWarehouseIdProvider);
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onOrdersEvent(Map<String, dynamic> eventData) {
      debugPrint("Pusher: Realtime update received on ordersToPackProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-orders', onOrdersEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-orders', onOrdersEvent);
    });

    return _fetchOrdersToPack(api, activeWarehouseId);
  }

  Future<List<WarehouseOrderModel>> _fetchOrdersToPack(
    ApiClient api,
    int? activeWarehouseId,
  ) async {
    try {
      final response = await api.client.get(
        '/warehouse/orders-to-pack',
        queryParameters: activeWarehouseId != null ? {'warehouse_id': activeWarehouseId} : null,
      );
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed orders-to-pack response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data.map((json) => WarehouseOrderModel.fromJson(json)).toList();
      }
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  bool _samePackList(
    List<WarehouseOrderModel> a,
    List<WarehouseOrderModel> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final oa = a[i];
      final ob = b[i];
      if (oa.id != ob.id ||
          oa.orderNumber != ob.orderNumber ||
          oa.status != ob.status ||
          oa.customerName != ob.customerName ||
          oa.salesmanName != ob.salesmanName ||
          oa.items.length != ob.items.length) {
        return false;
      }
      for (int j = 0; j < oa.items.length; j++) {
        final ia = oa.items[j];
        final ib = ob.items[j];
        if (ia.id != ib.id ||
            ia.productId != ib.productId ||
            ia.quantity != ib.quantity ||
            ia.isPacked != ib.isPacked ||
            ia.packedAt != ib.packedAt) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final activeWarehouseId = ref.read(activeWarehouseIdProvider);
      final fresh = await _fetchOrdersToPack(api, activeWarehouseId);
      final current = state.valueOrNull;
      if (current != null && _samePackList(current, fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current list on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final ordersToPackProvider =
    AsyncNotifierProvider<OrdersToPackNotifier, List<WarehouseOrderModel>>(
      OrdersToPackNotifier.new,
    );

class WarehouseDashboardData {
  final int? warehouseId;
  final String warehouseName;
  final int pendingPackingCount;
  final int readyTodayCount;
  final int lowStockCount;
  final List<WarehouseOrderModel> recentOrders;
  final List<WarehouseStockModel> lowStockItems;

  WarehouseDashboardData({
    this.warehouseId,
    required this.warehouseName,
    required this.pendingPackingCount,
    required this.readyTodayCount,
    required this.lowStockCount,
    required this.recentOrders,
    required this.lowStockItems,
  });
}

class WarehouseDashboardNotifier extends AsyncNotifier<WarehouseDashboardData> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<WarehouseDashboardData> build() async {
    ref.watch(authProvider.select((state) => state.user?.id));
    final activeWarehouseId = ref.watch(activeWarehouseIdProvider);
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onRealtimeEvent(Map<String, dynamic> eventData) {
      debugPrint("Pusher: Realtime update received on warehouseDashboardProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-orders', onRealtimeEvent);
    pusher.subscribeToChannel('private-products', onRealtimeEvent);
    pusher.subscribeToChannel('private-warehouses', onRealtimeEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-orders', onRealtimeEvent);
      pusher.unsubscribeFromChannel('private-products', onRealtimeEvent);
      pusher.unsubscribeFromChannel('private-warehouses', onRealtimeEvent);
    });

    return _fetchDashboard(api, activeWarehouseId);
  }

  Future<WarehouseDashboardData> _fetchDashboard(
    ApiClient api,
    int? activeWarehouseId,
  ) async {
    try {
      final response = await api.client.get(
        '/warehouse/dashboard',
        queryParameters: activeWarehouseId != null ? {'warehouse_id': activeWarehouseId} : null,
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['data'] is Map) {
        final data = response.data['data'] as Map<String, dynamic>;
        final recentOrdersList = (data['recent_orders'] as List? ?? [])
            .map((j) => WarehouseOrderModel.fromJson(j as Map<String, dynamic>))
            .toList();
        final lowStockList = (data['low_stock_items'] as List? ?? [])
            .map((j) => WarehouseStockModel.fromJson(j as Map<String, dynamic>))
            .toList();

        return WarehouseDashboardData(
          warehouseId: data['warehouse_id'] != null ? Formatters.parseInt(data['warehouse_id']) : null,
          warehouseName: data['warehouse_name']?.toString() ?? 'کۆگای سەرەکی',
          pendingPackingCount: Formatters.parseInt(data['pending_packing_count']),
          readyTodayCount: Formatters.parseInt(data['ready_today_count']),
          lowStockCount: Formatters.parseInt(data['low_stock_count']),
          recentOrders: recentOrdersList,
          lowStockItems: lowStockList,
        );
      }
    } catch (_) {
      // Fallback if backend endpoint is not yet deployed on live hosting:
      // aggregate directly from live orders and stock endpoints
    }

    try {
      final List<WarehouseOrderModel> orders =
          await ref.read(ordersToPackProvider.future);
      final List<WarehouseStockModel> stocks =
          await ref.read(warehouseStocksProvider.future);

      final lowStockItems =
          stocks.where((s) => s.quantity <= s.minStockLevel).toList();
      final warehouseName =
          stocks.isNotEmpty ? stocks.first.warehouseName : 'کۆگای سەرەکی';

      return WarehouseDashboardData(
        warehouseId: stocks.isNotEmpty ? stocks.first.warehouseId : null,
        warehouseName: warehouseName,
        pendingPackingCount: orders.length,
        readyTodayCount: 0,
        lowStockCount: lowStockItems.length,
        recentOrders: orders.take(5).toList(),
        lowStockItems: lowStockItems.take(5).toList(),
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final activeWarehouseId = ref.read(activeWarehouseIdProvider);
      final fresh = await _fetchDashboard(api, activeWarehouseId);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current dashboard state on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final warehouseDashboardProvider =
    AsyncNotifierProvider<WarehouseDashboardNotifier, WarehouseDashboardData>(
  WarehouseDashboardNotifier.new,
);

class WarehouseStocksNotifier extends AsyncNotifier<List<WarehouseStockModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<WarehouseStockModel>> build() async {
    final user = ref.watch(authProvider.select((state) => state.user));
    final activeWarehouseId = ref.watch(activeWarehouseIdProvider);
    final requestedWarehouseId = user?.isSalesman == true
        ? user?.warehouseId
        : activeWarehouseId;
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onProductStockEvent(Map<String, dynamic> eventData) {
      debugPrint("Pusher: Realtime update received on warehouseStocksProvider: $eventData");
      if (_tryPatchFromProductEvent(eventData, requestedWarehouseId)) {
        return;
      }
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-products', onProductStockEvent);
    pusher.subscribeToChannel('private-warehouses', onProductStockEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-products', onProductStockEvent);
      pusher.unsubscribeFromChannel('private-warehouses', onProductStockEvent);
    });

    return _fetchStocks(api, requestedWarehouseId);
  }

  bool _tryPatchFromProductEvent(
    Map<String, dynamic> eventData,
    int? requestedWarehouseId,
  ) {
    final current = state.valueOrNull;
    if (current == null) return false;

    final productId = int.tryParse(eventData['product_id']?.toString() ?? '');
    if (eventData['event_type']?.toString() == 'delete' && productId != null) {
      final filtered = current.where((s) => s.productId != productId).toList();
      if (filtered.length != current.length) {
        state = AsyncData(filtered);
      }
      return true;
    }

    final productMap = eventData['product'] is Map
        ? Map<String, dynamic>.from(eventData['product'] as Map)
        : null;
    final rawStocks = productMap?['stocks'] ?? eventData['stocks'];
    if (productId == null || rawStocks is! List) return false;

    final matchingIncoming = <int, Map<String, dynamic>>{};
    for (final s in rawStocks) {
      if (s is Map) {
        final wId = Formatters.parseInt(s['warehouse_id']);
        if (requestedWarehouseId != null && wId != requestedWarehouseId) continue;
        matchingIncoming[wId] = Map<String, dynamic>.from(s);
      }
    }

    if (matchingIncoming.isEmpty && requestedWarehouseId != null) {
      return true;
    }

    bool allExistingMatched = true;
    for (final wId in matchingIncoming.keys) {
      if (!current.any((s) => s.productId == productId && s.warehouseId == wId)) {
        allExistingMatched = false;
        break;
      }
    }
    if (!allExistingMatched) return false;

    bool anyChanged = false;
    final updatedList = current.map((existing) {
      if (existing.productId != productId) return existing;
      final incoming = matchingIncoming[existing.warehouseId];
      if (incoming == null) return existing;

      final nextQty = Formatters.parseDouble(incoming['quantity']);
      final nextReserved = Formatters.parseDouble(incoming['reserved_quantity']);
      final nextMin = Formatters.parseDouble(incoming['min_stock_level']);
      final nextPName = productMap?['name']?.toString() ?? existing.productName;
      final nextBarcode = productMap?['barcode']?.toString() ?? existing.barcode;

      if (existing.quantity == nextQty &&
          existing.reservedQuantity == nextReserved &&
          existing.minStockLevel == nextMin &&
          existing.productName == nextPName &&
          existing.barcode == nextBarcode) {
        return existing;
      }
      anyChanged = true;
      return WarehouseStockModel(
        id: existing.id,
        warehouseId: existing.warehouseId,
        warehouseName: existing.warehouseName,
        productId: existing.productId,
        productName: nextPName,
        barcode: nextBarcode,
        quantity: nextQty,
        reservedQuantity: nextReserved,
        minStockLevel: nextMin,
      );
    }).toList();

    if (anyChanged) {
      state = AsyncData(updatedList);
    }
    return true;
  }

  Future<List<WarehouseStockModel>> _fetchStocks(
    ApiClient api,
    int? requestedWarehouseId,
  ) async {
    try {
      final response = await api.client.get(
        '/warehouse/stock',
        queryParameters: requestedWarehouseId != null
            ? {'warehouse_id': requestedWarehouseId}
            : null,
      );
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed warehouse stock response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data.map((json) => WarehouseStockModel.fromJson(json)).toList();
      }
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  bool _sameStockList(
    List<WarehouseStockModel> a,
    List<WarehouseStockModel> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final sa = a[i];
      final sb = b[i];
      if (sa.id != sb.id ||
          sa.warehouseId != sb.warehouseId ||
          sa.warehouseName != sb.warehouseName ||
          sa.productId != sb.productId ||
          sa.productName != sb.productName ||
          sa.barcode != sb.barcode ||
          sa.quantity != sb.quantity ||
          sa.reservedQuantity != sb.reservedQuantity ||
          sa.minStockLevel != sb.minStockLevel) {
        return false;
      }
    }
    return true;
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final user = ref.read(authProvider).user;
      final activeWarehouseId = ref.read(activeWarehouseIdProvider);
      final requestedWarehouseId = user?.isSalesman == true
          ? user?.warehouseId
          : activeWarehouseId;
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchStocks(api, requestedWarehouseId);
      final current = state.valueOrNull;
      if (current != null && _sameStockList(current, fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current stock list on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final warehouseStocksProvider =
    AsyncNotifierProvider<WarehouseStocksNotifier, List<WarehouseStockModel>>(
  WarehouseStocksNotifier.new,
);

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
      // Intentionally not invalidating entire list providers on single item pack
      // to maintain ultra-fast, smooth, optimistic UI interactions.
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> packItems(List<Map<String, dynamic>> items) async {
    try {
      final idempotencyKey = 'pack_items_${DateTime.now().microsecondsSinceEpoch}';
      await api.client.post(
        '/warehouse/pack-items',
        data: {'items': items},
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );
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
      if (ref.exists(ordersToPackProvider)) {
        unawaited(ref.read(ordersToPackProvider.notifier).refreshSilently());
      }
      if (ref.exists(singleOrderProvider(orderId.toString()))) {
        unawaited(
          ref.read(singleOrderProvider(orderId.toString()).notifier).refreshSilently(),
        );
      }
      if (ref.exists(warehouseStocksProvider)) {
        unawaited(ref.read(warehouseStocksProvider.notifier).refreshSilently());
      }
      if (ref.exists(warehouseDashboardProvider)) {
        unawaited(ref.read(warehouseDashboardProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      await api.client.delete('/orders/$orderId');
      if (ref.exists(ordersToPackProvider)) {
        unawaited(ref.read(ordersToPackProvider.notifier).refreshSilently());
      }
      ref.read(ordersListProvider.notifier).removeOrderLocally(orderId.toString());
      if (ref.exists(singleOrderProvider(orderId.toString()))) {
        ref.read(singleOrderProvider(orderId.toString()).notifier).setOrderLocally(null);
      }
      if (ref.exists(warehouseDashboardProvider)) {
        unawaited(ref.read(warehouseDashboardProvider.notifier).refreshSilently());
      }
      ref
          .read(salesmanDashboardProvider.notifier)
          .refreshSilently();
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> adjustStock({
    required int warehouseId,
    required int productId,
    required num quantityChange,
    String type = 'ADJUSTMENT',
    String? notes,
  }) async {
    try {
      final idempotencyKey = 'adjust_${warehouseId}_${productId}_${DateTime.now().microsecondsSinceEpoch}';
      await api.client.post(
        '/warehouses/$warehouseId/stock/$productId/adjust',
        data: {
          'warehouse_id': warehouseId,
          'product_id': productId,
          'quantity_change': quantityChange,
          'type': type,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (ref.exists(warehouseStocksProvider)) {
        unawaited(ref.read(warehouseStocksProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<StockReconciliationModel> reconcileStock({
    required int warehouseId,
    required int productId,
  }) async {
    try {
      final response = await api.client.get(
        '/warehouses/$warehouseId/stock/$productId/reconcile',
      );
      
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map<String, dynamic>) {
          throw const FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed reconciliation response payload)',
          );
        }
        
        if (ref.exists(warehouseStocksProvider)) {
          unawaited(ref.read(warehouseStocksProvider.notifier).refreshSilently());
        }
        return StockReconciliationModel.fromJson(resData['data']);
      }
      
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
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
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<StockTransferModel?> createStockTransfer({
    required int fromWarehouseId,
    required int toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
    bool completeNow = false,
  }) async {
    try {
      final idempotencyKey = 'transfer_${DateTime.now().microsecondsSinceEpoch}';
      final response = await api.client.post(
        '/stock-transfers',
        data: {
          'from_warehouse_id': fromWarehouseId,
          'to_warehouse_id': toWarehouseId,
          'items': items,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (completeNow) 'complete_now': true,
        },
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (ref.exists(warehouseStocksProvider)) {
        unawaited(ref.read(warehouseStocksProvider.notifier).refreshSilently());
      }
      StockTransferModel? created;
      if (response.data is Map && response.data['data'] is Map) {
        created = StockTransferModel.fromJson(response.data['data']);
        if (ref.exists(stockTransfersListProvider)) {
          ref.read(stockTransfersListProvider.notifier).upsertTransferLocally(created);
        }
      } else if (ref.exists(stockTransfersListProvider)) {
        unawaited(ref.read(stockTransfersListProvider.notifier).refreshSilently());
      }
      return created;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> completeStockTransfer(int transferId) async {
    try {
      final idempotencyKey = 'transfer_complete_${transferId}_${DateTime.now().microsecondsSinceEpoch}';
      await api.client.post(
        '/stock-transfers/$transferId/complete',
        data: {},
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (ref.exists(warehouseStocksProvider)) {
        unawaited(ref.read(warehouseStocksProvider.notifier).refreshSilently());
      }
      if (ref.exists(stockTransfersListProvider)) {
        unawaited(ref.read(stockTransfersListProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> cancelStockTransfer(int transferId) async {
    try {
      final idempotencyKey = 'transfer_cancel_${transferId}_${DateTime.now().microsecondsSinceEpoch}';
      await api.client.post(
        '/stock-transfers/$transferId/cancel',
        data: {},
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (ref.exists(warehouseStocksProvider)) {
        unawaited(ref.read(warehouseStocksProvider.notifier).refreshSilently());
      }
      if (ref.exists(stockTransfersListProvider)) {
        unawaited(ref.read(stockTransfersListProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}

class StockTransfersListNotifier extends AsyncNotifier<List<StockTransferModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<StockTransferModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onStockTransferEvent(Map<String, dynamic> eventData) {
      debugPrint("Pusher: Realtime update received on stockTransfersListProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-stock-transfers', onStockTransferEvent);
    pusher.subscribeToChannel('private-products', onStockTransferEvent);
    pusher.subscribeToChannel('private-warehouses', onStockTransferEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-stock-transfers', onStockTransferEvent);
      pusher.unsubscribeFromChannel('private-products', onStockTransferEvent);
      pusher.unsubscribeFromChannel('private-warehouses', onStockTransferEvent);
    });

    return _fetchTransfers(api);
  }

  Future<List<StockTransferModel>> _fetchTransfers(ApiClient api) async {
    try {
      final response = await api.client.get('/stock-transfers');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw const FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە',
          );
        }
        final List data = resData['data'] as List;
        return data.map((json) => StockTransferModel.fromJson(json)).toList();
      }
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە: ${response.statusCode}');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchTransfers(api);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current transfers on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }

  void upsertTransferLocally(StockTransferModel transfer) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == transfer.id);
    final updated = List<StockTransferModel>.from(current);
    if (idx != -1) {
      updated[idx] = transfer;
    } else {
      updated.insert(0, transfer);
    }
    state = AsyncData(updated);
  }
}

final stockTransfersListProvider =
    AsyncNotifierProvider<StockTransfersListNotifier, List<StockTransferModel>>(
  StockTransfersListNotifier.new,
);

class VanTransferDraft {
  final int? fromWarehouseId;
  final int? toWarehouseId;
  final String notes;
  final Map<int, num> items; // productId -> quantity

  const VanTransferDraft({
    this.fromWarehouseId,
    this.toWarehouseId,
    this.notes = 'بارکردنی کاڵا بۆ ئۆتۆمبێلی کاشڤان',
    this.items = const {},
  });

  VanTransferDraft copyWith({
    int? fromWarehouseId,
    int? toWarehouseId,
    String? notes,
    Map<int, num>? items,
  }) {
    return VanTransferDraft(
      fromWarehouseId: fromWarehouseId ?? this.fromWarehouseId,
      toWarehouseId: toWarehouseId ?? this.toWarehouseId,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }
}

final vanTransferDraftStateProvider =
    StateProvider<VanTransferDraft>((ref) => const VanTransferDraft());
