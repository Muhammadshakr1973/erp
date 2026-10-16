class StockTransferItemModel {
  final int id;
  final int productId;
  final String productName;
  final String? productBarcode;
  final String? productUnit;
  final int quantity;
  final int quantityReceived;
  final String? notes;

  StockTransferItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productBarcode,
    this.productUnit,
    required this.quantity,
    this.quantityReceived = 0,
    this.notes,
  });

  factory StockTransferItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return StockTransferItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: product?['name']?.toString() ?? 'کاڵا #${json['product_id']}',
      productBarcode: product?['barcode']?.toString(),
      productUnit: product?['unit']?.toString() ?? 'دانە',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      quantityReceived: (json['quantity_received'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString(),
    );
  }
}

class StockTransferModel {
  final int id;
  final String transferNumber;
  final int fromWarehouseId;
  final int toWarehouseId;
  final String fromWarehouseName;
  final String toWarehouseName;
  final String status;
  final String? notes;
  final String? creatorName;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<StockTransferItemModel> items;

  StockTransferModel({
    required this.id,
    required this.transferNumber,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.fromWarehouseName,
    required this.toWarehouseName,
    required this.status,
    this.notes,
    this.creatorName,
    this.createdAt,
    this.completedAt,
    this.items = const [],
  });

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  int get totalItemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  factory StockTransferModel.fromJson(Map<String, dynamic> json) {
    final fromW = json['from_warehouse'] as Map<String, dynamic>?;
    final toW = json['to_warehouse'] as Map<String, dynamic>?;
    final creator = json['creator'] as Map<String, dynamic>?;
    final rawItems = json['items'] as List? ?? [];

    return StockTransferModel(
      id: json['id'] ?? 0,
      transferNumber: json['transfer_number']?.toString() ?? 'TRF-${json['id']}',
      fromWarehouseId: json['from_warehouse_id'] ?? 0,
      toWarehouseId: json['to_warehouse_id'] ?? 0,
      fromWarehouseName: fromW?['name']?.toString() ?? 'کۆگا #${json['from_warehouse_id']}',
      toWarehouseName: toW?['name']?.toString() ?? 'کۆگا #${json['to_warehouse_id']}',
      status: json['status']?.toString().toUpperCase() ?? 'DRAFT',
      notes: json['notes']?.toString(),
      creatorName: creator?['name']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      items: rawItems
          .map((i) => StockTransferItemModel.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}
