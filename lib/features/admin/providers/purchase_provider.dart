import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../products/providers/suppliers_provider.dart';
import '../models/purchase_requirement_model.dart';
import '../models/purchase_order_model.dart';

class PurchaseRequirementsNotifier
    extends AsyncNotifier<List<PurchaseRequirementModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<PurchaseRequirementModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final apiClient = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onRequirementsEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for purchaseRequirementsProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-purchases', onRequirementsEvent);
    pusher.subscribeToChannel('private-orders', onRequirementsEvent);
    pusher.subscribeToChannel('private-products', onRequirementsEvent);
    pusher.subscribeToChannel('private-suppliers', onRequirementsEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-purchases', onRequirementsEvent);
      pusher.unsubscribeFromChannel('private-orders', onRequirementsEvent);
      pusher.unsubscribeFromChannel('private-products', onRequirementsEvent);
      pusher.unsubscribeFromChannel('private-suppliers', onRequirementsEvent);
    });

    return _fetchRequirements(apiClient);
  }

  Future<List<PurchaseRequirementModel>> _fetchRequirements(
    ApiClient apiClient,
  ) async {
    try {
      final response = await apiClient.client.get('/purchase-requirements');
      final resData = response.data;
      if (!_isSuccessStatus(response.statusCode)) {
        throw Exception(
          apiClient.extractErrorMessage(
            resData,
            defaultMsg: 'کێشە لە بارکردنی داواکارییەکانی کڕین',
          ),
        );
      }
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed purchase requirements response payload)',
        );
      }
      final List<dynamic> data = resData['data'] as List;
      return data
          .whereType<Map>()
          .map((json) => PurchaseRequirementModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final apiClient = ref.read(apiClientProvider);
      final fresh = await _fetchRequirements(apiClient);
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

final purchaseRequirementsProvider = AsyncNotifierProvider<
    PurchaseRequirementsNotifier, List<PurchaseRequirementModel>>(
  PurchaseRequirementsNotifier.new,
);

class PurchaseRequirementsGroupNotifier extends AsyncNotifier<List<dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<dynamic>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final apiClient = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onGroupedRequirementsEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for purchaseRequirementsGroupProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-purchases', onGroupedRequirementsEvent);
    pusher.subscribeToChannel('private-orders', onGroupedRequirementsEvent);
    pusher.subscribeToChannel('private-products', onGroupedRequirementsEvent);
    pusher.subscribeToChannel('private-suppliers', onGroupedRequirementsEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-purchases', onGroupedRequirementsEvent);
      pusher.unsubscribeFromChannel('private-orders', onGroupedRequirementsEvent);
      pusher.unsubscribeFromChannel('private-products', onGroupedRequirementsEvent);
      pusher.unsubscribeFromChannel('private-suppliers', onGroupedRequirementsEvent);
    });

    return _fetchGrouped(apiClient);
  }

  Future<List<dynamic>> _fetchGrouped(ApiClient apiClient) async {
    try {
      final response = await apiClient.client.get('/purchase-requirements/group');
      final resData = response.data;
      if (!_isSuccessStatus(response.statusCode)) {
        throw Exception(
          apiClient.extractErrorMessage(
            resData,
            defaultMsg: 'کێشە لە بارکردنی داواکارییە گرووپکراوەکان',
          ),
        );
      }
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed grouped purchase requirements response payload)',
        );
      }
      return resData['data'] as List<dynamic>;
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final apiClient = ref.read(apiClientProvider);
      final fresh = await _fetchGrouped(apiClient);
      final current = state.valueOrNull;
      if (current != null && jsonEncode(current) == jsonEncode(fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current grouped list on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final purchaseRequirementsGroupProvider =
    AsyncNotifierProvider<PurchaseRequirementsGroupNotifier, List<dynamic>>(
  PurchaseRequirementsGroupNotifier.new,
);

class PurchaseOrdersNotifier extends AsyncNotifier<List<PurchaseOrderModel>> {
  final Map<int, PurchaseOrderModel> _localOrders = {};
  final Set<int> _removedOrderIds = {};
  bool _isRefreshingSilently = false;

  @override
  Future<List<PurchaseOrderModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final apiClient = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onPurchaseOrdersEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for PurchaseOrdersNotifier: $eventData");
      final eventType = eventData['event_type']?.toString();
      final orderId = int.tryParse(
        (eventData['purchase_order_id'] ?? eventData['id'])?.toString() ?? '',
      );
      if (eventType == 'delete' && orderId != null && orderId > 0) {
        removeOrderLocally(orderId);
        return;
      }
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-purchases', onPurchaseOrdersEvent);
    pusher.subscribeToChannel('private-suppliers', onPurchaseOrdersEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-purchases', onPurchaseOrdersEvent);
      pusher.unsubscribeFromChannel('private-suppliers', onPurchaseOrdersEvent);
    });

    return _fetchOrders(apiClient);
  }

  Future<List<PurchaseOrderModel>> _fetchOrders(ApiClient apiClient) async {
    try {
      final response = await apiClient.client.get('/purchase-orders');
      final resData = response.data;
      if (!_isSuccessStatus(response.statusCode)) {
        throw Exception(
          apiClient.extractErrorMessage(
            resData,
            defaultMsg: 'کێشە لە بارکردنی پسوڵەکانی کڕین',
          ),
        );
      }
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed purchase orders response payload)',
        );
      }
      final List<dynamic> data = resData['data'] as List;
      final orders = data
          .whereType<Map>()
          .map((json) => PurchaseOrderModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      final fetchedIds = orders.map((order) => order.id).toSet();
      _removedOrderIds.removeWhere((id) => !fetchedIds.contains(id));
      _localOrders.removeWhere((id, _) => fetchedIds.contains(id));
      orders.removeWhere((order) => _removedOrderIds.contains(order.id));
      return _mergeOrders(orders, _localOrders.values);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshingSilently) return;
    _isRefreshingSilently = true;
    try {
      final apiClient = ref.read(apiClientProvider);
      final freshOrders = await _fetchOrders(apiClient);
      state = AsyncData(freshOrders);
    } catch (_) {
      // Preserve current purchase orders on transient errors
    } finally {
      _isRefreshingSilently = false;
    }
  }

  void upsertOrderLocally(PurchaseOrderModel order) {
    _removedOrderIds.remove(order.id);
    _localOrders[order.id] = order;
    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      state = AsyncData(_mergeOrders(currentOrders, [order]));
    }
  }

  void removeOrderLocally(int orderId) {
    _localOrders.remove(orderId);
    _removedOrderIds.add(orderId);
    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      state = AsyncData(
        currentOrders.where((order) => order.id != orderId).toList(),
      );
    }
  }

  List<PurchaseOrderModel> _mergeOrders(
    Iterable<PurchaseOrderModel> currentOrders,
    Iterable<PurchaseOrderModel> updates,
  ) {
    final ordersById = {
      for (final order in currentOrders) order.id: order,
      for (final order in updates) order.id: order,
    };
    final orders = ordersById.values.toList();
    orders.sort((a, b) {
      final aDate = a.createdAt == null
          ? null
          : DateTime.tryParse(a.createdAt!);
      final bDate = b.createdAt == null
          ? null
          : DateTime.tryParse(b.createdAt!);
      if (aDate == null) return bDate == null ? 0 : 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return orders;
  }
}

final purchaseOrdersProvider =
    AsyncNotifierProvider<PurchaseOrdersNotifier, List<PurchaseOrderModel>>(
      PurchaseOrdersNotifier.new,
    );

final purchaseActionsProvider = Provider<PurchaseActions>((ref) {
  return PurchaseActions(ref);
});

class PurchaseActions {
  final Ref _ref;

  PurchaseActions(this._ref);

  Future<PurchaseOrderModel> createPurchaseOrder({
    required int? supplierId,
    required int warehouseId,
    required List<Map<String, dynamic>> items,
    num? paidAmount,
    bool autoReceive = true,
    String? notes,
    bool refreshRelatedProviders = true,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final payload = <String, dynamic>{
        'supplier_id': supplierId,
        'warehouse_id': warehouseId,
        'items': items,
        'paid_amount': paidAmount ?? 0,
        'auto_receive': autoReceive,
        'notes': notes,
      };

      final response = await apiClient.client.post(
        '/purchase-orders',
        data: payload,
      );

      final order = _purchaseOrderFromApiResponse(
        response,
        apiClient,
        defaultError: 'کێشە لە دروستکردنی پسوڵەی کڕین',
      );
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);

      if (refreshRelatedProviders) {
        if (_ref.exists(purchaseRequirementsProvider)) {
          unawaited(_ref.read(purchaseRequirementsProvider.notifier).refreshSilently());
        }
        if (_ref.exists(purchaseRequirementsGroupProvider)) {
          unawaited(_ref.read(purchaseRequirementsGroupProvider.notifier).refreshSilently());
        }
        unawaited(
          _ref.read(productsListProvider.notifier).refreshProductsSilently(),
        );
        if (_ref.exists(suppliersListProvider)) {
          unawaited(_ref.read(suppliersListProvider.notifier).refreshSilently());
        }
      }

      return order;
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<PurchaseOrderModel> updatePurchaseOrder({
    required int orderId,
    int? supplierId,
    bool includeNullSupplierId = false,
    int? warehouseId,
    List<Map<String, dynamic>>? items,
    num? paidAmount,
    bool? autoReceive,
    String? notes,
    bool refreshRelatedProviders = true,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final payload = <String, dynamic>{
        if (supplierId != null || includeNullSupplierId)
          'supplier_id': supplierId,
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (items != null) 'items': items,
        if (paidAmount != null) 'paid_amount': paidAmount,
        if (autoReceive != null) 'auto_receive': autoReceive,
        if (notes != null) 'notes': notes,
      };

      final response = await apiClient.client.put(
        '/purchase-orders/$orderId',
        data: payload,
      );

      final order = _purchaseOrderFromApiResponse(
        response,
        apiClient,
        defaultError: 'کێشە لە نوێکردنەوەی پسوڵەی کڕین',
      );
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);

      if (refreshRelatedProviders) {
        if (_ref.exists(purchaseRequirementsProvider)) {
          unawaited(_ref.read(purchaseRequirementsProvider.notifier).refreshSilently());
        }
        if (_ref.exists(purchaseRequirementsGroupProvider)) {
          unawaited(_ref.read(purchaseRequirementsGroupProvider.notifier).refreshSilently());
        }
        unawaited(
          _ref.read(productsListProvider.notifier).refreshProductsSilently(),
        );
        if (_ref.exists(suppliersListProvider)) {
          unawaited(_ref.read(suppliersListProvider.notifier).refreshSilently());
        }
      }

      return order;
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> deletePurchaseOrder(int orderId) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final response = await apiClient.client.delete('/purchase-orders/$orderId');
      if (!_isSuccessStatus(response.statusCode)) {
        throw Exception(
          apiClient.extractErrorMessage(
            response.data,
            defaultMsg: 'کێشە لە سڕینەوەی پسوڵەی کڕین',
          ),
        );
      }
      _ref.read(purchaseOrdersProvider.notifier).removeOrderLocally(orderId);
      if (_ref.exists(purchaseRequirementsProvider)) {
        unawaited(_ref.read(purchaseRequirementsProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> convertRequirementsToPO({
    required List<int> requirementIds,
    List<Map<String, dynamic>>? requirementItems,
    List<Map<String, dynamic>>? additionalItems,
    String? notes,
    String? idempotencyKey,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final sortedIds = List<int>.from(requirementIds)..sort();
      final payload = <String, dynamic>{'notes': notes};
      if (requirementItems != null) {
        payload['requirement_items'] = requirementItems;
      } else {
        payload['requirement_ids'] = sortedIds;
      }
      if (additionalItems != null && additionalItems.isNotEmpty) {
        payload['additional_items'] = additionalItems;
      }
      final key = idempotencyKey ??
          'convert_${_deterministicHash(jsonEncode(payload))}';

      final response = await apiClient.client.post(
        '/purchase-requirements/convert',
        data: payload,
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      final resData = response.data;
      if (!_isSuccessStatus(response.statusCode)) {
        throw Exception(
          apiClient.extractErrorMessage(
            resData,
            defaultMsg: 'کێشە لە گۆڕینی داواکارییەکان بۆ پسوڵەی کڕین',
          ),
        );
      }
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed created purchase orders response payload)',
        );
      }
      for (final orderData in resData['data'] as List) {
        if (orderData is! Map) {
          throw FormatException(
            'داتای پسوڵەی کڕین لە وەڵامی سێرڤەر نادروستە',
          );
        }
        _ref
            .read(purchaseOrdersProvider.notifier)
            .upsertOrderLocally(
              PurchaseOrderModel.fromJson(
                Map<String, dynamic>.from(orderData),
              ),
            );
      }
      if (_ref.exists(purchaseRequirementsProvider)) {
        unawaited(_ref.read(purchaseRequirementsProvider.notifier).refreshSilently());
      }
      if (_ref.exists(purchaseRequirementsGroupProvider)) {
        unawaited(_ref.read(purchaseRequirementsGroupProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> confirmPurchaseOrder(int orderId, {String? idempotencyKey}) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final key = idempotencyKey ?? 'confirm_po_$orderId';
      final response = await apiClient.client.post(
        '/purchase-orders/$orderId/confirm',
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      final order = _purchaseOrderFromApiResponse(
        response,
        apiClient,
        defaultError: 'کێشە لە پەسەندکردنی پسوڵەی کڕین',
      );
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> receivePurchaseOrder(int orderId, {List<Map<String, dynamic>>? items}) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final payload = <String, dynamic>{};
      if (items != null && items.isNotEmpty) {
        payload['items'] = items;
      }
      final key = 'receive_po_${orderId}_${DateTime.now().microsecondsSinceEpoch}';
      final response = await apiClient.client.post(
        '/purchase-orders/$orderId/receive',
        data: payload,
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      final order = _purchaseOrderFromApiResponse(
        response,
        apiClient,
        defaultError: 'کێشە لە وەرگرتنی کاڵاکانی پسوڵەی کڕین',
      );
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> cancelPurchaseOrder(int orderId, {String? idempotencyKey}) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final key = idempotencyKey ?? 'cancel_po_$orderId';
      final cancelResponse = await apiClient.client.post(
        '/purchase-orders/$orderId/cancel',
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      if (!_isSuccessStatus(cancelResponse.statusCode)) {
        throw Exception(
          apiClient.extractErrorMessage(
            cancelResponse.data,
            defaultMsg: 'کێشە لە هەڵوەشاندنەوەی پسوڵەی کڕین',
          ),
        );
      }
      final response = await apiClient.client.get(
        '/purchase-orders/$orderId',
      );
      final order = _purchaseOrderFromApiResponse(
        response,
        apiClient,
        defaultError: 'کێشە لە خوێندنەوەی پسوڵەی هەڵوەشاوە',
      );
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);
      if (_ref.exists(purchaseRequirementsProvider)) {
        unawaited(_ref.read(purchaseRequirementsProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }
}

bool _isSuccessStatus(int? statusCode) {
  return statusCode != null && statusCode >= 200 && statusCode < 300;
}

PurchaseOrderModel _purchaseOrderFromApiResponse(
  Response<dynamic> response,
  ApiClient apiClient, {
  required String defaultError,
}) {
  final responseData = response.data;
  if (!_isSuccessStatus(response.statusCode)) {
    throw Exception(
      apiClient.extractErrorMessage(
        responseData,
        defaultMsg: defaultError,
      ),
    );
  }
  if (responseData is! Map || responseData['data'] is! Map) {
    final extracted = apiClient.extractErrorMessage(
      responseData,
      defaultMsg: '',
    );
    throw FormatException(
      extracted.isNotEmpty
          ? extracted
          : 'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed purchase order response payload)',
    );
  }
  return PurchaseOrderModel.fromJson(
    Map<String, dynamic>.from(responseData['data'] as Map),
  );
}

String _deterministicHash(String input) {
  final bytes = utf8.encode(input);
  // FNV-1a 32-bit
  int fnvHash = 2166136261;
  for (final byte in bytes) {
    fnvHash ^= byte;
    fnvHash = (fnvHash * 16777619) & 0xFFFFFFFF;
  }

  // DJB2 hash
  int djbHash = 5381;
  for (final byte in bytes) {
    djbHash = ((djbHash << 5) + djbHash) + byte;
    djbHash = djbHash & 0xFFFFFFFF;
  }

  final fnvHex = fnvHash.toRadixString(16).padLeft(8, '0');
  final djbHex = djbHash.toRadixString(16).padLeft(8, '0');
  return '$fnvHex$djbHex';
}
