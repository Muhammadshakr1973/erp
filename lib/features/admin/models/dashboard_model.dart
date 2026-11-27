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
  final List<TodaySalesmanPlanItem> todaySalesmenPlan;
  final List<LowMarginSpecialPriceAlert> lowMarginSpecialPriceAlerts;

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
    this.todaySalesmenPlan = const [],
    this.lowMarginSpecialPriceAlerts = const [],
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['today_salesmen_plan'] as List? ?? [];
    final parsedPlan = rawPlan
        .map((item) => TodaySalesmanPlanItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final rawAlerts = json['low_margin_special_price_alerts'] as List? ?? [];
    final parsedAlerts = rawAlerts
        .map((item) => LowMarginSpecialPriceAlert.fromJson(Map<String, dynamic>.from(item)))
        .toList();

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
      todaySalesmenPlan: parsedPlan,
      lowMarginSpecialPriceAlerts: parsedAlerts,
    );
  }

  DashboardModel copyWith({
    double? monthlySales,
    double? monthlyProfit,
    double? totalReceivables,
    double? totalCustomerDebts,
    double? totalPayables,
    double? monthlyCollected,
    double? deliveredToOffice,
    double? lastMonthSales,
    double? lastMonthProfit,
    double? driversRemainingCash,
    double? lastCollectionAmount,
    String? lastCollectionDriver,
    List<TodaySalesmanPlanItem>? todaySalesmenPlan,
    List<LowMarginSpecialPriceAlert>? lowMarginSpecialPriceAlerts,
  }) {
    return DashboardModel(
      monthlySales: monthlySales ?? this.monthlySales,
      monthlyProfit: monthlyProfit ?? this.monthlyProfit,
      totalReceivables: totalReceivables ?? this.totalReceivables,
      totalCustomerDebts: totalCustomerDebts ?? this.totalCustomerDebts,
      totalPayables: totalPayables ?? this.totalPayables,
      monthlyCollected: monthlyCollected ?? this.monthlyCollected,
      deliveredToOffice: deliveredToOffice ?? this.deliveredToOffice,
      lastMonthSales: lastMonthSales ?? this.lastMonthSales,
      lastMonthProfit: lastMonthProfit ?? this.lastMonthProfit,
      driversRemainingCash: driversRemainingCash ?? this.driversRemainingCash,
      lastCollectionAmount: lastCollectionAmount ?? this.lastCollectionAmount,
      lastCollectionDriver: lastCollectionDriver ?? this.lastCollectionDriver,
      todaySalesmenPlan: todaySalesmenPlan ?? this.todaySalesmenPlan,
      lowMarginSpecialPriceAlerts: lowMarginSpecialPriceAlerts ?? this.lowMarginSpecialPriceAlerts,
    );
  }
}

class TodaySalesmanPlanItem {
  final int salesmanId;
  final String salesmanName;
  final String? salesmanPhone;
  final int routeId;
  final String routeName;
  final String? routeColor;
  final int customersCount;

  TodaySalesmanPlanItem({
    required this.salesmanId,
    required this.salesmanName,
    this.salesmanPhone,
    required this.routeId,
    required this.routeName,
    this.routeColor,
    required this.customersCount,
  });

  factory TodaySalesmanPlanItem.fromJson(Map<String, dynamic> json) {
    return TodaySalesmanPlanItem(
      salesmanId: (json['salesman_id'] is num)
          ? (json['salesman_id'] as num).toInt()
          : (int.tryParse(json['salesman_id']?.toString() ?? '0') ?? 0),
      salesmanName: json['salesman_name']?.toString() ?? '',
      salesmanPhone: json['salesman_phone']?.toString(),
      routeId: (json['route_id'] is num)
          ? (json['route_id'] as num).toInt()
          : (int.tryParse(json['route_id']?.toString() ?? '0') ?? 0),
      routeName: json['route_name']?.toString() ?? '',
      routeColor: json['route_color']?.toString(),
      customersCount: (json['customers_count'] is num)
          ? (json['customers_count'] as num).toInt()
          : (int.tryParse(json['customers_count']?.toString() ?? '0') ?? 0),
    );
  }
}

class LowMarginSpecialPriceAlert {
  final int id;
  final int orderId;
  final String orderNumber;
  final String? orderDate;
  final String orderStatus;
  final int salesmanId;
  final String salesmanName;
  final bool isCashVan;
  final int customerId;
  final String customerName;
  final int productId;
  final String productName;
  final int unitPrice;
  final int costPrice;
  final int profitMargin;

  LowMarginSpecialPriceAlert({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    this.orderDate,
    required this.orderStatus,
    required this.salesmanId,
    required this.salesmanName,
    required this.isCashVan,
    required this.customerId,
    required this.customerName,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.costPrice,
    required this.profitMargin,
  });

  factory LowMarginSpecialPriceAlert.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) =>
        (v is num) ? v.toInt() : (int.tryParse(v?.toString() ?? '0') ?? 0);

    return LowMarginSpecialPriceAlert(
      id: parseInt(json['id']),
      orderId: parseInt(json['order_id']),
      orderNumber: json['order_number']?.toString() ?? '',
      orderDate: json['order_date']?.toString(),
      orderStatus: json['order_status']?.toString() ?? '',
      salesmanId: parseInt(json['salesman_id']),
      salesmanName: json['salesman_name']?.toString() ?? 'نادیار',
      isCashVan: json['is_cash_van'] == true || json['is_cash_van'] == 1,
      customerId: parseInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? 'کڕیار',
      productId: parseInt(json['product_id']),
      productName: json['product_name']?.toString() ?? 'کاڵا',
      unitPrice: parseInt(json['unit_price']),
      costPrice: parseInt(json['cost_price']),
      profitMargin: parseInt(json['profit_margin']),
    );
  }
}
