class WarehouseStockModel {
  final int id;
  final int warehouseId;
  final String warehouseName;
  final int productId;
  final String productName;
  final String barcode;
  final int quantity;
  final int reservedQuantity;

  WarehouseStockModel({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.reservedQuantity,
  });

  factory WarehouseStockModel.fromJson(Map<String, dynamic> json) {
    final warehouseObj = json['warehouse'];
    final String wName = warehouseObj != null
        ? (warehouseObj['name'] ?? 'کۆگا')
        : 'کۆگا';

    final productObj = json['product'];
    final String pName = productObj != null
        ? (productObj['name'] ?? 'کاڵا')
        : 'کاڵا';
    final String pBarcode = productObj != null
        ? (productObj['barcode'] ?? '')
        : '';

    return WarehouseStockModel(
      id: json['id'] ?? 0,
      warehouseId: json['warehouse_id'] ?? 0,
      warehouseName: wName,
      productId: json['product_id'] ?? 0,
      productName: pName,
      barcode: pBarcode,
      quantity: json['quantity'] ?? 0,
      reservedQuantity: json['reserved_quantity'] ?? 0,
    );
  }
}
