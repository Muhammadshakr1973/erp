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
  final int itemsCount;

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
    required this.itemsCount,
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List?;
    return PurchaseOrderModel(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      supplierId: json['supplier_id'] ?? 0,
      supplierName: json['supplier'] != null ? json['supplier']['name'] ?? '' : '',
      warehouseId: json['warehouse_id'] ?? 0,
      warehouseName: json['warehouse'] != null ? json['warehouse']['name'] ?? '' : '',
      status: json['status'] ?? 'DRAFT',
      totalAmount: json['total_amount'] ?? 0,
      notes: json['notes'],
      itemsCount: itemsList != null ? itemsList.length : 0,
    );
  }
}
