import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/sync/pusher_service.dart';
import '../../admin/views/providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../salesman/providers/salesman_dashboard_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../shared/models/customer.dart';
import '../../shared/providers/customer_provider.dart';
import '../models/order_model.dart';

class OrdersListNotifier extends AsyncNotifier<List<OrderModel>> {
  final Set<int> _fetchingOrderIds = {};
  final Set<int> _pendingRefetchOrderIds = {};
  final Map<int, DateTime> _deletedAtByOrderId = {};
  bool _isRefreshingAll = false;
  bool _pendingRefreshAll = false;

  void _pruneDeletedCache() {
    if (_deletedAtByOrderId.isEmpty) return;
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    _deletedAtByOrderId.removeWhere((_, deletedAt) => deletedAt.isBefore(cutoff));
  }

  bool _wasDeletedSince(int orderId, DateTime fetchStartedAt) {
    final deletedAt = _deletedAtByOrderId[orderId];
    if (deletedAt == null) return false;
    return !deletedAt.isBefore(fetchStartedAt);
  }

  @override
  FutureOr<List<OrderModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onOrdersEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received on private-orders channel: $eventData",
      );
      _handleOrdersRealtimeEvent(eventData);
    }

    pusher.subscribeToChannel('private-orders', onOrdersEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    // Keep customer details (name, phone, address, balance, price_type) inside loaded orders synced
    ref.listen<AsyncValue<PaginatedResponse<Customer>>>(
      filteredCustomerListProvider(defaultCustomerDirectoryFilters),
      (prev, next) {
        final prevData = prev?.valueOrNull?.data;
        final nextData = next.valueOrNull?.data;
        if (prevData == null || nextData == null) return;
        final prevById = {for (final c in prevData) c.id: c};
        for (final c in nextData) {
          final old = prevById[c.id];
          if (old == null ||
              old.name != c.name ||
              old.phone != c.phone ||
              old.address != c.address ||
              old.balance != c.balance ||
              old.priceType != c.priceType ||
              old.permanentDiscount != c.permanentDiscount ||
              old.specialPrices.length != c.specialPrices.length) {
            patchCustomerOnOrdersLocally(c);
          }
        }
      },
    );

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-orders', onOrdersEvent);
    });

    return _fetchOrders(api);
  }

  void _handleOrdersRealtimeEvent(Map<String, dynamic> eventData) {
    final eventType = eventData['event_type']?.toString();
    final orderId = int.tryParse(
      (eventData['sales_order_id'] ?? eventData['order_id'] ?? eventData['id'])
              ?.toString() ??
          '',
    );

    if (orderId == null || orderId <= 0) {
      unawaited(refreshSilently());
      return;
    }

    if (eventType == 'delete') {
      removeOrderLocally(orderId.toString());
      if (ref.exists(singleOrderProvider(orderId.toString()))) {
        ref
            .read(singleOrderProvider(orderId.toString()).notifier)
            .setOrderLocally(null);
      }
      return;
    }

    final eventStatus = eventData['status']?.toString().toUpperCase();
    unawaited(_fetchAndPatchSingleOrder(orderId, eventStatus: eventStatus));
  }

  Future<void> _fetchAndPatchSingleOrder(
    int orderId, {
    String? eventStatus,
  }) async {
    if (_fetchingOrderIds.contains(orderId)) {
      _pendingRefetchOrderIds.add(orderId);
      return;
    }
    _fetchingOrderIds.add(orderId);
    final fetchStartedAt = DateTime.now();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.client.get('/orders/$orderId');
      if (_wasDeletedSince(orderId, fetchStartedAt)) {
        return;
      }
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        if (data is! Map) return;

        final fetched = OrderModel.fromJson(Map<String, dynamic>.from(data));
        final user = ref.read(authProvider).user;
        final currentOrders = state.valueOrNull;

        // Non-customer /orders index hides customer portal DRAFT orders unless already tracked
        if (user != null &&
            !user.isCustomer &&
            fetched.status.toUpperCase() == OrderModel.statusDraft) {
          final alreadyExists =
              currentOrders?.any((o) => o.id == fetched.id) ?? false;
          if (!alreadyExists) return;
        }

        upsertOrderLocally(fetched);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403 || code == 404) {
        final user = ref.read(authProvider).user;
        // Drivers get 403 on /orders/{id} for unassigned READY orders; refresh silently in that edge case
        if (code == 403 &&
            user != null &&
            user.isDriver &&
            eventStatus == OrderModel.statusReady) {
          unawaited(refreshSilently());
        } else {
          removeOrderLocally(orderId.toString());
          if (code == 404 &&
              ref.exists(singleOrderProvider(orderId.toString()))) {
            ref
                .read(singleOrderProvider(orderId.toString()).notifier)
                .setOrderLocally(null);
          }
        }
      }
    } catch (_) {
      // Ignore transient errors silently
    } finally {
      _fetchingOrderIds.remove(orderId);
      if (_pendingRefetchOrderIds.remove(orderId)) {
        unawaited(
          _fetchAndPatchSingleOrder(orderId, eventStatus: eventStatus),
        );
      }
    }
  }

  Future<void> refreshSingleOrder(int orderId) async {
    if (orderId <= 0) return;
    await _fetchAndPatchSingleOrder(orderId);
  }

  Future<List<OrderModel>> _fetchOrders(ApiClient api) async {
    final fetchStartedAt = DateTime.now();
    final response = await api.client.get('/orders');
    if (response.statusCode == 200) {
      final resData = response.data['data'] ?? response.data;
      if (resData is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response payload)',
        );
      }
      final List data = resData;
      _pruneDeletedCache();
      final Map<int, OrderModel> uniqueMap = {};
      for (final json in data) {
        if (json is Map) {
          final ord = OrderModel.fromJson(Map<String, dynamic>.from(json));
          if (!_wasDeletedSince(ord.id, fetchStartedAt)) {
            uniqueMap[ord.id] = ord;
          }
        }
      }
      final onlineOrders = uniqueMap.values.toList();

      onlineOrders.sort((a, b) {
        final aDate =
            DateTime.tryParse(a.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse(b.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return onlineOrders;
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  }

  bool _sameOrderData(OrderModel a, OrderModel b) {
    if (a.id != b.id ||
        a.orderNumber != b.orderNumber ||
        a.sharedKey != b.sharedKey ||
        a.version != b.version ||
        a.customerId != b.customerId ||
        a.salesmanId != b.salesmanId ||
        a.warehouseId != b.warehouseId ||
        a.subtotal != b.subtotal ||
        a.permanentDiscountPercent != b.permanentDiscountPercent ||
        a.permanentDiscountAmount != b.permanentDiscountAmount ||
        a.discountAmount != b.discountAmount ||
        a.discountPercent != b.discountPercent ||
        a.discountType != b.discountType ||
        a.totalAmount != b.totalAmount ||
        a.totalProfit != b.totalProfit ||
        a.status != b.status ||
        a.notes != b.notes ||
        a.createdAt != b.createdAt ||
        a.priceType != b.priceType ||
        a.customerName != b.customerName ||
        a.customerAddress != b.customerAddress) {
      return false;
    }

    if (a.customer is Map && b.customer is Map) {
      final am = a.customer as Map;
      final bm = b.customer as Map;
      if (am['current_balance']?.toString() != bm['current_balance']?.toString() ||
          am['price_type']?.toString() != bm['price_type']?.toString() ||
          am['phone']?.toString() != bm['phone']?.toString()) {
        return false;
      }
    }

    if (a.items.length != b.items.length) return false;
    for (int i = 0; i < a.items.length; i++) {
      final ai = a.items[i];
      final bi = b.items[i];
      if (ai.id != bi.id ||
          ai.productId != bi.productId ||
          ai.productName != bi.productName ||
          ai.quantity != bi.quantity ||
          ai.unitPrice != bi.unitPrice ||
          ai.subtotal != bi.subtotal ||
          ai.isPacked != bi.isPacked ||
          ai.notes != bi.notes ||
          ai.priceType != bi.priceType) {
        return false;
      }
    }

    if (a.returnedItems.length != b.returnedItems.length) return false;
    for (int i = 0; i < a.returnedItems.length; i++) {
      final ar = a.returnedItems[i];
      final br = b.returnedItems[i];
      if (ar.id != br.id ||
          ar.productId != br.productId ||
          ar.quantity != br.quantity ||
          ar.unitPrice != br.unitPrice ||
          ar.subtotal != br.subtotal ||
          ar.reason != br.reason) {
        return false;
      }
    }

    return true;
  }

  Future<void> refreshSilently() async {
    if (_isRefreshingAll) {
      _pendingRefreshAll = true;
      return;
    }
    _isRefreshingAll = true;
    final api = ref.read(apiClientProvider);
    try {
      final freshOrders = await _fetchOrders(api);
      final current = state.valueOrNull;
      if (current != null && current.length == freshOrders.length) {
        bool allSame = true;
        for (int i = 0; i < freshOrders.length; i++) {
          if (!_sameOrderData(current[i], freshOrders[i])) {
            allSame = false;
            break;
          }
        }
        if (allSame) return;
      }
      state = AsyncData(freshOrders);
    } catch (_) {
      // Maintain current state on transient errors
    } finally {
      _isRefreshingAll = false;
      if (_pendingRefreshAll) {
        _pendingRefreshAll = false;
        unawaited(refreshSilently());
      }
    }
  }

  void patchCustomerOnOrdersLocally(Customer customer) {
    final currentOrders = state.valueOrNull;
    if (currentOrders == null || currentOrders.isEmpty) return;

    bool anyUpdated = false;
    final updated = currentOrders.map((o) {
      if (o.customerId != customer.id) return o;
      final existingCustomerMap = o.customer is Map
          ? Map<String, dynamic>.from(o.customer as Map)
          : <String, dynamic>{};
      final mergedCustomer = {
        ...existingCustomerMap,
        ...customer.toJson(),
      };
      anyUpdated = true;
      return o.copyWith(customer: mergedCustomer);
    }).toList();

    if (anyUpdated) {
      state = AsyncData(updated);
    }
  }

  void removeOrderLocally(String orderId) {
    final parsedId = int.tryParse(orderId);
    if (parsedId != null && parsedId > 0) {
      _pruneDeletedCache();
      _deletedAtByOrderId[parsedId] = DateTime.now();
      _pendingRefetchOrderIds.remove(parsedId);
    }

    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      final existed = currentOrders.any((o) => o.id.toString() == orderId);
      if (!existed) return;
      final updated = currentOrders
          .where((o) => o.id.toString() != orderId)
          .toList();
      state = AsyncData(updated);
    }
  }

  void updateOrderStatusLocally(String orderId, String newStatus) {
    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      bool changed = false;
      final updated = currentOrders.map((o) {
        if (o.id.toString() == orderId && o.status != newStatus) {
          changed = true;
          return o.copyWith(status: newStatus);
        }
        return o;
      }).toList();
      if (changed) {
        state = AsyncData(updated);
      }
    }
  }

  void upsertOrderLocally(OrderModel newOrder) {
    final singleKey = newOrder.id.toString();
    if (ref.exists(singleOrderProvider(singleKey))) {
      final existingSingle = ref.read(singleOrderProvider(singleKey)).valueOrNull;
      if (existingSingle == null || !_sameOrderData(existingSingle, newOrder)) {
        ref.read(singleOrderProvider(singleKey).notifier).setOrderLocally(newOrder);
      }
    }

    final currentOrders = state.valueOrNull;
    if (currentOrders == null) {
      state = AsyncData([newOrder]);
      return;
    }

    final existingIndex = currentOrders.indexWhere((o) => o.id == newOrder.id);
    if (existingIndex != -1 &&
        _sameOrderData(currentOrders[existingIndex], newOrder)) {
      return;
    }

    final updated = List<OrderModel>.from(currentOrders);
    if (existingIndex != -1) {
      updated[existingIndex] = newOrder;
    } else {
      updated.add(newOrder);
      updated.sort((a, b) {
        final aDate =
            DateTime.tryParse(a.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse(b.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    }
    state = AsyncData(updated);
  }

  void restoreState(List<OrderModel> previousOrders) {
    for (final order in previousOrders) {
      _deletedAtByOrderId.remove(order.id);
    }
    state = AsyncData(previousOrders);
  }
}

final ordersListProvider =
    AsyncNotifierProvider<OrdersListNotifier, List<OrderModel>>(
      OrdersListNotifier.new,
    );

class SingleOrderNotifier extends FamilyAsyncNotifier<OrderModel?, String> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<OrderModel?> build(String arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return null;
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    final parsedId = int.tryParse(arg);

    // Subscribe to Pusher channel when this provider is active for real-time updates
    if (parsedId != null && parsedId > 0) {
      void onOrderEvent(Map<String, dynamic> eventData) {
        debugPrint("Realtime update for order $arg: $eventData");
        final eventType = eventData['event_type']?.toString();
        if (eventType == 'delete') {
          state = const AsyncData(null);
          ref.read(ordersListProvider.notifier).removeOrderLocally(arg);
          return;
        }
        unawaited(refreshSilently());
      }

      pusher.subscribeToOrder(parsedId, onOrderEvent);
      final reconnectSub = pusher.onReconnected.listen((_) {
        unawaited(refreshSilently());
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromOrder(parsedId, onOrderEvent);
      });
    }

    return _fetchSingleOrder(api, arg);
  }

  Future<OrderModel?> _fetchSingleOrder(ApiClient api, String orderId) async {
    try {
      final response = await api.client.get('/orders/$orderId');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        if (data is! Map) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response payload)',
          );
        }
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          return null;
        }
        throw Exception(api.parseError(e));
      }
      rethrow;
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
      final fresh = await _fetchSingleOrder(api, arg);
      state = AsyncData(fresh);
      if (fresh != null) {
        ref.read(ordersListProvider.notifier).upsertOrderLocally(fresh);
      } else {
        ref.read(ordersListProvider.notifier).removeOrderLocally(arg);
      }
    } catch (_) {
      // Preserve current order state on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }

  void setOrderLocally(OrderModel? order) {
    state = AsyncData(order);
  }
}

