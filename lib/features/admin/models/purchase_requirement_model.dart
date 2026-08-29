class PurchaseRequirementModel {
  final int id;
  final int productId;
  final String productName;
  final int warehouseId;
  final String warehouseName;
  final int? supplierId;
  final String? supplierName;
  final int requiredQuantity;
  final int currentStock;
  final bool isUrgent;
  final String status;
  final int? salesOrderId;
  final String? createdByName;

  PurchaseRequirementModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.warehouseId,
    required this.warehouseName,
    this.supplierId,
    this.supplierName,
    required this.requiredQuantity,
    required this.currentStock,
    required this.isUrgent,
    required this.status,
    this.salesOrderId,
    this.createdByName,
  });

  factory PurchaseRequirementModel.fromJson(Map<String, dynamic> json) {
    return PurchaseRequirementModel(
      id: json['id'],
      productId: json['product_id'],
      productName: json['product'] != null ? json['product']['name'] ?? '' : '',
      warehouseId: json['warehouse_id'],
      warehouseName: json['warehouse'] != null ? json['warehouse']['name'] ?? '' : '',
      supplierId: json['supplier_id'],
      supplierName: json['supplier'] != null ? json['supplier']['name'] ?? '' : null,
      requiredQuantity: json['required_quantity'] ?? 0,
      currentStock: json['current_stock'] ?? 0,
      isUrgent: json['is_urgent'] == true || json['is_urgent'] == 1,
      status: json['status'] ?? 'OPEN',
      salesOrderId: json['sales_order_id'],
      createdByName: json['creator'] != null ? json['creator']['name'] ?? '' : '',
    );
  }
}
