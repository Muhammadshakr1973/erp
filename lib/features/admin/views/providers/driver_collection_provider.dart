import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';
import '../../models/driver_collection_model.dart';

final driverCashSummaryProvider = FutureProvider<List<DriverCashSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
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
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