final singleOrderProvider =
    AsyncNotifierProvider.family<SingleOrderNotifier, OrderModel?, String>(
      SingleOrderNotifier.new,
    );

final customerOrdersProvider = FutureProvider.family<List<OrderModel>, int>((
  ref,
  customerId,
) async {
  final orders = await ref.watch(ordersListProvider.future);
  return orders.where((order) => order.customerId == customerId).toList();
});

final orderActionsProvider = Provider<OrderActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return OrderActions(api, ref);
});

class OrderActions {
  final ApiClient api;
  final Ref ref;

  OrderActions(this.api, this.ref);

  void _refreshSalesmanDashboard() {
    final user = ref.read(authProvider).user;
    if (user == null || user.isCustomer) return;
    unawaited(
      ref.read(salesmanDashboardProvider.notifier).refreshSilently(),
    );
  }

  Future<OrderModel> createOrder(Map<String, dynamic> data) async {
    try {
      final idempotencyKey =
          data['idempotency_key'] ??
          'create_order_${DateTime.now().microsecondsSinceEpoch}';

      final response = await api.client.post(
        '/orders',
        data: data,
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey}),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        final errorMsg = api.extractErrorMessage(
          response.data,
          defaultMsg: 'هەڵە لە دروستکردنی پسوڵە',
        );
        throw Exception(errorMsg);
      }

