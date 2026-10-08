import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
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

class DashboardCustomer {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final int currentBalance;
  final int visitOrder;
  final bool visited;

  DashboardCustomer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    required this.currentBalance,
    required this.visitOrder,
    required this.visited,
  });

  factory DashboardCustomer.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['customer_id'];
    final parsedId = rawId is num
        ? rawId.toInt()
        : (int.tryParse(rawId?.toString() ?? '0') ?? 0);

    final rawBalance = json['current_balance'] ?? json['balance'];
    final parsedBalance = rawBalance is num
        ? rawBalance.toInt()
        : (int.tryParse(rawBalance?.toString() ?? '0') ?? 0);

    final rawVisitOrder = json['visit_order'];
    final parsedVisitOrder = rawVisitOrder is num
        ? rawVisitOrder.toInt()
        : (int.tryParse(rawVisitOrder?.toString() ?? '0') ?? 0);

    return DashboardCustomer(
      id: parsedId,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      currentBalance: parsedBalance,
      visitOrder: parsedVisitOrder,
      visited: json['visited'] == true ||
          json['visited'] == 1 ||
          json['visited'] == '1' ||
          json['visited'] == 'true',
    );
  }
}

class SalesmanDashboardData {
  final String routeName;
  final int? todayRouteId;
  final List<DashboardCustomer> todayRouteCustomers;
  final int todaySales;
  final int todayUnits;
  final int last7DaysSales;
  final int last7DaysUnits;
  final int monthUnits;
  final int lastMonthUnits;
  final int newCustomersWeek;
  final int newCustomersMonth;
  final List<WeeklyChartItem> weeklyChartData;

  SalesmanDashboardData({
    required this.routeName,
    this.todayRouteId,
    this.todayRouteCustomers = const [],
    required this.todaySales,
    required this.todayUnits,
    required this.last7DaysSales,
    required this.last7DaysUnits,
    required this.monthUnits,
    this.lastMonthUnits = 0,
    required this.newCustomersWeek,
    required this.newCustomersMonth,
    required this.weeklyChartData,
  });

  factory SalesmanDashboardData.fromJson(Map<String, dynamic> json) {
    final rawChart = json['weekly_chart_data'] as List? ?? [];
    final rawCustomers = json['today_route_customers'] as List? ?? [];
    
    return SalesmanDashboardData(
      routeName: json['route_name']?.toString() ?? 'گشتی',
      todayRouteId: json['today_route_id'] != null
          ? (json['today_route_id'] is num
              ? (json['today_route_id'] as num).toInt()
              : int.tryParse(json['today_route_id'].toString()))
          : null,
      todayRouteCustomers: rawCustomers
          .map((item) => DashboardCustomer.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      todaySales: (json['today_sales'] is num)
          ? (json['today_sales'] as num).toInt()
          : (int.tryParse(json['today_sales']?.toString() ?? '0') ?? 0),
      todayUnits: (json['today_units'] is num)
          ? (json['today_units'] as num).toInt()
          : (int.tryParse(json['today_units']?.toString() ?? '0') ?? 0),
      last7DaysSales: (json['last_7_days_sales'] is num)
          ? (json['last_7_days_sales'] as num).toInt()
          : (int.tryParse(json['last_7_days_sales']?.toString() ?? '') ??
              (int.tryParse(json['weekly_sales']?.toString() ?? '0') ?? 0)),
      last7DaysUnits: (json['last_7_days_units'] is num)
          ? (json['last_7_days_units'] as num).toInt()
          : (int.tryParse(json['last_7_days_units']?.toString() ?? '0') ?? 0),
      monthUnits: (json['month_units'] is num)
          ? (json['month_units'] as num).toInt()
          : (int.tryParse(json['month_units']?.toString() ?? '') ??
              (int.tryParse(json['this_month_units']?.toString() ?? '0') ?? 0)),
      lastMonthUnits: (json['last_month_units'] is num)
          ? (json['last_month_units'] as num).toInt()
          : (int.tryParse(json['last_month_units']?.toString() ?? '') ??
              (int.tryParse(json['previous_month_units']?.toString() ?? '0') ?? 0)),
      newCustomersWeek: (json['new_customers_week'] is num)
          ? (json['new_customers_week'] as num).toInt()
          : (int.tryParse(json['new_customers_week']?.toString() ?? '0') ?? 0),
      newCustomersMonth: (json['new_customers_month'] is num)
          ? (json['new_customers_month'] as num).toInt()
          : (int.tryParse(json['new_customers_month']?.toString() ?? '0') ?? 0),
      weeklyChartData: rawChart
          .map((item) => WeeklyChartItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class SalesmanDashboardNotifier extends AsyncNotifier<SalesmanDashboardData> {
  @override
  FutureOr<SalesmanDashboardData> build() async {
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSalesmanDashboardEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for SalesmanDashboardNotifier: $eventData");
      refreshSilently();
    }

    pusher.subscribeToChannel('private-orders', onSalesmanDashboardEvent);
    pusher.subscribeToChannel('private-customers', onSalesmanDashboardEvent);
    pusher.subscribeToChannel('private-delivery-trips', onSalesmanDashboardEvent);

    ref.onDispose(() {
      pusher.unsubscribeFromChannel('private-orders', onSalesmanDashboardEvent);
      pusher.unsubscribeFromChannel('private-customers', onSalesmanDashboardEvent);
      pusher.unsubscribeFromChannel('private-delivery-trips', onSalesmanDashboardEvent);
    });

    return _fetchDashboard(api);
  }

  Future<SalesmanDashboardData> _fetchDashboard(ApiClient api) async {
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
  }

  Future<void> refreshSilently() async {
    final api = ref.read(apiClientProvider);
    try {
      final freshData = await _fetchDashboard(api);
      state = AsyncData(freshData);
    } catch (_) {
      // Keep existing dashboard data on transient errors
    }
  }
}

final salesmanDashboardProvider =
    AsyncNotifierProvider<SalesmanDashboardNotifier, SalesmanDashboardData>(
  SalesmanDashboardNotifier.new,
);
