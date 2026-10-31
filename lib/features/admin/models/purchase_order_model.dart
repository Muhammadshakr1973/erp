class PurchaseOrderItemModel {
  final int id;
  final int purchaseOrderId;
  final int productId;
  final String productName;
  final String? productUnit;
  final int unitsPerCarton;
  final double quantity;
  final double receivedQuantity;
  final num unitCost;
  final num totalCost;

  PurchaseOrderItemModel({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    required this.productName,
    this.productUnit,
    this.unitsPerCarton = 1,
    required this.quantity,
    required this.receivedQuantity,
    required this.unitCost,
    required this.totalCost,
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] is Map ? json['product'] as Map : null;
    final int upc = productMap != null
        ? ((productMap['units_per_carton'] as num?)?.toInt() ?? 1)
        : ((json['units_per_carton'] as num?)?.toInt() ?? 1);
    final String? unit = productMap != null
        ? productMap['unit']?.toString()
        : json['product_unit']?.toString();

    return PurchaseOrderItemModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      purchaseOrderId: json['purchase_order_id'] is int
          ? json['purchase_order_id']
          : (int.tryParse(json['purchase_order_id']?.toString() ?? '0') ?? 0),
      productId: json['product_id'] is int
          ? json['product_id']
          : (int.tryParse(json['product_id']?.toString() ?? '0') ?? 0),
      productName: productMap != null
          ? productMap['name']?.toString() ?? ''
          : (json['product_name']?.toString() ?? ''),
      productUnit: unit,
      unitsPerCarton: upc > 0 ? upc : 1,
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      receivedQuantity: double.tryParse(json['received_quantity']?.toString() ?? '0') ?? 0.0,
      unitCost: num.tryParse(json['unit_cost']?.toString() ?? '0') ?? 0,
      totalCost: num.tryParse(json['total_cost']?.toString() ?? '0') ?? 0,
    );
  }

  double get remainingQuantity => quantity - receivedQuantity;
}

class PurchaseOrderModel {
  final int id;
  final String orderNumber;
  final int supplierId;
  final String supplierName;
  final String? supplierPhone;
  final int warehouseId;
  final String warehouseName;
  final String status;
  final num totalAmount;
  final num paidAmount;
  final String? notes;
  final DateTime? receivedAt;
  final String? createdAt;
  final int itemsCount;
  final List<PurchaseOrderItemModel> items;

  PurchaseOrderModel({
    required this.id,
    required this.orderNumber,
    required this.supplierId,
    required this.supplierName,
    this.supplierPhone,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.totalAmount,
    this.paidAmount = 0,
    this.notes,
    this.receivedAt,
    this.createdAt,
    required this.itemsCount,
    required this.items,
  });

  num get remainingDebt {
    final debt = totalAmount - paidAmount;
    return debt > 0 ? debt : 0;
  }

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List?;
    final parsedItems = itemsList != null
        ? itemsList.map((item) => PurchaseOrderItemModel.fromJson(item)).toList()
        : <PurchaseOrderItemModel>[];

    DateTime? parsedReceivedAt;
    if (json['received_at'] != null) {
      parsedReceivedAt = DateTime.tryParse(json['received_at'].toString());
    }

    return PurchaseOrderModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      orderNumber: json['order_number']?.toString() ?? '',
      supplierId: json['supplier_id'] is int
          ? json['supplier_id']
          : (int.tryParse(json['supplier_id']?.toString() ?? '0') ?? 0),
      supplierName: json['supplier'] != null
          ? json['supplier']['name']?.toString() ?? ''
          : '',
      supplierPhone: json['supplier'] is Map
          ? json['supplier']['phone']?.toString()
          : null,
      warehouseId: json['warehouse_id'] is int
          ? json['warehouse_id']
          : (int.tryParse(json['warehouse_id']?.toString() ?? '0') ?? 0),
      warehouseName: json['warehouse'] != null
          ? json['warehouse']['name']?.toString() ?? ''
          : '',
      status: json['status']?.toString() ?? 'DRAFT',
      totalAmount: num.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      paidAmount: num.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0,
      notes: json['notes']?.toString(),
      receivedAt: parsedReceivedAt,
      createdAt: json['created_at']?.toString(),
      itemsCount: itemsList != null ? itemsList.length : 0,
      items: parsedItems,
    );
  }
}