      _refreshSalesmanDashboard();

      final resData = response.data;
      final orderData = (resData is Map && resData.containsKey('data'))
          ? resData['data']
          : resData;

      if (orderData is Map &&
          orderData['id'] != null &&
          (int.tryParse(orderData['id'].toString()) ?? 0) > 0) {
        final orderMap = Map<String, dynamic>.from(orderData);
        final newOrder = OrderModel.fromJson(orderMap);
        ref.read(ordersListProvider.notifier).upsertOrderLocally(newOrder);
        ref.read(productsListProvider.notifier).patchProductsFromOrderData(orderMap);
        if (data.containsKey('returned_items')) {
          ref.invalidate(salesReturnsListProvider);
        }
        if (newOrder.customerId > 0) {
          unawaited(
            ref
                .read(customerActionsProvider)
                .refreshSingleCustomerEverywhere(newOrder.customerId),
          );
        }
        ref.invalidate(dashboardProvider);
        return newOrder;
      }

      throw FormatException('داتای دروستکراوی پسوڵە نادروستە');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<OrderModel> updateOrder(int orderId, Map<String, dynamic> data) async {
    try {
      final idempotencyKey =
          data['idempotency_key'] ??
          'update_order_${orderId}_${DateTime.now().microsecondsSinceEpoch}';

      final response = await api.client.put(
        '/orders/$orderId',
        data: data,
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey}),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        final errorMsg = api.extractErrorMessage(
          response.data,
          defaultMsg: 'هەڵە لە پاشەکەوتکردنی پسوڵە',
        );
        throw Exception(errorMsg);
      }

