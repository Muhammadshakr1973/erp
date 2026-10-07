class WarehouseOrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String createdAt;
  final String customerName;
  final String salesmanName;
  final List<WarehouseOrderItemModel> items;

  WarehouseOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.customerName,
    this.salesmanName = 'مەندوبی دیارینەکراو',
    required this.items,
  });

  factory WarehouseOrderModel.fromJson(Map<String, dynamic> json) {
    final customerObj = json['customer'];
    final String cName = customerObj != null
        ? (customerObj['name'] ?? 'کڕیاری نەنوسراو')
        : 'کڕیاری نەنوسراو';

    final salesmanObj = json['salesman'] ?? json['creator'];
    final String sName = salesmanObj != null
        ? (salesmanObj['name'] ?? 'مەندوبی دیارینەکراو')
        : (json['salesman_name'] ?? 'مەندوبی دیارینەکراو');

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
      salesmanName: sName,
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
  final String? productUnit;
  final int? unitsPerCarton;
  final String? productImagePath;
  final String? sku;

  WarehouseOrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.isPacked,
    this.packedAt,
    this.productUnit,
    this.unitsPerCarton,
    this.productImagePath,
    this.sku,
  });

  factory WarehouseOrderItemModel.fromJson(Map<String, dynamic> json) {
    final productObj = json['product'] as Map<String, dynamic>?;
    final String pName = productObj != null
        ? (productObj['name'] ?? 'کاڵا')
        : 'کاڵا';

    // Handle is_packed as bool, check if it is 1 or true
    final rawPacked = json['is_packed'];
    final bool isPacked = rawPacked == true || rawPacked == 1;

    final imgPath = productObj != null
        ? (productObj['image_path'] ?? productObj['image_url'] ?? productObj['image'])
        : (json['product_image_path'] ?? json['image_path'] ?? json['image_url']);

    final String? pSku = productObj != null
        ? productObj['sku']?.toString()
        : json['sku']?.toString();

    return WarehouseOrderItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: pName,
      quantity: json['quantity'] ?? 0,
      isPacked: isPacked,
      packedAt: json['packed_at'],
      productUnit: productObj != null ? (productObj['unit'] ?? 'دانە') : (json['product_unit'] ?? 'دانە'),
      unitsPerCarton: productObj != null ? (productObj['units_per_carton'] ?? 1) : (json['units_per_carton'] ?? 1),
      productImagePath: imgPath?.toString(),
      sku: pSku,
    );
  }

  WarehouseOrderItemModel copyWith({bool? isPacked, String? packedAt}) {
    return WarehouseOrderItemModel(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      isPacked: isPacked ?? this.isPacked,
      packedAt: packedAt ?? this.packedAt,
      productUnit: productUnit,
      unitsPerCarton: unitsPerCarton,
      productImagePath: productImagePath,
      sku: sku,
    );
  }
}
