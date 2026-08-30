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
      totalOrdersCount: (json['total_orders_count'] ?? 0) as int,
      totalDeliveredCount: (json['total_delivered_count'] ?? 0) as int,
      totalGrossAmount: (json['total_gross_amount'] ?? 0) as int,
      totalDiscountAmount: (json['total_discount_amount'] ?? 0) as int,
      totalNetSales: (json['total_net_sales'] ?? 0) as int,
      totalCostAmount: (json['total_cost_amount'] ?? 0) as int,
      totalProfitAmount: (json['total_profit_amount'] ?? 0) as int,
      averageOrderValue: (json['average_order_value'] ?? 0) as int,
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
      salesmanId: (json['salesman_id'] ?? 0) as int,
      salesmanName: (json['salesman_name'] ?? '') as String,
      ordersCount: (json['orders_count'] ?? 0) as int,
      totalSales: (json['total_sales'] ?? 0) as int,
      totalProfit: (json['total_profit'] ?? 0) as int,
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
      routeId: json['route_id'] as int?,
      routeName: (json['route_name'] ?? '') as String,
      ordersCount: (json['orders_count'] ?? 0) as int,
      totalSales: (json['total_sales'] ?? 0) as int,
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
      id: (json['id'] ?? 0) as int,
      orderNumber: (json['order_number'] ?? '') as String,
      orderDate: (json['order_date'] ?? json['created_at'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      customerName: (customer?['name'] ?? 'N/A') as String,
      routeName: (route?['name'] ?? 'بێ ڕێگا') as String,
      salesmanName: (salesman?['name'] ?? 'N/A') as String,
      warehouseName: (warehouse?['name'] ?? 'N/A') as String,
      subtotal: (json['subtotal'] ?? 0) as int,
      discountAmount: (json['discount_amount'] ?? 0) as int,
      totalAmount: (json['total_amount'] ?? 0) as int,
      totalProfit: (json['total_profit'] ?? 0) as int,
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
  final int totalUnitsSold;
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
      totalRevenue: (json['total_revenue'] ?? 0) as int,
      totalCost: (json['total_cost'] ?? 0) as int,
      totalProfit: (json['total_profit'] ?? 0) as int,
      totalUnitsSold: (json['total_units_sold'] ?? 0) as int,
      profitMarginPercent: (json['profit_margin_percent'] ?? 0.0) is int
          ? ((json['profit_margin_percent'] ?? 0) as int).toDouble()
          : (json['profit_margin_percent'] ?? 0.0) as double,
    );
  }
}