      _refreshSalesmanDashboard();

      final resData = response.data;
      final orderData = (resData is Map && resData.containsKey('data'))
          ? resData['data']
          : resData;

      if (orderData is Map &&
          orderData['id'] != null &&
          (int.tryParse(orderData['id'].toString()) ?? 0) > 0) {
        final orderMap = Map<String, dynamic>.from(orderData);
        final updatedOrder = OrderModel.fromJson(orderMap);
        // Update this single order locally in both list and detail providers without wiping UI
        ref.read(ordersListProvider.notifier).upsertOrderLocally(updatedOrder);
        ref
            .read(singleOrderProvider(orderId.toString()).notifier)
            .setOrderLocally(updatedOrder);

        // Patch only the products whose stock changed in this order
        ref.read(productsListProvider.notifier).patchProductsFromOrderData(orderMap);
        if (data.containsKey('returned_items')) {
          ref.invalidate(salesReturnsListProvider);
        }

        return updatedOrder;
      }

      throw FormatException('داتای نوێکراوەی پسوڵە نادروستە');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    Map<String, dynamic> extraData = const {},
  }) async {
    final previousOrders = ref.read(ordersListProvider).valueOrNull;
    final parsedId = int.tryParse(orderId);
    final existingOrder = previousOrders
        ?.where((o) => o.id.toString() == orderId)
        .firstOrNull;

    ref
        .read(ordersListProvider.notifier)
        .updateOrderStatusLocally(orderId, newStatus);

    try {
      final idempotencyKey =
          'status_order_${orderId}_${DateTime.now().microsecondsSinceEpoch}';

      final response = await api.client.post(
        '/orders/$orderId/status',
        data: {'status': newStatus, ...extraData},
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey}),
      );
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      final resData = response.data;
      final orderData = (resData is Map && resData.containsKey('data'))
          ? resData['data']
          : null;
      if (orderData is Map && orderData['id'] != null) {
        final orderMap = Map<String, dynamic>.from(orderData);
        final updated = OrderModel.fromJson(orderMap);
        ref.read(ordersListProvider.notifier).upsertOrderLocally(updated);
        ref
            .read(singleOrderProvider(orderId).notifier)
            .setOrderLocally(updated);
        ref.read(productsListProvider.notifier).patchProductsFromOrderData(orderMap);
        if (updated.customerId > 0) {
          unawaited(
            ref
                .read(customerActionsProvider)
                .refreshSingleCustomerEverywhere(updated.customerId),
          );
        }
      } else if (parsedId != null) {
        await ref.read(ordersListProvider.notifier).refreshSingleOrder(parsedId);
        unawaited(
          ref.read(singleOrderProvider(orderId).notifier).refreshSilently(),
        );
        if (existingOrder != null && existingOrder.customerId > 0) {
          unawaited(
            ref
                .read(customerActionsProvider)
                .refreshSingleCustomerEverywhere(existingOrder.customerId),
          );
        }
      }

      _refreshSalesmanDashboard();
    } catch (e) {
      if (previousOrders != null) {
        ref.read(ordersListProvider.notifier).restoreState(previousOrders);
      } else if (parsedId != null) {
        unawaited(
          ref.read(ordersListProvider.notifier).refreshSingleOrder(parsedId),
        );
      }
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final previousList = ref.read(ordersListProvider).valueOrNull;
    final deletedOrder = previousList
        ?.where((o) => o.id.toString() == orderId)
        .firstOrNull;

    // 1. Optimistically remove from local state immediately
    ref.read(ordersListProvider.notifier).removeOrderLocally(orderId);
    ref.read(singleOrderProvider(orderId).notifier).setOrderLocally(null);

    try {
      // 2. Call backend API
      final response = await api.client.delete('/orders/$orderId');
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      // 3. Patch affected products and customer silently (Pusher also broadcasts released stock)
      if (deletedOrder != null) {
        for (final item in deletedOrder.items) {
          unawaited(
            ref
                .read(productsListProvider.notifier)
                .refreshSingleProduct(item.productId),
          );
        }
        if (deletedOrder.customerId > 0) {
          unawaited(
            ref
                .read(customerActionsProvider)
                .refreshSingleCustomerEverywhere(deletedOrder.customerId),
          );
        }
      }
      _refreshSalesmanDashboard();
      ref.invalidate(dashboardProvider);
    } catch (e) {
      // Restore state on failure
      if (previousList != null) {
        ref.read(ordersListProvider.notifier).restoreState(previousList);
      }
      throw Exception(api.parseError(e));
    }
  }
}

