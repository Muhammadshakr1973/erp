import '../../../core/utils/formatters.dart';

class WarehouseStockModel {
  final int id;
  final int warehouseId;
  final String warehouseName;
  final int productId;
  final String productName;
  final String barcode;
  final double quantity;
  final double reservedQuantity;
  final double minStockLevel;

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
  double get availableQuantity => quantity - reservedQuantity;

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
      id: Formatters.parseInt(json['id']),
      warehouseId: Formatters.parseInt(json['warehouse_id']),
      warehouseName: wName,
      productId: Formatters.parseInt(json['product_id']),
      productName: pName,
      barcode: pBarcode,
      quantity: Formatters.parseDouble(json['quantity']),
      reservedQuantity: Formatters.parseDouble(json['reserved_quantity']),
      minStockLevel: Formatters.parseDouble(json['min_stock_level']),
    );
  }
}

class StockReconciliationModel {
  final bool isConsistent;
  final double storedQuantity;
  final double recalculatedQuantity;
  final double storedReserved;
  final double recalculatedReserved;
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
      isConsistent: json['is_consistent'] == true || json['is_consistent'] == 1,
      storedQuantity: Formatters.parseDouble(json['stored_quantity']),
      recalculatedQuantity: Formatters.parseDouble(json['recalculated_quantity']),
      storedReserved: Formatters.parseDouble(json['stored_reserved']),
      recalculatedReserved: Formatters.parseDouble(json['recalculated_reserved']),
      discrepancies: List<String>.from(json['discrepancies'] ?? []),
    );
  }
}
