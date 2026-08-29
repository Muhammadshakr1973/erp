class CommissionDetailModel {
  final int id;
  final int salesmanCommissionId;
  final int salesOrderId;
  final String? orderNumber;
  final String? customerName;
  final int salesAmount;
  final int profitAmount;
  final int commissionAmount;

  CommissionDetailModel({
    required this.id,
    required this.salesmanCommissionId,
    required this.salesOrderId,
    this.orderNumber,
    this.customerName,
    required this.salesAmount,
    required this.profitAmount,
    required this.commissionAmount,
  });

  factory CommissionDetailModel.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    final customer = order?['customer'] as Map<String, dynamic>?;

    return CommissionDetailModel(
      id: json['id'] ?? 0,
      salesmanCommissionId: json['salesman_commission_id'] ?? json['commission_id'] ?? 0,
      salesOrderId: json['sales_order_id'] ?? 0,
      orderNumber: order?['order_number']?.toString() ?? json['order_number']?.toString(),
      customerName: customer?['name'] ?? json['customer_name'],
      salesAmount: (json['sales_amount'] as num?)?.toInt() ?? 0,
      profitAmount: (json['profit_amount'] as num?)?.toInt() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommissionModel {
  final int id;
  final int salesmanId;
  final String salesmanName;
  final String? salesmanPhone;
  final String periodFrom;
  final String periodTo;
  final int totalSales;
  final int totalProfit;
  final double commissionRate;
  final int commissionAmount;
  final String status;
  final String? calculatedByName;
  final String? approvedByName;
  final String? approvedAt;
  final String? paidByName;
  final String? paidAt;
  final String? paymentMethod;
  final String? cancelledByName;
  final String? cancelledAt;
  final String? cancellationReason;
  final String? notes;
  final String? createdAt;
  final List<CommissionDetailModel> details;

  CommissionModel({
    required this.id,
    required this.salesmanId,
    required this.salesmanName,
    this.salesmanPhone,
    required this.periodFrom,
    required this.periodTo,
    required this.totalSales,
    required this.totalProfit,
    required this.commissionRate,
    required this.commissionAmount,
    required this.status,
    this.calculatedByName,
    this.approvedByName,
    this.approvedAt,
    this.paidByName,
    this.paidAt,
    this.paymentMethod,
    this.cancelledByName,
    this.cancelledAt,
    this.cancellationReason,
    this.notes,
    this.createdAt,
    this.details = const [],
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    final salesman = json['salesman'] as Map<String, dynamic>?;
    final calculator = json['calculator'] as Map<String, dynamic>?;
    final approver = json['approver'] as Map<String, dynamic>?;
    final payer = json['payer'] as Map<String, dynamic>?;
    final canceller = json['canceller'] as Map<String, dynamic>?;
    final rawDetails = json['details'] as List<dynamic>? ?? [];

    return CommissionModel(
      id: json['id'] ?? 0,
      salesmanId: json['salesman_id'] ?? 0,
      salesmanName: salesman?['name'] ?? json['salesman_name'] ?? 'مەندوب',
      salesmanPhone: salesman?['phone'] ?? json['salesman_phone'],
      periodFrom: (json['period_from'] as String?)?.split('T').first ?? '',
      periodTo: (json['period_to'] as String?)?.split('T').first ?? '',
      totalSales: (json['total_sales'] as num?)?.toInt() ?? 0,
      totalProfit: (json['total_profit'] ?? json['profit_amount'] as num?)?.toInt() ?? 0,
      commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '0') ?? 0.0,
      commissionAmount: (json['commission_amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?)?.toLowerCase() ?? 'calculated',
      calculatedByName: calculator?['name'],
      approvedByName: approver?['name'],
      approvedAt: json['approved_at'],
      paidByName: payer?['name'],
      paidAt: json['paid_at'],
      paymentMethod: json['payment_method'],
      cancelledByName: canceller?['name'],
      cancelledAt: json['cancelled_at'],
      cancellationReason: json['cancellation_reason'],
      notes: json['notes'],
      createdAt: json['created_at'],
      details: rawDetails.map((e) => CommissionDetailModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
