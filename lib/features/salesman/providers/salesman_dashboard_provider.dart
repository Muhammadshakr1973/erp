import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../orders/providers/orders_provider.dart';

class SalesmanDashboardData {
  final String routeName;
  final int todaySales;
  final int visitedCount;
  final int totalVisits;

  SalesmanDashboardData({
    required this.routeName,
    required this.todaySales,
    required this.visitedCount,
    required this.totalVisits,
  });

  factory SalesmanDashboardData.fromJson(Map<String, dynamic> json) {
    return SalesmanDashboardData(
      routeName: json['route_name'] ?? 'گشتی',
      todaySales: json['today_sales'] ?? 0,
      visitedCount: json['visited_count'] ?? 0,
      totalVisits: json['total_visits'] ?? 1,
    );
  }
}

final salesmanDashboardProvider = FutureProvider<SalesmanDashboardData>((ref) async {
  // Watching orders list provider triggers an automatic refetch
  // whenever any orders change or a real-time Pusher notification arrives!
  ref.watch(ordersListProvider);
  
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/salesman/dashboard');
    if (response.statusCode == 200) {
      final data = response.data['data'] ?? response.data;
      return SalesmanDashboardData.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە');
  } catch (e) {
    if (e is DioException) {
      throw Exception(api.parseError(e));
    }
    rethrow;
  }
});
