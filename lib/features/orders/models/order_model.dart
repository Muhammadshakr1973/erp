class OrderItemModel {
  final int id;
  final int orderId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final bool isPacked;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.isPacked,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] ?? 0,
      orderId: json['sales_order_id'] ?? json['order_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product'] != null
          ? (json['product']['name'] ?? 'کاڵا')
          : (json['product_name'] ?? 'کاڵا'),
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      isPacked: json['is_packed'] == true || json['is_packed'] == 1,
    );
  }
}

class OrderModel {
  static const String statusDraft = 'DRAFT';
  static const String statusConfirmed = 'CONFIRMED';
  static const String statusPacking = 'PACKING';
  static const String statusReady = 'READY';
  static const String statusInDelivery = 'IN_DELIVERY';
  static const String statusDelivered = 'DELIVERED';
  static const String statusCancelled = 'CANCELLED';

  final int id;
  final String orderNumber;
  final int customerId;
  final int salesmanId;
  final int? warehouseId;
  final double subtotal;
  final double discountAmount;
  final double discountPercent;
  final double totalAmount;
  final double totalProfit;
  final String status;
  final String? notes;
  final String createdAt;
  final dynamic customer;
  final dynamic salesman;
  final dynamic warehouse;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.salesmanId,
    this.warehouseId,
    required this.subtotal,
    required this.discountAmount,
    required this.discountPercent,
    required this.totalAmount,
    required this.totalProfit,
    required this.status,
    this.notes,
    required this.createdAt,
    this.customer,
    this.salesman,
    this.warehouse,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItemModel> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((itemJson) => OrderItemModel.fromJson(itemJson))
          .toList();
    }

    return OrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      customerId: json['customer_id'] ?? 0,
      salesmanId: json['salesman_id'] ?? 0,
      warehouseId: json['warehouse_id'],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      discountPercent:
          double.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0.0,
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      totalProfit:
          double.tryParse(json['total_profit']?.toString() ?? '0') ?? 0.0,
      status: (json['status'] ?? 'DRAFT').toString().toUpperCase(),
      notes: json['notes'],
      createdAt: json['created_at'] ?? '',
      customer: json['customer'],
      salesman: json['salesman'],
      warehouse: json['warehouse'],
      items: parsedItems,
    );
  }

  String get localizedStatus {
    switch (status) {
      case statusDraft:
        return 'داڕشتن (Draft)';
      case statusConfirmed:
        return 'پشتڕاستکراوەتەوە';
      case statusPacking:
        return 'لە پاکەتکردندایە';
      case statusReady:
        return 'ئامادەیە بۆ ناردن';
      case statusInDelivery:
        return 'لە ڕێگەی گەیاندندایە';
      case statusDelivered:
        return 'گەیشتووە';
      case statusCancelled:
        return 'هەڵوەشاوەتەوە';
      default:
        return status;
    }
  }

  bool get isTerminal =>
      status == statusDelivered || status == statusCancelled;

  bool get canCancel => !isTerminal;

  List<String> get allowedNextStatuses {
    switch (status) {
      case statusDraft:
        return [statusConfirmed, statusCancelled];
      case statusConfirmed:
        return [statusPacking, statusReady, statusCancelled];
      case statusPacking:
        return [statusReady, statusCancelled];
      case statusReady:
        return [statusInDelivery, statusCancelled];
      case statusInDelivery:
        return [statusDelivered, statusCancelled];
      case statusDelivered:
      case statusCancelled:
      default:
        return [];
    }
  }
}
