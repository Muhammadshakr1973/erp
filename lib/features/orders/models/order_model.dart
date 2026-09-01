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
  final String? sharedKey;
  final int version;
  final int customerId;
  final int salesmanId;
  final int? warehouseId;
  final double subtotal;
  final double permanentDiscountPercent;
  final double permanentDiscountAmount;
  final double discountAmount;
  final double discountPercent;
  final String discountType;
  final double totalAmount;
  final double totalProfit;
  final String status;
  final String? notes;
  final String createdAt;
  final dynamic customer;
  final dynamic salesman;
  final dynamic warehouse;
  final List<OrderItemModel> items;
  final bool pendingSync;

  OrderModel({
    required this.id,
    required this.orderNumber,
    this.sharedKey,
    this.version = 1,
    required this.customerId,
    required this.salesmanId,
    this.warehouseId,
    required this.subtotal,
    this.permanentDiscountPercent = 0.0,
    this.permanentDiscountAmount = 0.0,
    required this.discountAmount,
    required this.discountPercent,
    this.discountType = 'PERCENT',
    required this.totalAmount,
    required this.totalProfit,
    required this.status,
    this.notes,
    required this.createdAt,
    this.customer,
    this.salesman,
    this.warehouse,
    this.items = const [],
    this.pendingSync = false,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItemModel> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((itemJson) => OrderItemModel.fromJson(itemJson))
          .toList();
    }

    return OrderModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      orderNumber: json['order_number'] ?? '',
      sharedKey: json['shared_key']?.toString(),
      version: json['version'] is int ? json['version'] : (int.tryParse(json['version']?.toString() ?? '1') ?? 1),
      customerId: json['customer_id'] ?? 0,
      salesmanId: json['salesman_id'] ?? 0,
      warehouseId: json['warehouse_id'],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      permanentDiscountPercent:
          double.tryParse(
            json['permanent_discount_percent']?.toString() ?? '0',
          ) ??
          0.0,
      permanentDiscountAmount:
          double.tryParse(
            json['permanent_discount_amount']?.toString() ?? '0',
          ) ??
          0.0,
      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      discountPercent:
          double.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0.0,
      discountType: (json['discount_type'] ?? 'PERCENT').toString(),
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
      pendingSync: json['pending_sync'] == true || json['pending_sync'] == 1,
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
        return [statusPacking, statusCancelled];
      case statusPacking:
        return [statusReady, statusCancelled];
      case statusReady:
        return [statusInDelivery, statusCancelled];
      case statusInDelivery:
        return [statusDelivered, statusReady, statusCancelled];
      case statusDelivered:
      case statusCancelled:
      default:
        return [];
    }
  }
}
