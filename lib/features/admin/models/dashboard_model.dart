class DashboardModel {
  final double monthlySales;
  final double monthlyProfit;
  final double totalReceivables;
  final double monthlyCollected;
  final double deliveredToOffice;
  final double lastMonthSales;
  final double lastMonthProfit;

  DashboardModel({
    required this.monthlySales,
    required this.monthlyProfit,
    required this.totalReceivables,
    required this.monthlyCollected,
    required this.deliveredToOffice,
    required this.lastMonthSales,
    required this.lastMonthProfit,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      monthlySales:
          double.tryParse(json['monthly_sales']?.toString() ?? '0') ?? 0.0,
      monthlyProfit:
          double.tryParse(json['monthly_profit']?.toString() ?? '0') ?? 0.0,
      totalReceivables:
          double.tryParse(json['total_receivables']?.toString() ?? '0') ?? 0.0,
      monthlyCollected:
          double.tryParse(json['monthly_collected']?.toString() ?? '0') ?? 0.0,
      deliveredToOffice:
          double.tryParse(json['delivered_to_office']?.toString() ?? '0') ?? 0.0,
      lastMonthSales:
          double.tryParse(json['last_month_sales']?.toString() ?? '0') ?? 0.0,
      lastMonthProfit:
          double.tryParse(json['last_month_profit']?.toString() ?? '0') ?? 0.0,
    );
  }
}
