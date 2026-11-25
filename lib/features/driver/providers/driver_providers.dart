import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../admin/views/providers/driver_collection_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/delivery_trip_model.dart';

class DriverUserSummary {
  final int id;
  final String name;
  final String? phone;

  DriverUserSummary({
    required this.id,
    required this.name,
    this.phone,
  });

  factory DriverUserSummary.fromJson(Map<String, dynamic> json) {
    return DriverUserSummary(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }
}

class ActiveDriversNotifier extends AsyncNotifier<List<DriverUserSummary>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<DriverUserSummary>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onActiveDriversEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received on private-users for activeDriversProvider: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-users', onActiveDriversEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-users', onActiveDriversEvent);
    });

    return _fetchDrivers(api);
  }

  Future<List<DriverUserSummary>> _fetchDrivers(ApiClient api) async {
    try {
      final response = await api.client.get('/delivery-trips/drivers');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed drivers response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data
            .whereType<Map>()
            .map((json) => DriverUserSummary.fromJson(Map<String, dynamic>.from(json)))
            .toList();
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
      final fresh = await _fetchDrivers(api);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current drivers list on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final activeDriversProvider =
    AsyncNotifierProvider<ActiveDriversNotifier, List<DriverUserSummary>>(
  ActiveDriversNotifier.new,
);

class DriverTripsNotifier extends AsyncNotifier<List<DeliveryTripModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<DeliveryTripModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onDriverTripsEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received on private-delivery-trips: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-delivery-trips', onDriverTripsEvent);
    pusher.subscribeToChannel('private-orders', onDriverTripsEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-delivery-trips', onDriverTripsEvent);
      pusher.unsubscribeFromChannel('private-orders', onDriverTripsEvent);
    });

    return _fetchTrips(api);
  }

  Future<List<DeliveryTripModel>> _fetchTrips(ApiClient api) async {
    try {
      final response = await api.client.get('/delivery-trips');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed driver trips response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data.map((json) => DeliveryTripModel.fromJson(json)).toList();
      }
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
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
      final fresh = await _fetchTrips(api);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current trips on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final driverTripsProvider =
    AsyncNotifierProvider<DriverTripsNotifier, List<DeliveryTripModel>>(
  DriverTripsNotifier.new,
);

class TripDetailNotifier extends FamilyAsyncNotifier<DeliveryTripModel, int> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<DeliveryTripModel> build(int arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر چۆتە دەرەوە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onTripDetailEvent(Map<String, dynamic> eventData) {
      final eventTripId = int.tryParse(
        (eventData['delivery_trip_id'] ?? eventData['trip_id'])?.toString() ?? '',
      );
      if (eventTripId != null && eventTripId != arg) {
        return;
      }
      debugPrint("Realtime update received on private-delivery-trips for single trip: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-delivery-trips', onTripDetailEvent);
    pusher.subscribeToChannel('private-orders', onTripDetailEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-delivery-trips', onTripDetailEvent);
      pusher.unsubscribeFromChannel('private-orders', onTripDetailEvent);
    });

    return _fetchTrip(api, arg);
  }

  Future<DeliveryTripModel> _fetchTrip(ApiClient api, int tripId) async {
    try {
      final response = await api.client.get('/delivery-trips/$tripId');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed trip detail response payload)',
          );
        }
        return DeliveryTripModel.fromJson(Map<String, dynamic>.from(resData['data']));
      }
      throw Exception('گەشتەکە نەدۆزرایەوە');
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
      final fresh = await _fetchTrip(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current trip detail on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final tripDetailProvider = AsyncNotifierProvider.family<
    TripDetailNotifier, DeliveryTripModel, int>(
  TripDetailNotifier.new,
);

final driverActionsProvider = Provider<DriverActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return DriverActions(api, ref);
});

class DriverActions {
  final ApiClient api;
  final Ref ref;

  DriverActions(this.api, this.ref);

  Future<void> createDeliveryTrip({
    required int driverId,
    required String tripDate,
    required List<int> orderIds,
    String? notes,
    String? customEntityId,
  }) async {
    try {
      final entityId = customEntityId ?? 'trip_${DateTime.now().microsecondsSinceEpoch}';
      final payload = <String, dynamic>{
        'driver_id': driverId,
        'trip_date': tripDate,
        'order_ids': orderIds,
        'idempotency_key': entityId,
      };
      if (notes != null && notes.trim().isNotEmpty) {
        payload['notes'] = notes.trim();
      }

      await api.client.post(
        '/delivery-trips',
        data: payload,
        options: Options(
          headers: {
            'X-Idempotency-Key': entityId,
          },
        ),
      );

      if (ref.exists(driverTripsProvider)) {
        unawaited(ref.read(driverTripsProvider.notifier).refreshSilently());
      }
      unawaited(ref.read(ordersListProvider.notifier).refreshSilently());
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deliverOrder({
    required int tripOrderId,
    required int receivedAmount,
    String? notes,
  }) async {
    try {
      final idempotencyKey = 'deliver_${tripOrderId}_${DateTime.now().microsecondsSinceEpoch}';
      await api.client.post(
        '/delivery-trips/orders/$tripOrderId/deliver',
        data: {
          'received_amount': receivedAmount,
          'notes': notes,
        },
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (ref.exists(driverTripsProvider)) {
        unawaited(ref.read(driverTripsProvider.notifier).refreshSilently());
      }
      if (ref.exists(driverCashSummaryProvider)) {
        unawaited(ref.read(driverCashSummaryProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> failOrder({
    required int tripOrderId,
    required String failedReason,
    String? notes,
  }) async {
    try {
      final idempotencyKey = 'fail_${tripOrderId}_${DateTime.now().microsecondsSinceEpoch}';
      await api.client.post(
        '/delivery-trips/orders/$tripOrderId/fail',
        data: {
          'failed_reason': failedReason,
          'notes': notes,
        },
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (ref.exists(driverTripsProvider)) {
        unawaited(ref.read(driverTripsProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
