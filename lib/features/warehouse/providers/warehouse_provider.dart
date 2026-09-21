import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../../core/sync/sync_service.dart';
import '../models/warehouse_order_model.dart';
import '../models/warehouse_stock_model.dart';

final FutureProvider<List<WarehouseOrderModel>> ordersToPackProvider =
    FutureProvider<List<WarehouseOrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onOrdersEvent(Map<String, dynamic> eventData) {
    debugPrint("Pusher: Realtime update received on ordersToPackProvider: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-orders', onOrdersEvent);

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-orders', onOrdersEvent);
  });

  try {
    final response = await api.client.get('/warehouse/orders-to-pack');
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
});

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

final FutureProvider<WarehouseDashboardData> warehouseDashboardProvider =
    FutureProvider<WarehouseDashboardData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onRealtimeEvent(Map<String, dynamic> eventData) {
    debugPrint("Pusher: Realtime update received on warehouseDashboardProvider: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-orders', onRealtimeEvent);
  pusher.subscribeToChannel('private-products', onRealtimeEvent);

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-orders', onRealtimeEvent);
    pusher.unsubscribeFromChannel('private-products', onRealtimeEvent);
  });

  try {
    final response = await api.client.get('/warehouse/dashboard');
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
        warehouseId: data['warehouse_id'] as int?,
        warehouseName: data['warehouse_name'] ?? 'کۆگای سەرەکی',
        pendingPackingCount: (data['pending_packing_count'] as num?)?.toInt() ?? 0,
        readyTodayCount: (data['ready_today_count'] as num?)?.toInt() ?? 0,
        lowStockCount: (data['low_stock_count'] as num?)?.toInt() ?? 0,
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
        await ref.watch(ordersToPackProvider.future);
    final List<WarehouseStockModel> stocks =
        await ref.watch(warehouseStocksProvider.future);

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
});

final FutureProvider<List<WarehouseStockModel>> warehouseStocksProvider =
    FutureProvider<List<WarehouseStockModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onProductStockEvent(Map<String, dynamic> eventData) {
    debugPrint("Pusher: Realtime update received on warehouseStocksProvider: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-products', onProductStockEvent);

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-products', onProductStockEvent);
  });

  try {
    final response = await api.client.get('/warehouse/stock');
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
        
        ref.invalidate(warehouseStocksProvider);
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

  Future<void> createStockTransfer({
    required int fromWarehouseId,
    required int toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
      await syncService.enqueueOperation(
        entityId: localId,
        operationType: 'STOCK_TRANSFER_CREATE',
        payload: {
          'from_warehouse_id': fromWarehouseId,
          'to_warehouse_id': toWarehouseId,
          'items': items,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      await syncService.syncPendingOperations();
      ref.invalidate(warehouseStocksProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> completeStockTransfer(int transferId) async {
    try {
      await syncService.enqueueOperation(
        entityId: transferId.toString(),
        operationType: 'STOCK_TRANSFER_COMPLETE',
        payload: {},
      );
      await syncService.syncPendingOperations();
      ref.invalidate(warehouseStocksProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> cancelStockTransfer(int transferId) async {
    try {
      await syncService.enqueueOperation(
        entityId: transferId.toString(),
        operationType: 'STOCK_TRANSFER_CANCEL',
        payload: {},
      );
      await syncService.syncPendingOperations();
      ref.invalidate(warehouseStocksProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}

