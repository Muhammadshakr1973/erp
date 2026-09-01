import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../models/delivery_trip_model.dart';

final driverTripsProvider = FutureProvider<List<DeliveryTripModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/delivery-trips');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => DeliveryTripModel.fromJson(json)).toList();
    }
    throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final tripDetailProvider =
    FutureProvider.family<DeliveryTripModel, int>((ref, tripId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/delivery-trips/$tripId');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = response.data['data'] ?? {};
      return DeliveryTripModel.fromJson(data);
    }
    throw Exception('گەشتەکە نەدۆزرایەوە');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final driverActionsProvider = Provider<DriverActions>((ref) {
  final api = ref.watch(apiClientProvider);
  final syncService = ref.watch(syncServiceProvider);
  return DriverActions(api, syncService, ref);
});

class DriverActions {
  final ApiClient api;
  final SyncService syncService;
  final Ref ref;

  DriverActions(this.api, this.syncService, this.ref);

  Future<void> deliverOrder({
    required int tripOrderId,
    required int receivedAmount,
    String? notes,
  }) async {
    try {
      await syncService.enqueueOperation(
        entityId: tripOrderId.toString(),
        operationType: 'DELIVER_ORDER',
        payload: {
          'received_amount': receivedAmount,
          'notes': notes,
        },
      );
      ref.invalidate(driverTripsProvider);
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
      await syncService.enqueueOperation(
        entityId: tripOrderId.toString(),
        operationType: 'FAIL_ORDER',
        payload: {
          'failed_reason': failedReason,
          'notes': notes,
        },
      );
      ref.invalidate(driverTripsProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
