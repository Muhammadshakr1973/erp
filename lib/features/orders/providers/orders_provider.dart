import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../admin/views/providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../salesman/providers/salesman_dashboard_provider.dart';
import '../../shared/providers/customer_provider.dart';
import '../models/order_model.dart';

class OrdersListNotifier extends AsyncNotifier<List<OrderModel>> {
  @override
  FutureOr<List<OrderModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onOrdersEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received on private-orders channel: $eventData");
      refreshSilently();
    }

    pusher.subscribeToChannel('private-orders', onOrdersEvent);

    ref.onDispose(() {
      pusher.unsubscribeFromChannel('private-orders', onOrdersEvent);
    });

    return _fetchOrders(api);
  }

  Future<List<OrderModel>> _fetchOrders(ApiClient api) async {
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

      onlineOrders.sort((a, b) {
        final aDate = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return onlineOrders;
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  }

  Future<void> refreshSilently() async {
    final api = ref.read(apiClientProvider);
    try {
      final freshOrders = await _fetchOrders(api);
      state = AsyncData(freshOrders);
    } catch (_) {
      // Maintain current state on transient errors
    }
  }

  void removeOrderLocally(String orderId) {
    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      final updated = currentOrders.where((o) => o.id.toString() != orderId).toList();
      state = AsyncData(updated);
    }
  }

  void updateOrderStatusLocally(String orderId, String newStatus) {
    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      final updated = currentOrders.map((o) {
        if (o.id.toString() == orderId) {
          return o.copyWith(status: newStatus);
        }
        return o;
      }).toList();
      state = AsyncData(updated);
    }
  }

  void upsertOrderLocally(OrderModel newOrder) {
    final currentOrders = state.valueOrNull ?? [];
    final index = currentOrders.indexWhere((o) => o.id == newOrder.id);
    List<OrderModel> updated;
    if (index >= 0) {
      updated = List.from(currentOrders)..[index] = newOrder;
    } else {
      updated = [newOrder, ...currentOrders];
    }
    state = AsyncData(updated);
  }

  void restoreState(List<OrderModel> previousOrders) {
    state = AsyncData(previousOrders);
  }
}

final ordersListProvider =
    AsyncNotifierProvider<OrdersListNotifier, List<OrderModel>>(
  OrdersListNotifier.new,
);

final singleOrderProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  orderId,
) async {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return null;
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  final parsedId = int.tryParse(orderId);

  // Subscribe to Pusher channel when this provider is active for real-time updates
  if (parsedId != null && parsedId > 0) {
    void onOrderEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update for order $orderId: $eventData");
      ref.invalidateSelf();
      ref.invalidate(ordersListProvider);
    }

    pusher.subscribeToOrder(parsedId, onOrderEvent);

    ref.onDispose(() {
      pusher.unsubscribeFromOrder(parsedId, onOrderEvent);
    });
  }

  try {
    final response = await api.client.get('/orders/$orderId');
    if (response.statusCode == 200) {
      final data = response.data['data'] ?? response.data;
      if (data is! Map) {
        throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response payload)');
      }
      return OrderModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
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
  final api = ref.watch(apiClientProvider);
  return OrderActions(api, ref);
});

class OrderActions {
  final ApiClient api;
  final Ref ref;

  OrderActions(this.api, this.ref);

  Future<OrderModel> createOrder(Map<String, dynamic> data) async {
    try {
      final idempotencyKey = data['idempotency_key'] ??
          'create_order_${DateTime.now().microsecondsSinceEpoch}';

      final response = await api.client.post(
        '/orders',
        data: data,
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );

      final resData = response.data;
      final orderData = (resData is Map && resData.containsKey('data'))
          ? resData['data']
          : resData;

      if (orderData is Map) {
        final newOrder = OrderModel.fromJson(Map<String, dynamic>.from(orderData));
        ref.read(ordersListProvider.notifier).upsertOrderLocally(newOrder);
        ref.read(ordersListProvider.notifier).refreshSilently();
        ref.invalidate(salesmanDashboardProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(filteredCustomerListProvider);
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
      final idempotencyKey = data['idempotency_key'] ??
          'update_order_${orderId}_${DateTime.now().microsecondsSinceEpoch}';

      final response = await api.client.put(
        '/orders/$orderId',
        data: data,
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );

      ref.invalidate(singleOrderProvider(orderId.toString()));

      final resData = response.data;
      final orderData = (resData is Map && resData.containsKey('data'))
          ? resData['data']
          : resData;

      if (orderData is Map) {
        final updatedOrder = OrderModel.fromJson(Map<String, dynamic>.from(orderData));
        ref.read(ordersListProvider.notifier).upsertOrderLocally(updatedOrder);
        ref.read(ordersListProvider.notifier).refreshSilently();
        ref.invalidate(salesmanDashboardProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(filteredCustomerListProvider);
        return updatedOrder;
      }

      throw FormatException('داتای نوێکراوەی پسوڵە نادروستە');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    ref.read(ordersListProvider.notifier).updateOrderStatusLocally(orderId, newStatus);
    ref.invalidate(singleOrderProvider(orderId));

    try {
      final idempotencyKey =
          'status_order_${orderId}_${DateTime.now().microsecondsSinceEpoch}';

      await api.client.post(
        '/orders/$orderId/status',
        data: {'status': newStatus},
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );

      ref.read(ordersListProvider.notifier).refreshSilently();
      ref.invalidate(salesmanDashboardProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(filteredCustomerListProvider);
    } catch (e) {
      ref.read(ordersListProvider.notifier).refreshSilently();
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final previousList = ref.read(ordersListProvider).valueOrNull;

    // 1. Optimistically remove from local state immediately
    ref.read(ordersListProvider.notifier).removeOrderLocally(orderId);
    ref.invalidate(singleOrderProvider(orderId));

    try {
      // 2. Call backend API
      await api.client.delete('/orders/$orderId');

      // 3. Silently update providers in background without resetting UI state
      ref.read(ordersListProvider.notifier).refreshSilently();
      ref.invalidate(salesmanDashboardProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(filteredCustomerListProvider);
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
    debugPrint("Realtime update received on private-orders channel for sales returns: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-orders', onSalesReturnsEvent);

  ref.onDispose(() {
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
        options: Options(
          headers: {
            'X-Idempotency-Key': returnEntityId,
          },
        ),
      );

      if (payload['sales_order_id'] != null) {
        ref.invalidate(singleOrderProvider(payload['sales_order_id'].toString()));
      }
      ref.invalidate(ordersListProvider);
      ref.invalidate(salesReturnsListProvider);
      ref.invalidate(salesmanDashboardProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(filteredCustomerListProvider);
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
final readyOrdersForDeliveryProvider = FutureProvider<List<OrderModel>>((ref) async {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return const [];
  final pusher = ref.watch(pusherServiceProvider);

  void onOrdersEvent(Map<String, dynamic> eventData) {
    debugPrint("Realtime update received on readyOrdersForDeliveryProvider: $eventData");
    ref.invalidate(ordersListProvider);
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-orders', onOrdersEvent);

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-orders', onOrdersEvent);
  });

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

final adminOrderFilterProvider =
    StateProvider<AdminOrderFilterState>((ref) => const AdminOrderFilterState());

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
    result = result.where((o) => o.customerId == filterState.customerId).toList();
  }

  // 3. Salesman filter
  if (filterState.salesmanId != null) {
    result = result.where((o) => o.salesmanId == filterState.salesmanId).toList();
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


