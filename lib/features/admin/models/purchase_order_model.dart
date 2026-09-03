class PurchaseOrderItemModel {
  final int id;
  final int purchaseOrderId;
  final int productId;
  final String productName;
  final int quantity;
  final int receivedQuantity;
  final num unitCost;
  final num totalCost;

  PurchaseOrderItemModel({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.receivedQuantity,
    required this.unitCost,
    required this.totalCost,
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemModel(
      id: json['id'] ?? 0,
      purchaseOrderId: json['purchase_order_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product'] != null
          ? json['product']['name'] ?? ''
          : '',
      quantity: json['quantity'] ?? 0,
      receivedQuantity: json['received_quantity'] ?? 0,
      unitCost: json['unit_cost'] ?? 0,
      totalCost: json['total_cost'] ?? 0,
    );
  }

  int get remainingQuantity => quantity - receivedQuantity;
}

class PurchaseOrderModel {
  final int id;
  final String orderNumber;
  final int supplierId;
  final String supplierName;
  final int warehouseId;
  final String warehouseName;
  final String status;
  final num totalAmount;
  final String? notes;
  final DateTime? receivedAt;
  final int itemsCount;
  final List<PurchaseOrderItemModel> items;

  PurchaseOrderModel({
    required this.id,
    required this.orderNumber,
    required this.supplierId,
    required this.supplierName,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.totalAmount,
    this.notes,
    this.receivedAt,
    required this.itemsCount,
    required this.items,
  });

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
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      supplierId: json['supplier_id'] ?? 0,
      supplierName: json['supplier'] != null
          ? json['supplier']['name'] ?? ''
          : '',
      warehouseId: json['warehouse_id'] ?? 0,
      warehouseName: json['warehouse'] != null
          ? json['warehouse']['name'] ?? ''
          : '',
      status: json['status'] ?? 'DRAFT',
      totalAmount: json['total_amount'] ?? 0,
      notes: json['notes'],
      receivedAt: parsedReceivedAt,
      itemsCount: itemsList != null ? itemsList.length : 0,
      items: parsedItems,
    );
  }
}

