import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/route_model.dart';
import 'customer_provider.dart';

List<Map<String, dynamic>> _parseListResponse(dynamic rawData) {
  if (rawData is List) {
    return List<Map<String, dynamic>>.from(rawData);
  }
  if (rawData is Map) {
    if (rawData.containsKey('data')) {
      final inner = rawData['data'];
      if (inner is List) {
        return List<Map<String, dynamic>>.from(inner);
      }
      if (inner is Map && inner.containsKey('data')) {
        final doubleInner = inner['data'];
        if (doubleInner is List) {
          return List<Map<String, dynamic>>.from(doubleInner);
        }
      }
    }
  }
  throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response structure)');
}

class RouteListNotifier extends AsyncNotifier<List<RouteModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<RouteModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onRoutesEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for routeListProvider: $eventData");
      final eventType = eventData['event_type']?.toString();
      final routeId = int.tryParse(eventData['route_id']?.toString() ?? '');
      if (eventType == 'delete' && routeId != null && routeId > 0) {
        removeRouteLocally(routeId);
        return;
      }
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-routes', onRoutesEvent);
    pusher.subscribeToChannel('private-customers', onRoutesEvent);
    pusher.subscribeToChannel('private-users', onRoutesEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-routes', onRoutesEvent);
      pusher.unsubscribeFromChannel('private-customers', onRoutesEvent);
      pusher.unsubscribeFromChannel('private-users', onRoutesEvent);
    });

    return _fetchRoutes(api);
  }

  Future<List<RouteModel>> _fetchRoutes(ApiClient api) async {
    try {
      final response = await api.client.get('/routes');
      if (response.statusCode == 200) {
        final list = _parseListResponse(response.data);
        return list.map((json) => RouteModel.fromJson(json)).toList();
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
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
      final fresh = await _fetchRoutes(api);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current routes on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }

  void upsertRouteLocally(RouteModel route) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((r) => r.id == route.id);
    final updated = List<RouteModel>.from(current);
    if (idx != -1) {
      updated[idx] = route;
    } else {
      updated.add(route);
    }
    state = AsyncData(updated);
  }

  void removeRouteLocally(int routeId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final filtered = current.where((r) => r.id != routeId).toList();
    if (filtered.length != current.length) {
      state = AsyncData(filtered);
    }
  }
}

final routeListProvider = AsyncNotifierProvider<RouteListNotifier, List<RouteModel>>(
  RouteListNotifier.new,
);

class TodayRouteAssignmentsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onTodayAssignmentsEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received for todayRouteAssignmentsProvider: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-routes', onTodayAssignmentsEvent);
    pusher.subscribeToChannel('private-customers', onTodayAssignmentsEvent);
    pusher.subscribeToChannel('private-users', onTodayAssignmentsEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-routes', onTodayAssignmentsEvent);
      pusher.unsubscribeFromChannel('private-customers', onTodayAssignmentsEvent);
      pusher.unsubscribeFromChannel('private-users', onTodayAssignmentsEvent);
    });

    return _fetchTodayAssignments(api);
  }

  Future<List<Map<String, dynamic>>> _fetchTodayAssignments(ApiClient api) async {
    try {
      final response = await api.client.get('/routes/today-assignments');
      if (response.statusCode == 200) {
        return _parseListResponse(response.data);
      }
      return const [];
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
      final fresh = await _fetchTodayAssignments(api);
      final current = state.valueOrNull;
      if (current != null && jsonEncode(current) == jsonEncode(fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current assignments on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final todayRouteAssignmentsProvider = AsyncNotifierProvider<
    TodayRouteAssignmentsNotifier, List<Map<String, dynamic>>>(
  TodayRouteAssignmentsNotifier.new,
);

final routeActionsProvider = Provider<RouteActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return RouteActions(api, ref);
});

class RouteActions {
  final ApiClient api;
  final Ref ref;

  RouteActions(this.api, this.ref);

  void _refreshTodayAssignmentsSilently() {
    if (ref.exists(todayRouteAssignmentsProvider)) {
      unawaited(
        ref.read(todayRouteAssignmentsProvider.notifier).refreshSilently(),
      );
    }
  }

  void _refreshRoutesSilently() {
    if (ref.exists(routeListProvider)) {
      unawaited(ref.read(routeListProvider.notifier).refreshSilently());
    }
  }

  Future<RouteModel> addRoute({
    required String name,
    String? color,
    bool isActive = true,
  }) async {
    try {
      final response = await api.client.post(
        '/routes',
        data: {
          'name': name,
          if (color != null) 'color': color,
          'is_active': isActive,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw response.data ?? 'هەڵەیەک ڕوویدا';
      }
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed route response payload)',
        );
      }
      final created = RouteModel.fromJson(Map<String, dynamic>.from(resData['data']));
      if (ref.exists(routeListProvider)) {
        ref.read(routeListProvider.notifier).upsertRouteLocally(created);
      }
      _refreshTodayAssignmentsSilently();
      return created;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<RouteModel> updateRoute(
    int id, {
    required String name,
    String? color,
    bool? isActive,
  }) async {
    try {
      final response = await api.client.put(
        '/routes/$id',
        data: {
          'name': name,
          if (color != null) 'color': color,
          if (isActive != null) 'is_active': isActive,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw response.data ?? 'هەڵەیەک ڕوویدا';
      }
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed route response payload)',
        );
      }
      final updated = RouteModel.fromJson(Map<String, dynamic>.from(resData['data']));
      if (ref.exists(routeListProvider)) {
        ref.read(routeListProvider.notifier).upsertRouteLocally(updated);
      }
      _refreshTodayAssignmentsSilently();
      return updated;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteRoute(int id) async {
    try {
      await api.client.delete('/routes/$id');
      if (ref.exists(routeListProvider)) {
        ref.read(routeListProvider.notifier).removeRouteLocally(id);
      }
      _refreshTodayAssignmentsSilently();
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> assignSalesman(
    int routeId,
    int salesmanId, {
    String? workDate,
    String? dayOfWeek,
  }) async {
    try {
      await api.client.post(
        '/routes/$routeId/assign-salesman',
        data: {
          'salesman_id': salesmanId,
          if (workDate != null) 'work_date': workDate,
          if (dayOfWeek != null) 'day_of_week': dayOfWeek,
        },
      );
      _refreshRoutesSilently();
      _refreshTodayAssignmentsSilently();
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> removeSalesman(int routeId, int salesmanId, {String? dayOfWeek}) async {
    try {
      await api.client.delete(
        '/routes/$routeId/remove-salesman/$salesmanId',
        queryParameters: {
          if (dayOfWeek != null) 'day_of_week': dayOfWeek,
        },
      );
      _refreshRoutesSilently();
      _refreshTodayAssignmentsSilently();
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<List<Map<String, dynamic>>> fetchSalesmenList() async {
    try {
      final response = await api.client.get('/salesmen');
      if (response.statusCode == 200) {
        return _parseListResponse(response.data);
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<List<Map<String, dynamic>>> fetchRouteCustomers(int routeId) async {
    try {
      final response = await api.client.get('/routes/$routeId/customers');
      if (response.statusCode == 200) {
        return _parseListResponse(response.data);
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> reorderCustomers(int routeId, List<int> customerIds) async {
    try {
      await api.client.post(
        '/routes/$routeId/reorder-customers',
        data: {'customer_ids': customerIds},
      );
      _refreshRoutesSilently();
      _refreshTodayAssignmentsSilently();
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> assignCustomers(int routeId, List<int> customerIds) async {
    try {
      await api.client.post(
        '/routes/$routeId/assign-customers',
        data: {'customer_ids': customerIds},
      );
      _refreshRoutesSilently();
      _refreshTodayAssignmentsSilently();
      for (final cid in customerIds.toSet()) {
        unawaited(
          ref.read(customerActionsProvider).refreshSingleCustomerEverywhere(cid),
        );
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
