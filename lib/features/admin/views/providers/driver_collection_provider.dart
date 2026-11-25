import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/driver_collection_model.dart';
import 'dashboard_provider.dart';

class DriverCashSummaryNotifier extends AsyncNotifier<List<DriverCashSummary>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<DriverCashSummary>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onDeliveryTripEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received on private-delivery-trips for driver cash summary: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-delivery-trips', onDeliveryTripEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel(
        'private-delivery-trips',
        onDeliveryTripEvent,
      );
    });

    return _fetchSummary(api);
  }

  Future<List<DriverCashSummary>> _fetchSummary(ApiClient api) async {
    try {
      final response = await api.client.get('/driver-collections/summary');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw const FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە');
        }
        final list = resData['data'] as List;
        return list
            .whereType<Map>()
            .map(
              (json) =>
                  DriverCashSummary.fromJson(Map<String, dynamic>.from(json)),
            )
            .toList();
      }
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە: ${response.statusCode}');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchSummary(api);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current summary on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final driverCashSummaryProvider =
    AsyncNotifierProvider<DriverCashSummaryNotifier, List<DriverCashSummary>>(
      DriverCashSummaryNotifier.new,
    );

class DriverCollectionsHistoryNotifier
    extends AsyncNotifier<List<DriverCollection>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<DriverCollection>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onDeliveryTripHistoryEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received on private-delivery-trips for driver collection history: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel(
      'private-delivery-trips',
      onDeliveryTripHistoryEvent,
    );
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel(
        'private-delivery-trips',
        onDeliveryTripHistoryEvent,
      );
    });

    return _fetchHistory(api);
  }

  Future<List<DriverCollection>> _fetchHistory(ApiClient api) async {
    try {
      final response = await api.client.get('/driver-collections');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw const FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە');
        }
        final list = resData['data'] as List;
        return list
            .whereType<Map>()
            .map(
              (json) =>
                  DriverCollection.fromJson(Map<String, dynamic>.from(json)),
            )
            .toList();
      }
      throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە: ${response.statusCode}');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchHistory(api);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current collections history on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final driverCollectionsHistoryProvider =
    AsyncNotifierProvider<
      DriverCollectionsHistoryNotifier,
      List<DriverCollection>
    >(DriverCollectionsHistoryNotifier.new);

final driverCollectionActionsProvider = Provider<DriverCollectionActions>((
  ref,
) {
  final api = ref.watch(apiClientProvider);
  return DriverCollectionActions(api, ref);
});

class DriverCollectionActions {
  final ApiClient api;
  final Ref ref;

  DriverCollectionActions(this.api, this.ref);

  Future<void> storeCollection({
    required int driverId,
    required int amount,
    required String collectedAt,
    String? notes,
  }) async {
    try {
      final response = await api.client.post(
        '/driver-collections',
        data: {
          'driver_id': driverId,
          'amount': amount,
          'collected_at': collectedAt,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      if (response.statusCode != null && response.statusCode! >= 400) {
        throw Exception(
          api.extractErrorMessage(
            response.data,
            defaultMsg: 'کێشەیەک لە زانیارییەکاندا هەیە',
          ),
        );
      }

      // Silently refresh driver cash summary, collections history, and main admin dashboard
      if (ref.exists(driverCashSummaryProvider)) {
        unawaited(
          ref.read(driverCashSummaryProvider.notifier).refreshSilently(),
        );
      }
      if (ref.exists(driverCollectionsHistoryProvider)) {
        unawaited(
          ref.read(driverCollectionsHistoryProvider.notifier).refreshSilently(),
        );
      }
      if (ref.exists(dashboardProvider)) {
        unawaited(ref.read(dashboardProvider.notifier).refreshSilently());
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
