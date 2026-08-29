class WarehouseOrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String createdAt;
  final String customerName;
  final List<WarehouseOrderItemModel> items;

  WarehouseOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.items,
  });

  factory WarehouseOrderModel.fromJson(Map<String, dynamic> json) {
    final customerObj = json['customer'];
    final String cName = customerObj != null ? (customerObj['name'] ?? 'کڕیاری نەنوسراو') : 'کڕیاری نەنوسراو';

    final List itemsList = json['items'] ?? [];
    final List<WarehouseOrderItemModel> parsedItems = itemsList
        .map((itemJson) => WarehouseOrderItemModel.fromJson(itemJson))
        .toList();

    return WarehouseOrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'CONFIRMED',
      createdAt: json['created_at'] ?? '',
      customerName: cName,
      items: parsedItems,
    );
  }
}

class WarehouseOrderItemModel {
  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final bool isPacked;
  final String? packedAt;

  WarehouseOrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.isPacked,
    this.packedAt,
  });

  factory WarehouseOrderItemModel.fromJson(Map<String, dynamic> json) {
    final productObj = json['product'];
    final String pName = productObj != null ? (productObj['name'] ?? 'کاڵا') : 'کاڵا';

    // Handle is_packed as bool, check if it is 1 or true
    final rawPacked = json['is_packed'];
    final bool isPacked = rawPacked == true || rawPacked == 1;

    return WarehouseOrderItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: pName,
      quantity: json['quantity'] ?? 0,
      isPacked: isPacked,
      packedAt: json['packed_at'],
    );
  }

  WarehouseOrderItemModel copyWith({
    bool? isPacked,
    String? packedAt,
  }) {
    return WarehouseOrderItemModel(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      isPacked: isPacked ?? this.isPacked,
      packedAt: packedAt ?? this.packedAt,
    );
  }
}