final salesReturnsListProvider = FutureProvider<List<dynamic>>((ref) async {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return const [];
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onSalesReturnsEvent(Map<String, dynamic> eventData) {
    final eventType = eventData['event_type']?.toString();
    if (eventType == 'return_created' || eventType == 'delete') {
      debugPrint(
        "Realtime return update received on private-orders channel: $eventData",
      );
      ref.invalidateSelf();
    }
  }

  pusher.subscribeToChannel('private-orders', onSalesReturnsEvent);
  final reconnectSub = pusher.onReconnected.listen((_) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    reconnectSub.cancel();
    pusher.unsubscribeFromChannel('private-orders', onSalesReturnsEvent);
  });

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
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return null;
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onReturnDetailEvent(Map<String, dynamic> eventData) {
    if (eventData['event_type']?.toString() == 'return_created') {
      ref.invalidateSelf();
    }
  }

  pusher.subscribeToChannel('private-orders', onReturnDetailEvent);
  final reconnectSub = pusher.onReconnected.listen((_) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    reconnectSub.cancel();
    pusher.unsubscribeFromChannel('private-orders', onReturnDetailEvent);
  });

  try {
    final response = await api.client.get('/sales-returns/$id');
    if (response.statusCode == 200) {
      final resData = response.data;
      final data = (resData is Map && resData.containsKey('data'))
          ? resData['data']
          : resData;
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
  final ApiClient api;
  final Ref ref;

  SalesReturnActions(this.api, this.ref);

  Future<void> createSalesReturn(Map<String, dynamic> data) async {
    final String returnEntityId =
        data['idempotency_key'] ??
        'return_${DateTime.now().microsecondsSinceEpoch}';

    final payload = Map<String, dynamic>.from(data)
      ..['idempotency_key'] = returnEntityId;

    try {
      await api.client.post(
        '/sales-returns',
        data: payload,
        options: Options(headers: {'X-Idempotency-Key': returnEntityId}),
      );

      final orderIdStr = payload['sales_order_id']?.toString();
      final orderId = int.tryParse(orderIdStr ?? '');
      if (orderId != null && orderId > 0) {
        unawaited(
          ref.read(ordersListProvider.notifier).refreshSingleOrder(orderId),
        );
        unawaited(
          ref
              .read(singleOrderProvider(orderIdStr!).notifier)
              .refreshSilently(),
        );
      }
      final customerId = int.tryParse(
        payload['customer_id']?.toString() ?? '',
      );
      if (customerId != null && customerId > 0) {
        unawaited(
          ref
              .read(customerActionsProvider)
              .refreshSingleCustomerEverywhere(customerId),
        );
      }
      ref.invalidate(salesReturnsListProvider);
      unawaited(ref.read(salesmanDashboardProvider.notifier).refreshSilently());
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}

final salesReturnActionsProvider = Provider<SalesReturnActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return SalesReturnActions(api, ref);
});

/// پسوڵە ئامادەکراوەکان بۆ دابەشکردن و دروستکردنی گەشتی شۆفێر
/// تەنها ئەو پسوڵانە دەگرێتەوە کە لە دۆخی READY دان
final readyOrdersForDeliveryProvider = FutureProvider<List<OrderModel>>((
  ref,
) async {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return const [];

  final orders = await ref.watch(ordersListProvider.future);
  return orders
      .where((order) => order.status.toUpperCase() == OrderModel.statusReady)
      .toList();
});

class AdminOrderFilterState {
  final String searchQuery;
  final int? customerId;
  final int? salesmanId;
  final DateTime? startDate;
  final DateTime? endDate;

  const AdminOrderFilterState({
    this.searchQuery = '',
    this.customerId,
    this.salesmanId,
    this.startDate,
    this.endDate,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      customerId != null ||
      salesmanId != null ||
      startDate != null ||
      endDate != null;

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (customerId != null) count++;
    if (salesmanId != null) count++;
    if (startDate != null || endDate != null) count++;
    return count;
  }

  AdminOrderFilterState copyWith({
    String? searchQuery,
    int? customerId,
    int? salesmanId,
    DateTime? startDate,
    DateTime? endDate,
    bool clearCustomer = false,
    bool clearSalesman = false,
    bool clearDates = false,
    bool clearSearch = false,
  }) {
    return AdminOrderFilterState(
      searchQuery: clearSearch ? '' : (searchQuery ?? this.searchQuery),
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      salesmanId: clearSalesman ? null : (salesmanId ?? this.salesmanId),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }
}

final adminOrderFilterProvider = StateProvider<AdminOrderFilterState>(
  (ref) => const AdminOrderFilterState(),
);

List<OrderModel> applyAdminOrderFilters({
  required List<OrderModel> orders,
  required String tabFilter,
  required AdminOrderFilterState filterState,
}) {
  List<OrderModel> result = orders;

  // 1. Tab filter
  if (tabFilter == 'لە گەیاندن') {
    result = result
        .where((o) => o.status == 'IN_DELIVERY' || o.status == 'CONFIRMED')
        .toList();
  } else if (tabFilter == 'گەیشتووە') {
    result = result.where((o) => o.status == 'DELIVERED').toList();
  }

  // 2. Customer filter
  if (filterState.customerId != null) {
    result = result
        .where((o) => o.customerId == filterState.customerId)
        .toList();
  }

  // 3. Salesman filter
  if (filterState.salesmanId != null) {
    result = result
        .where((o) => o.salesmanId == filterState.salesmanId)
        .toList();
  }

  // 4. Start date filter
  if (filterState.startDate != null) {
    final startDay = DateTime(
      filterState.startDate!.year,
      filterState.startDate!.month,
      filterState.startDate!.day,
    );
    result = result.where((o) {
      final parsed = DateTime.tryParse(o.createdAt);
      if (parsed == null) return true;
      final orderDay = DateTime(parsed.year, parsed.month, parsed.day);
      return !orderDay.isBefore(startDay);
    }).toList();
  }

  // 5. End date filter
  if (filterState.endDate != null) {
    final endDay = DateTime(
      filterState.endDate!.year,
      filterState.endDate!.month,
      filterState.endDate!.day,
    );
    result = result.where((o) {
      final parsed = DateTime.tryParse(o.createdAt);
      if (parsed == null) return true;
      final orderDay = DateTime(parsed.year, parsed.month, parsed.day);
      return !orderDay.isAfter(endDay);
    }).toList();
  }

  // 6. Search query filter
  if (filterState.searchQuery.trim().isNotEmpty) {
    final q = filterState.searchQuery.trim().toLowerCase();
    result = result.where((o) {
      final orderNum = o.orderNumber.toLowerCase();
      final customerName = o.customer is Map && o.customer['name'] != null
          ? o.customer['name'].toString().toLowerCase()
          : '';
      final salesmanName = o.salesman is Map && o.salesman['name'] != null
          ? o.salesman['name'].toString().toLowerCase()
          : '';
      return orderNum.contains(q) ||
          customerName.contains(q) ||
          salesmanName.contains(q);
    }).toList();
  }

  return result;
}
