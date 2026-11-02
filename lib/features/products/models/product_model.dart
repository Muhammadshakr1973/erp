import '../../../core/utils/formatters.dart';

class ProductModel {
  final int id;
  final String name;
  final String? sku;
  final String barcode;
  final int? categoryId;
  final int? supplierId;
  final dynamic category;
  final dynamic supplier;
  final String? unit;
  final double costPrice;
  final double priceN1;
  final double priceN2;
  final double priceN3;
  final int unitsPerCarton;
  final String? imagePath;
  final bool isActive;
  final List<dynamic> stocks;

  ProductModel({
    required this.id,
    required this.name,
    this.sku,
    required this.barcode,
    this.categoryId,
    this.supplierId,
    this.category,
    this.supplier,
    this.unit,
    required this.costPrice,
    required this.priceN1,
    required this.priceN2,
    required this.priceN3,
    required this.unitsPerCarton,
    this.imagePath,
    this.isActive = true,
    this.stocks = const [],
  });

  ProductModel copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    int? categoryId,
    int? supplierId,
    dynamic category,
    dynamic supplier,
    String? unit,
    double? costPrice,
    double? priceN1,
    double? priceN2,
    double? priceN3,
    int? unitsPerCarton,
    String? imagePath,
    bool? isActive,
    List<dynamic>? stocks,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      priceN1: priceN1 ?? this.priceN1,
      priceN2: priceN2 ?? this.priceN2,
      priceN3: priceN3 ?? this.priceN3,
      unitsPerCarton: unitsPerCarton ?? this.unitsPerCarton,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      stocks: stocks ?? this.stocks,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: Formatters.parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString() ?? '',
      categoryId: json['category_id'] != null ? Formatters.parseInt(json['category_id']) : null,
      supplierId: json['supplier_id'] != null ? Formatters.parseInt(json['supplier_id']) : null,
      category: json['category'],
      supplier: json['supplier'],
      unit: json['unit']?.toString(),
      costPrice: Formatters.parseDouble(json['cost_price']),
      priceN1: Formatters.parseDouble(json['price_n1']),
      priceN2: Formatters.parseDouble(json['price_n2']),
      priceN3: Formatters.parseDouble(json['price_n3']),
      unitsPerCarton: Formatters.parseInt(json['units_per_carton'], 12),
      imagePath: json['image_path']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      stocks: json['stocks'] ?? [],
    );
  }

  int get minStockLevel {
    if (stocks.isEmpty) return 0;
    int minLevel = 0;
    for (var s in stocks) {
      if (s is Map) {
        minLevel += Formatters.parseInt(s['min_stock_level']);
      }
    }
    return minLevel;
  }

  int get totalStock {
    int total = 0;
    for (var s in stocks) {
      if (s is Map) {
        total += Formatters.parseInt(s['quantity']);
      }
    }
    return total;
  }

  int getStockForWarehouse(int? warehouseId) {
    if (warehouseId == null || stocks.isEmpty) return 0;
    for (var s in stocks) {
      if (s is Map && Formatters.parseInt(s['warehouse_id']) == warehouseId) {
        return Formatters.parseInt(s['quantity']);
      }
    }
    return 0;
  }

  bool get isLowStock {
    final min = minStockLevel;
    if (min > 0) {
      return totalStock <= min;
    }
    return totalStock <= 0;
  }
}
