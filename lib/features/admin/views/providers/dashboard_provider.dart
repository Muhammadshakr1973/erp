import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/dashboard_model.dart';

final FutureProvider<DashboardModel> dashboardProvider =
    FutureProvider<DashboardModel>((ref) async {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) {
    throw Exception('بەکارهێنەر لۆگئۆت بووە (User is logged out)');
  }
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onRealtimeDashboardEvent(Map<String, dynamic> eventData) {
    debugPrint("Pusher: Realtime update received on admin dashboardProvider: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-orders', onRealtimeDashboardEvent);
  pusher.subscribeToChannel('private-delivery-trips', onRealtimeDashboardEvent);
  pusher.subscribeToChannel('private-customers', onRealtimeDashboardEvent);
  pusher.subscribeToChannel('private-products', onRealtimeDashboardEvent);
  pusher.subscribeToChannel('private-commissions', onRealtimeDashboardEvent);

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-orders', onRealtimeDashboardEvent);
    pusher.unsubscribeFromChannel('private-delivery-trips', onRealtimeDashboardEvent);
    pusher.unsubscribeFromChannel('private-customers', onRealtimeDashboardEvent);
    pusher.unsubscribeFromChannel('private-products', onRealtimeDashboardEvent);
    pusher.unsubscribeFromChannel('private-commissions', onRealtimeDashboardEvent);
  });

  try {
    final response = await api.client.get('/reports/dashboard');
    if (response.statusCode == 200) {
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed dashboard response payload)',
        );
      }
      return DashboardModel.fromJson(Map<String, dynamic>.from(resData['data']));
    }
    throw Exception('داتا نەگەڕایەوە');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});
