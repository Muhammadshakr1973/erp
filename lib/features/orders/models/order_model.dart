class OrderModel {
  final int id;
  final String orderNumber;
  final int customerId;
  final int salesmanId;
  final double totalAmount;
  final String status;
  final String createdAt;
  final dynamic customer;
  final dynamic salesman;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.salesmanId,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.customer,
    this.salesman,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      customerId: json['customer_id'] ?? 0,
      salesmanId: json['salesman_id'] ?? 0,
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'PENDING',
      createdAt: json['created_at'] ?? '',
      customer: json['customer'],
      salesman: json['salesman'],
    );
  }
}
