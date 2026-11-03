import '../../../core/utils/formatters.dart';

class SalesReportSummary {
  final int totalOrdersCount;
  final int totalDeliveredCount;
  final int totalGrossAmount;
  final int totalDiscountAmount;
  final int totalNetSales;
  final int totalCostAmount;
  final int totalProfitAmount;
  final int averageOrderValue;

  SalesReportSummary({
    required this.totalOrdersCount,
    required this.totalDeliveredCount,
    required this.totalGrossAmount,
    required this.totalDiscountAmount,
    required this.totalNetSales,
    required this.totalCostAmount,
    required this.totalProfitAmount,
    required this.averageOrderValue,
  });

  factory SalesReportSummary.fromJson(Map<String, dynamic> json) {
    return SalesReportSummary(
      totalOrdersCount: Formatters.parseInt(json['total_orders_count']),
      totalDeliveredCount: Formatters.parseInt(json['total_delivered_count']),
      totalGrossAmount: Formatters.parseInt(json['total_gross_amount']),
      totalDiscountAmount: Formatters.parseInt(json['total_discount_amount']),
      totalNetSales: Formatters.parseInt(json['total_net_sales']),
      totalCostAmount: Formatters.parseInt(json['total_cost_amount']),
      totalProfitAmount: Formatters.parseInt(json['total_profit_amount']),
      averageOrderValue: Formatters.parseInt(json['average_order_value']),
    );
  }
}

class SalesReportSalesmanBreakdown {
  final int salesmanId;
  final String salesmanName;
  final int ordersCount;
  final int totalSales;
  final int totalProfit;

  SalesReportSalesmanBreakdown({
    required this.salesmanId,
    required this.salesmanName,
    required this.ordersCount,
    required this.totalSales,
    required this.totalProfit,
  });

  factory SalesReportSalesmanBreakdown.fromJson(Map<String, dynamic> json) {
    return SalesReportSalesmanBreakdown(
      salesmanId: Formatters.parseInt(json['salesman_id']),
      salesmanName: json['salesman_name']?.toString() ?? '',
      ordersCount: Formatters.parseInt(json['orders_count']),
      totalSales: Formatters.parseInt(json['total_sales']),
      totalProfit: Formatters.parseInt(json['total_profit']),
    );
  }
}

class SalesReportRouteBreakdown {
  final int? routeId;
  final String routeName;
  final int ordersCount;
  final int totalSales;

  SalesReportRouteBreakdown({
    this.routeId,
    required this.routeName,
    required this.ordersCount,
    required this.totalSales,
  });

  factory SalesReportRouteBreakdown.fromJson(Map<String, dynamic> json) {
    return SalesReportRouteBreakdown(
      routeId: json['route_id'] != null ? Formatters.parseInt(json['route_id']) : null,
      routeName: json['route_name']?.toString() ?? '',
      ordersCount: Formatters.parseInt(json['orders_count']),
      totalSales: Formatters.parseInt(json['total_sales']),
    );
  }
}

class SalesReportOrderItem {
  final int id;
  final String orderNumber;
  final String orderDate;
  final String status;
  final String customerName;
  final String routeName;
  final String salesmanName;
  final String warehouseName;
  final int subtotal;
  final int discountAmount;
  final int totalAmount;
  final int totalProfit;

  SalesReportOrderItem({
    required this.id,
    required this.orderNumber,
    required this.orderDate,
    required this.status,
    required this.customerName,
    required this.routeName,
    required this.salesmanName,
    required this.warehouseName,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.totalProfit,
  });

  factory SalesReportOrderItem.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final route = customer?['route'] as Map<String, dynamic>?;
    final salesman = json['salesman'] as Map<String, dynamic>?;
    final warehouse = json['warehouse'] as Map<String, dynamic>?;

    return SalesReportOrderItem(
      id: Formatters.parseInt(json['id']),
      orderNumber: json['order_number']?.toString() ?? '',
      orderDate: (json['order_date'] ?? json['created_at'])?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      customerName: customer?['name']?.toString() ?? 'N/A',
      routeName: route?['name']?.toString() ?? 'بێ ڕێگا',
      salesmanName: salesman?['name']?.toString() ?? 'N/A',
      warehouseName: warehouse?['name']?.toString() ?? 'N/A',
      subtotal: Formatters.parseInt(json['subtotal']),
      discountAmount: Formatters.parseInt(json['discount_amount']),
      totalAmount: Formatters.parseInt(json['total_amount']),
      totalProfit: Formatters.parseInt(json['total_profit']),
    );
  }
}

class SalesReportData {
  final SalesReportSummary summary;
  final List<SalesReportSalesmanBreakdown> bySalesman;
  final List<SalesReportRouteBreakdown> byRoute;
  final List<SalesReportOrderItem> orders;

  SalesReportData({
    required this.summary,
    required this.bySalesman,
    required this.byRoute,
    required this.orders,
  });

