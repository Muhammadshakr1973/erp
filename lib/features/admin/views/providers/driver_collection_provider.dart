import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../models/driver_collection_model.dart';
import 'dashboard_provider.dart';

final driverCashSummaryProvider = FutureProvider<List<DriverCashSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onDeliveryTripEvent(Map<String, dynamic> eventData) {
    debugPrint("Realtime update received on private-delivery-trips for driver cash summary: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-delivery-trips', onDeliveryTripEvent);

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-delivery-trips', onDeliveryTripEvent);
  });

  try {
    final response = await api.client.get('/driver-collections/summary');
    if (response.statusCode == 200) {
      final resData = response.data;
      if (resData is! Map || resData['data'] is! List) {
        throw const FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە');
      }
      final list = resData['data'] as List;
      return list.map((json) => DriverCashSummary.fromJson(json as Map<String, dynamic>)).toList();
    }
    throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە: ${response.statusCode}');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final driverCollectionsHistoryProvider = FutureProvider<List<DriverCollection>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onDeliveryTripHistoryEvent(Map<String, dynamic> eventData) {
    debugPrint("Realtime update received on private-delivery-trips for driver collection history: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-delivery-trips', onDeliveryTripHistoryEvent);

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-delivery-trips', onDeliveryTripHistoryEvent);
  });

  try {
    final response = await api.client.get('/driver-collections');
    if (response.statusCode == 200) {
      final resData = response.data;
      if (resData is! Map || resData['data'] is! List) {
        throw const FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە');
      }
      final list = resData['data'] as List;
      return list.map((json) => DriverCollection.fromJson(json as Map<String, dynamic>)).toList();
    }
    throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە: ${response.statusCode}');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final driverCollectionActionsProvider = Provider<DriverCollectionActions>((ref) {
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
        throw Exception(api.extractErrorMessage(response.data, defaultMsg: 'کێشەیەک لە زانیارییەکاندا هەیە'));
      }
      ref.invalidate(driverCashSummaryProvider);
      ref.invalidate(driverCollectionsHistoryProvider);
      ref.invalidate(dashboardProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
