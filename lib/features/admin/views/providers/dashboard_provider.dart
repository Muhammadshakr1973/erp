import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../models/dashboard_model.dart';

final dashboardProvider = FutureProvider<DashboardModel>((ref) async {
  final api = ref.watch(apiClientProvider);
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
