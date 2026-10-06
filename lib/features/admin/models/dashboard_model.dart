class DashboardModel {
  final double monthlySales;
  final double monthlyProfit;
  final double totalReceivables;
  final double totalCustomerDebts;
  final double totalPayables;
  final double monthlyCollected;
  final double deliveredToOffice;
  final double lastMonthSales;
  final double lastMonthProfit;
  final double driversRemainingCash;
  final double lastCollectionAmount;
  final String? lastCollectionDriver;

  DashboardModel({
    required this.monthlySales,
    required this.monthlyProfit,
    required this.totalReceivables,
    required this.totalCustomerDebts,
    required this.totalPayables,
    required this.monthlyCollected,
    required this.deliveredToOffice,
    required this.lastMonthSales,
    required this.lastMonthProfit,
    required this.driversRemainingCash,
    required this.lastCollectionAmount,
    this.lastCollectionDriver,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      monthlySales:
          double.tryParse(json['monthly_sales']?.toString() ?? '0') ?? 0.0,
      monthlyProfit:
          double.tryParse(json['monthly_profit']?.toString() ?? '0') ?? 0.0,
      totalReceivables:
          double.tryParse(json['total_receivables']?.toString() ?? '0') ?? 0.0,
      totalCustomerDebts:
          double.tryParse(json['total_customer_debts']?.toString() ?? json['total_receivables']?.toString() ?? '0') ?? 0.0,
      totalPayables:
          double.tryParse(json['total_payables']?.toString() ?? '0') ?? 0.0,
      monthlyCollected:
          double.tryParse(json['monthly_collected']?.toString() ?? '0') ?? 0.0,
      deliveredToOffice:
          double.tryParse(json['delivered_to_office']?.toString() ?? '0') ?? 0.0,
      lastMonthSales:
          double.tryParse(json['last_month_sales']?.toString() ?? '0') ?? 0.0,
      lastMonthProfit:
          double.tryParse(json['last_month_profit']?.toString() ?? '0') ?? 0.0,
      driversRemainingCash:
          double.tryParse(json['drivers_remaining_cash']?.toString() ?? '0') ?? 0.0,
      lastCollectionAmount:
          double.tryParse(json['last_collection_amount']?.toString() ?? '0') ?? 0.0,
      lastCollectionDriver: json['last_collection_driver']?.toString(),
    );
  }
}