  factory SalesReportData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final breakdownJson = json['breakdown'] as Map<String, dynamic>? ?? {};
    final ordersJson = json['orders'] as Map<String, dynamic>? ?? {};
    final ordersList = ordersJson['data'] as List? ?? [];

    final salesmanList = breakdownJson['by_salesman'] as List? ?? [];
    final routeList = breakdownJson['by_route'] as List? ?? [];

    return SalesReportData(
      summary: SalesReportSummary.fromJson(summaryJson),
      bySalesman: salesmanList
          .map(
            (e) => SalesReportSalesmanBreakdown.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      byRoute: routeList
          .map(
            (e) =>
                SalesReportRouteBreakdown.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      orders: ordersList
          .map((e) => SalesReportOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProfitReportSummary {
  final int totalRevenue;
  final int totalCost;
  final int totalProfit;
  final double totalUnitsSold;
  final double profitMarginPercent;

  ProfitReportSummary({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.totalUnitsSold,
    required this.profitMarginPercent,
  });

  factory ProfitReportSummary.fromJson(Map<String, dynamic> json) {
    return ProfitReportSummary(
      totalRevenue: Formatters.parseInt(json['total_revenue']),
      totalCost: Formatters.parseInt(json['total_cost']),
      totalProfit: Formatters.parseInt(json['total_profit']),
      totalUnitsSold: Formatters.parseDouble(json['total_units_sold']),
      profitMarginPercent: Formatters.parseDouble(json['profit_margin_percent']),
    );
  }
}

class ProfitProductBreakdown {
  final int productId;
  final String productName;
  final String sku;
  final String categoryName;
  final double unitsSold;
  final int totalRevenue;
  final int totalCost;
  final int totalProfit;
  final double marginPercent;

  ProfitProductBreakdown({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.categoryName,
    required this.unitsSold,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.marginPercent,
  });

  factory ProfitProductBreakdown.fromJson(Map<String, dynamic> json) {
    return ProfitProductBreakdown(
      productId: Formatters.parseInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      unitsSold: Formatters.parseDouble(json['units_sold']),
      totalRevenue: Formatters.parseInt(json['total_revenue']),
      totalCost: Formatters.parseInt(json['total_cost']),
      totalProfit: Formatters.parseInt(json['total_profit']),
      marginPercent: Formatters.parseDouble(json['margin_percent']),
    );
  }
}

class ProfitReportData {
  final ProfitReportSummary summary;
  final List<ProfitProductBreakdown> topProducts;

  ProfitReportData({required this.summary, required this.topProducts});

  factory ProfitReportData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final breakdownJson = json['breakdown'] as Map<String, dynamic>? ?? {};
    final productsList = breakdownJson['by_product'] as List? ?? [];

    return ProfitReportData(
      summary: ProfitReportSummary.fromJson(summaryJson),
      topProducts: productsList
          .map(
            (e) => ProfitProductBreakdown.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class SalesmanPerformanceItem {
  final int salesmanId;
  final String salesmanName;
  final String? phone;
  final double commissionRate;
  final int totalOrders;
  final int deliveredOrders;
  final int totalSales;
  final int totalProfit;
  final int lastMonthProfit;
  final int newCustomersThisMonth;
  final int newCustomersLastMonth;
  final int estimatedCommission;
  final int paymentsCollected;
  final int averageOrderValue;

  SalesmanPerformanceItem({
    required this.salesmanId,
    required this.salesmanName,
    this.phone,
    required this.commissionRate,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.totalSales,
    required this.totalProfit,
    this.lastMonthProfit = 0,
    this.newCustomersThisMonth = 0,
    this.newCustomersLastMonth = 0,
    required this.estimatedCommission,
    required this.paymentsCollected,
    required this.averageOrderValue,
  });

  factory SalesmanPerformanceItem.fromJson(Map<String, dynamic> json) {
    return SalesmanPerformanceItem(
      salesmanId: Formatters.parseInt(json['salesman_id']),
      salesmanName: json['salesman_name']?.toString() ?? '',
      phone: json['salesman_phone']?.toString(),
      commissionRate: Formatters.parseDouble(json['commission_rate']),
      totalOrders: Formatters.parseInt(json['total_orders']),
      deliveredOrders: Formatters.parseInt(json['delivered_orders']),
      totalSales: Formatters.parseInt(json['total_sales']),
      totalProfit: Formatters.parseInt(json['total_profit']),
      lastMonthProfit: Formatters.parseInt(json['last_month_profit']),
      newCustomersThisMonth: Formatters.parseInt(json['new_customers_this_month'] ?? json['new_customers']),
      newCustomersLastMonth: Formatters.parseInt(json['new_customers_last_month']),
      estimatedCommission: Formatters.parseInt(json['estimated_commission']),
      paymentsCollected: Formatters.parseInt(json['payments_collected']),
      averageOrderValue: Formatters.parseInt(json['average_order_value']),
    );
  }
}

class SalesBySalesmanReportData {
  final int totalSalesmen;
  final int totalSalesAmount;
  final int totalProfitAmount;
  final int totalCommission;
  final int totalCollectedCash;
  final List<SalesmanPerformanceItem> salesmen;

  SalesBySalesmanReportData({
    required this.totalSalesmen,
    required this.totalSalesAmount,
    required this.totalProfitAmount,
    required this.totalCommission,
    required this.totalCollectedCash,
    required this.salesmen,
  });

  factory SalesBySalesmanReportData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final list = json['salesmen'] as List? ?? [];

    return SalesBySalesmanReportData(
      totalSalesmen: Formatters.parseInt(summaryJson['total_salesmen']),
      totalSalesAmount: Formatters.parseInt(summaryJson['total_sales_amount']),
      totalProfitAmount: Formatters.parseInt(summaryJson['total_profit_amount']),
      totalCommission: Formatters.parseInt(summaryJson['total_commission']),
      totalCollectedCash: Formatters.parseInt(summaryJson['total_collected_cash']),
      salesmen: list
          .map(
            (e) => SalesmanPerformanceItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class LowStockItem {
  final int warehouseId;
  final String warehouseName;
  final int productId;
  final String productName;
  final String sku;
  final String barcode;
  final String unit;
  final String categoryName;
  final String supplierName;
  final double quantity;
  final double reservedQuantity;
  final double availableQuantity;
  final double minStockLevel;
  final double suggestedReorder;
  final int estimatedCost;

  LowStockItem({
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.categoryName,
    required this.supplierName,
    required this.quantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    required this.minStockLevel,
    required this.suggestedReorder,
    required this.estimatedCost,
  });

  factory LowStockItem.fromJson(Map<String, dynamic> json) {
    return LowStockItem(
      warehouseId: Formatters.parseInt(json['warehouse_id']),
      warehouseName: json['warehouse_name']?.toString() ?? '',
      productId: Formatters.parseInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      unit: (json['unit'] ?? 'PCS').toString(),
      categoryName: json['category_name']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      quantity: Formatters.parseDouble(json['quantity']),
      reservedQuantity: Formatters.parseDouble(json['reserved_quantity']),
      availableQuantity: Formatters.parseDouble(json['available_quantity']),
      minStockLevel: Formatters.parseDouble(json['min_stock_level']),
      suggestedReorder: Formatters.parseDouble(json['suggested_reorder']),
      estimatedCost: Formatters.parseInt(json['estimated_cost']),
    );
  }
}

class LowStockReportData {
  final int totalLowStockItems;
  final int estimatedReorderCost;
  final List<LowStockItem> items;

  LowStockReportData({
    required this.totalLowStockItems,
    required this.estimatedReorderCost,
    required this.items,
  });

  factory LowStockReportData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final list = json['items'] as List? ?? [];

    return LowStockReportData(
      totalLowStockItems: Formatters.parseInt(summaryJson['total_low_stock_items']),
      estimatedReorderCost: Formatters.parseInt(summaryJson['estimated_reorder_cost']),
      items: list
          .map((e) => LowStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StockTransferReportItem {
  final int id;
  final String? transferNumber;
  final String fromWarehouseName;
  final String toWarehouseName;
  final String status;
  final String? notes;
  final String? creatorName;
  final String createdAt;

  StockTransferReportItem({
    required this.id,
    this.transferNumber,
    required this.fromWarehouseName,
    required this.toWarehouseName,
    required this.status,
    this.notes,
    this.creatorName,
    required this.createdAt,
  });

  factory StockTransferReportItem.fromJson(Map<String, dynamic> json) {
    final from = json['from_warehouse'] as Map<String, dynamic>?;
    final to = json['to_warehouse'] as Map<String, dynamic>?;
    final creator = json['creator'] as Map<String, dynamic>?;

    return StockTransferReportItem(
      id: Formatters.parseInt(json['id']),
      transferNumber: json['transfer_number']?.toString(),
      fromWarehouseName: from?['name']?.toString() ?? '',
      toWarehouseName: to?['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      notes: json['notes']?.toString(),
      creatorName: creator?['name']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class StockTransfersReportData {
  final int totalTransfers;
  final int completedTransfers;
  final List<StockTransferReportItem> transfers;

  StockTransfersReportData({
    required this.totalTransfers,
    required this.completedTransfers,
    required this.transfers,
  });

  factory StockTransfersReportData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final transJson = json['transfers'] as Map<String, dynamic>? ?? {};
    final list = transJson['data'] as List? ?? [];

    return StockTransfersReportData(
      totalTransfers: Formatters.parseInt(summaryJson['total_transfers']),
      completedTransfers: Formatters.parseInt(summaryJson['completed_transfers']),
      transfers: list
          .map(
            (e) => StockTransferReportItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

