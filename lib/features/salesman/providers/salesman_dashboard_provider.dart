import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../orders/providers/orders_provider.dart';

class WeeklyChartItem {
  final String date;
  final String label;
  final int sales;
  final int units;

  WeeklyChartItem({
    required this.date,
    required this.label,
    required this.sales,
    required this.units,
  });

  factory WeeklyChartItem.fromJson(Map<String, dynamic> json) {
    return WeeklyChartItem(
      date: json['date']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sales: (json['sales'] is num) ? (json['sales'] as num).toInt() : 0,
      units: (json['units'] is num) ? (json['units'] as num).toInt() : 0,
    );
  }
}

class SalesmanDashboardData {
  final String routeName;
  final int todaySales;
  final int todayUnits;
  final int last7DaysUnits;
  final int newCustomersWeek;
  final int newCustomersMonth;
  final List<WeeklyChartItem> weeklyChartData;

  SalesmanDashboardData({
    required this.routeName,
    required this.todaySales,
    required this.todayUnits,
    required this.last7DaysUnits,
    required this.newCustomersWeek,
    required this.newCustomersMonth,
    required this.weeklyChartData,
  });

  factory SalesmanDashboardData.fromJson(Map<String, dynamic> json) {
    final rawChart = json['weekly_chart_data'] as List? ?? [];
    return SalesmanDashboardData(
      routeName: json['route_name']?.toString() ?? 'گشتی',
      todaySales: (json['today_sales'] is num) ? (json['today_sales'] as num).toInt() : 0,
      todayUnits: (json['today_units'] is num) ? (json['today_units'] as num).toInt() : 0,
      last7DaysUnits: (json['last_7_days_units'] is num) ? (json['last_7_days_units'] as num).toInt() : 0,
      newCustomersWeek: (json['new_customers_week'] is num) ? (json['new_customers_week'] as num).toInt() : 0,
      newCustomersMonth: (json['new_customers_month'] is num) ? (json['new_customers_month'] as num).toInt() : 0,
      weeklyChartData: rawChart
          .map((item) => WeeklyChartItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
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