class ProfitProductBreakdown {
  final int productId;
  final String productName;
  final String sku;
  final String categoryName;
  final int unitsSold;
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
      productId: (json['product_id'] ?? 0) as int,
      productName: (json['product_name'] ?? '') as String,
      sku: (json['sku'] ?? '') as String,
      categoryName: (json['category_name'] ?? '') as String,
      unitsSold: (json['units_sold'] ?? 0) as int,
      totalRevenue: (json['total_revenue'] ?? 0) as int,
      totalCost: (json['total_cost'] ?? 0) as int,
      totalProfit: (json['total_profit'] ?? 0) as int,
      marginPercent: (json['margin_percent'] ?? 0.0) is int
          ? ((json['margin_percent'] ?? 0) as int).toDouble()
          : (json['margin_percent'] ?? 0.0) as double,
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
    required this.estimatedCommission,
    required this.paymentsCollected,
    required this.averageOrderValue,
  });

  factory SalesmanPerformanceItem.fromJson(Map<String, dynamic> json) {
    return SalesmanPerformanceItem(
      salesmanId: (json['salesman_id'] ?? 0) as int,
      salesmanName: (json['salesman_name'] ?? '') as String,
      phone: json['salesman_phone'] as String?,
      commissionRate: (json['commission_rate'] ?? 0.0) is int
          ? ((json['commission_rate'] ?? 0) as int).toDouble()
          : (json['commission_rate'] ?? 0.0) as double,
      totalOrders: (json['total_orders'] ?? 0) as int,
      deliveredOrders: (json['delivered_orders'] ?? 0) as int,
      totalSales: (json['total_sales'] ?? 0) as int,
      totalProfit: (json['total_profit'] ?? 0) as int,
      estimatedCommission: (json['estimated_commission'] ?? 0) as int,
      paymentsCollected: (json['payments_collected'] ?? 0) as int,
      averageOrderValue: (json['average_order_value'] ?? 0) as int,
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
      totalSalesmen: (summaryJson['total_salesmen'] ?? 0) as int,
      totalSalesAmount: (summaryJson['total_sales_amount'] ?? 0) as int,
      totalProfitAmount: (summaryJson['total_profit_amount'] ?? 0) as int,
      totalCommission: (summaryJson['total_commission'] ?? 0) as int,
      totalCollectedCash: (summaryJson['total_collected_cash'] ?? 0) as int,
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
  final int quantity;
  final int reservedQuantity;
  final int availableQuantity;
  final int minStockLevel;
  final int suggestedReorder;
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
      warehouseId: (json['warehouse_id'] ?? 0) as int,
      warehouseName: (json['warehouse_name'] ?? '') as String,
      productId: (json['product_id'] ?? 0) as int,
      productName: (json['product_name'] ?? '') as String,
      sku: (json['sku'] ?? '') as String,
      barcode: (json['barcode'] ?? '') as String,
      unit: (json['unit'] ?? 'PCS') as String,
      categoryName: (json['category_name'] ?? '') as String,
      supplierName: (json['supplier_name'] ?? '') as String,
      quantity: (json['quantity'] ?? 0) as int,
      reservedQuantity: (json['reserved_quantity'] ?? 0) as int,
      availableQuantity: (json['available_quantity'] ?? 0) as int,
      minStockLevel: (json['min_stock_level'] ?? 0) as int,
      suggestedReorder: (json['suggested_reorder'] ?? 0) as int,
      estimatedCost: (json['estimated_cost'] ?? 0) as int,
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
      totalLowStockItems: (summaryJson['total_low_stock_items'] ?? 0) as int,
      estimatedReorderCost: (summaryJson['estimated_reorder_cost'] ?? 0) as int,
      items: list
          .map((e) => LowStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StockMovementItem {
  final int id;
  final String warehouseName;
  final String productName;
  final String sku;
  final String unit;
  final String type;
  final int quantityChange;
  final int quantityAfter;
  final String? referenceType;
  final int? referenceId;
  final String? notes;
  final String createdAt;

  StockMovementItem({
    required this.id,
    required this.warehouseName,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.type,
    required this.quantityChange,
    required this.quantityAfter,
    this.referenceType,
    this.referenceId,
    this.notes,
    required this.createdAt,
  });

  factory StockMovementItem.fromJson(Map<String, dynamic> json) {
    final warehouse = json['warehouse'] as Map<String, dynamic>?;
    final product = json['product'] as Map<String, dynamic>?;

    return StockMovementItem(
      id: (json['id'] ?? 0) as int,
      warehouseName: (warehouse?['name'] ?? '') as String,
      productName: (product?['name'] ?? '') as String,
      sku: (product?['sku'] ?? '') as String,
      unit: (product?['unit'] ?? 'PCS') as String,
      type: (json['type'] ?? '') as String,
      quantityChange: (json['quantity_change'] ?? 0) as int,
      quantityAfter: (json['quantity_after'] ?? 0) as int,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as int?,
      notes: json['notes'] as String?,
      createdAt: (json['created_at'] ?? '') as String,
    );
  }
}

class StockMovementsReportData {
  final int totalTransactions;
  final int totalQuantityIn;
  final int totalQuantityOut;
  final List<StockMovementItem> transactions;

  StockMovementsReportData({
    required this.totalTransactions,
    required this.totalQuantityIn,
    required this.totalQuantityOut,
    required this.transactions,
  });

  factory StockMovementsReportData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final transJson = json['transactions'] as Map<String, dynamic>? ?? {};
    final list = transJson['data'] as List? ?? [];

    return StockMovementsReportData(
      totalTransactions: (summaryJson['total_transactions'] ?? 0) as int,
      totalQuantityIn: (summaryJson['total_quantity_in'] ?? 0) as int,
      totalQuantityOut: (summaryJson['total_quantity_out'] ?? 0) as int,
      transactions: list
          .map((e) => StockMovementItem.fromJson(e as Map<String, dynamic>))
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
      id: (json['id'] ?? 0) as int,
      transferNumber: json['transfer_number'] as String?,
      fromWarehouseName: (from?['name'] ?? '') as String,
      toWarehouseName: (to?['name'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      notes: json['notes'] as String?,
      creatorName: creator?['name'] as String?,
      createdAt: (json['created_at'] ?? '') as String,
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
      totalTransfers: (summaryJson['total_transfers'] ?? 0) as int,
      completedTransfers: (summaryJson['completed_transfers'] ?? 0) as int,
      transfers: list
          .map(
            (e) => StockTransferReportItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
