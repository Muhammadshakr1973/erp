class OrderItemModel {
  final int id;
  final int orderId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final bool isPacked;
  final String? notes;
  final String? productUnit;
  final int? unitsPerCarton;
  final String? productImagePath;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.isPacked,
    this.notes,
    this.productUnit,
    this.unitsPerCarton,
    this.productImagePath,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>?;
    final imgPath = productJson != null
        ? (productJson['image_path'] ?? productJson['image_url'] ?? productJson['image'])
        : (json['product_image_path'] ?? json['image_path'] ?? json['image_url']);

    return OrderItemModel(
      id: json['id'] ?? 0,
      orderId: json['sales_order_id'] ?? json['order_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product'] != null
          ? (json['product']['name'] ?? 'کاڵا')
          : (json['product_name'] ?? 'کاڵا'),
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse((json['subtotal'] ?? json['total_price'] ?? json['line_total'])?.toString() ?? '0') ?? 0.0,
      isPacked: json['is_packed'] == true || json['is_packed'] == 1,
      notes: json['notes'],
      productUnit: productJson != null ? (productJson['unit'] ?? 'دانە') : (json['product_unit'] ?? 'دانە'),
      unitsPerCarton: productJson != null ? (productJson['units_per_carton'] ?? 1) : (json['units_per_carton'] ?? 1),
      productImagePath: imgPath?.toString(),
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
  final String? priceType;

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
    this.discountType = 'FIXED',
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
    this.priceType,
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
      discountType: (json['discount_type'] ?? 'FIXED').toString(),
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      totalProfit:
          double.tryParse(json['total_profit']?.toString() ?? '0') ?? 0.0,
      status: (json['status'] ?? 'PACKING').toString().toUpperCase(),
      notes: json['notes'],
      createdAt: json['created_at'] ?? '',
      customer: json['customer'],
      salesman: json['salesman'],
      warehouse: json['warehouse'],
      items: parsedItems,
      pendingSync: json['pending_sync'] == true || json['pending_sync'] == 1,
      priceType: json['price_type']?.toString(),
    );
  }

  OrderModel copyWith({
    int? id,
    String? orderNumber,
    String? sharedKey,
    int? version,
    int? customerId,
    int? salesmanId,
    int? warehouseId,
    double? subtotal,
    double? permanentDiscountPercent,
    double? permanentDiscountAmount,
    double? discountAmount,
    double? discountPercent,
    String? discountType,
    double? totalAmount,
    double? totalProfit,
    String? status,
    String? notes,
    String? createdAt,
    dynamic customer,
    dynamic salesman,
    dynamic warehouse,
    List<OrderItemModel>? items,
    bool? pendingSync,
    String? priceType,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      sharedKey: sharedKey ?? this.sharedKey,
      version: version ?? this.version,
      customerId: customerId ?? this.customerId,
      salesmanId: salesmanId ?? this.salesmanId,
      warehouseId: warehouseId ?? this.warehouseId,
      subtotal: subtotal ?? this.subtotal,
      permanentDiscountPercent: permanentDiscountPercent ?? this.permanentDiscountPercent,
      permanentDiscountAmount: permanentDiscountAmount ?? this.permanentDiscountAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      discountType: discountType ?? this.discountType,
      totalAmount: totalAmount ?? this.totalAmount,
      totalProfit: totalProfit ?? this.totalProfit,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      salesman: salesman ?? this.salesman,
      warehouse: warehouse ?? this.warehouse,
      items: items ?? this.items,
      pendingSync: pendingSync ?? this.pendingSync,
      priceType: priceType ?? this.priceType,
    );
  }

  String get customerName {
    if (customerId == 0) return 'کڕیاری کاتی (بێ ناو)';
    if (customer == null) return 'کڕیاری نەناسراو';
    if (customer is Map) return customer['name']?.toString() ?? 'کڕیاری نەناسراو';
    try {
      final nameVal = (customer as dynamic).name;
      if (nameVal != null) return nameVal.toString();
    } catch (_) {}
    return 'کڕیاری نەناسراو';
  }

  String get customerRouteName {
    if (customer == null) return 'ڕاوت دیاری نەکراوە';
    if (customer is Map) {
      if (customer['route'] != null && customer['route'] is Map) {
        final rName = customer['route']['name']?.toString();
        if (rName != null && rName.trim().isNotEmpty) return rName.trim();
      }
      final rNameDirect = customer['route_name']?.toString();
      if (rNameDirect != null && rNameDirect.trim().isNotEmpty) return rNameDirect.trim();
    }
    try {
      final routeVal = (customer as dynamic).route;
      if (routeVal != null) {
        final rName = (routeVal as dynamic).name;
        if (rName != null && rName.toString().trim().isNotEmpty) return rName.toString().trim();
      }
    } catch (_) {}
    return 'ڕاوت دیاری نەکراوە';
  }

  String get customerAddress {
    if (customer == null) return 'ناونیشان دیاری نەکراوە';
    if (customer is Map) {
      final addr = customer['address']?.toString() ?? '';
      return addr.trim().isNotEmpty ? addr.trim() : 'ناونیشان دیاری نەکراوە';
    }
    try {
      final addrVal = (customer as dynamic).address;
      if (addrVal != null && addrVal.toString().trim().isNotEmpty) {
        return addrVal.toString().trim();
      }
    } catch (_) {}
    return 'ناونیشان دیاری نەکراوە';
  }

  double? get customerLatitude {
    if (customer == null) return null;
    if (customer is Map) {
      return double.tryParse(customer['latitude']?.toString() ?? '');
    }
    try {
      final lat = (customer as dynamic).latitude;
      if (lat != null) return double.tryParse(lat.toString());
    } catch (_) {}
    return null;
  }

  double? get customerLongitude {
    if (customer == null) return null;
    if (customer is Map) {
      return double.tryParse(customer['longitude']?.toString() ?? '');
    }
    try {
      final lng = (customer as dynamic).longitude;
      if (lng != null) return double.tryParse(lng.toString());
    } catch (_) {}
    return null;
  }

  String get salesmanName {
    if (salesman == null) return 'مەندوبی نەناسراو';
    if (salesman is Map) return salesman['name']?.toString() ?? 'مەندوبی نەناسراو';
    try {
      final nameVal = (salesman as dynamic).name;
      if (nameVal != null) return nameVal.toString();
    } catch (_) {}
    return 'مەندوبی نەناسراو';
  }

  String get warehouseName {
    if (warehouse == null) return 'کۆگای نەناسراو';
    if (warehouse is Map) return warehouse['name']?.toString() ?? 'کۆگای نەناسراو';
    try {
      final nameVal = (warehouse as dynamic).name;
      if (nameVal != null) return nameVal.toString();
    } catch (_) {}
    return 'کۆگای نەناسراو';
  }

  String get localizedStatus {
    switch (status) {
      case statusDraft:
        return 'داڕشتن (کۆن)';
      case statusConfirmed:
        return 'پشتڕاستکراوەتەوە (کۆن)';
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
      case statusPacking:
        return [statusReady, statusCancelled];
      case statusReady:
        return [statusInDelivery, statusCancelled];
      case statusInDelivery:
        return [statusDelivered, statusReady, statusCancelled];
      case statusDraft:
        return [statusPacking, statusCancelled];
      case statusConfirmed:
        return [statusPacking, statusReady, statusCancelled];
      case statusDelivered:
      case statusCancelled:
      default:
        return [];
    }
  }
}
