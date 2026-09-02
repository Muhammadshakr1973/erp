class WarehouseStockModel {
  final int id;
  final int warehouseId;
  final String warehouseName;
  final int productId;
  final String productName;
  final String barcode;
  final int quantity;
  final int reservedQuantity;
  final int minStockLevel;

  WarehouseStockModel({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.reservedQuantity,
    required this.minStockLevel,
  });

  /// Authoritative available stock calculation per GARDI stock equation:
  /// Available = Physical Quantity - Reserved Quantity
  int get availableQuantity => quantity - reservedQuantity;

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
      minStockLevel: json['min_stock_level'] ?? 0,
    );
  }
}

class StockReconciliationModel {
  final bool isConsistent;
  final int storedQuantity;
  final int recalculatedQuantity;
  final int storedReserved;
  final int recalculatedReserved;
  final List<String> discrepancies;

  StockReconciliationModel({
    required this.isConsistent,
    required this.storedQuantity,
    required this.recalculatedQuantity,
    required this.storedReserved,
    required this.recalculatedReserved,
    required this.discrepancies,
  });

  factory StockReconciliationModel.fromJson(Map<String, dynamic> json) {
    return StockReconciliationModel(
      isConsistent: json['is_consistent'] ?? false,
      storedQuantity: json['stored_quantity'] ?? 0,
      recalculatedQuantity: json['recalculated_quantity'] ?? 0,
      storedReserved: json['stored_reserved'] ?? 0,
      recalculatedReserved: json['recalculated_reserved'] ?? 0,
      discrepancies: List<String>.from(json['discrepancies'] ?? []),
    );
  }
}
