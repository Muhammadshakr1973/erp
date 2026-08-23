import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';
import '../../models/dashboard_model.dart';

final dashboardProvider = FutureProvider<DashboardModel>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/dashboard');
    if (response.statusCode == 200) {
      return DashboardModel.fromJson(response.data['data']);
    }
    throw Exception('داتا نەگەڕایەوە');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});
