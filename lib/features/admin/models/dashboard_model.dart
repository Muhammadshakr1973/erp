class DashboardModel {
  final double monthlySales;
  final double monthlyProfit;
  final double totalReceivables;
  final double monthlyCollected;

  DashboardModel({
    required this.monthlySales,
    required this.monthlyProfit,
    required this.totalReceivables,
    required this.monthlyCollected,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      monthlySales: double.tryParse(json['monthly_sales']?.toString() ?? '0') ?? 0.0,
      monthlyProfit: double.tryParse(json['monthly_profit']?.toString() ?? '0') ?? 0.0,
      totalReceivables: double.tryParse(json['total_receivables']?.toString() ?? '0') ?? 0.0,
      monthlyCollected: double.tryParse(json['monthly_collected']?.toString() ?? '0') ?? 0.0,
    );
  }
}
