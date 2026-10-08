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
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sku: json['sku'],
      barcode: json['barcode'] ?? '',
      categoryId: json['category_id'],
      supplierId: json['supplier_id'],
      category: json['category'],
      supplier: json['supplier'],
      unit: json['unit'],
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      priceN1: double.tryParse(json['price_n1']?.toString() ?? '0') ?? 0.0,
      priceN2: double.tryParse(json['price_n2']?.toString() ?? '0') ?? 0.0,
      priceN3: double.tryParse(json['price_n3']?.toString() ?? '0') ?? 0.0,
      unitsPerCarton: json['units_per_carton'] ?? 12,
      imagePath: json['image_path'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      stocks: json['stocks'] ?? [],
    );
  }

  int get minStockLevel {
    if (stocks.isEmpty) return 0;
    int minLevel = 0;
    for (var s in stocks) {
      if (s is Map) {
        minLevel += (s['min_stock_level'] as num?)?.toInt() ?? 0;
      }
    }
    return minLevel;
  }

  int get totalStock {
    int total = 0;
    for (var s in stocks) {
      if (s is Map) {
        total += (s['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  bool get isLowStock {
    final min = minStockLevel;
    if (min > 0) {
      return totalStock <= min;
    }
    return totalStock <= 0;
  }
}
