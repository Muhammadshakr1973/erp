class ProductModel {
  final int id;
  final String name;
  final String? sku;
  final String barcode;
  final int? categoryId;
  final dynamic category;
  final String? unit;
  final double costPrice;
  final double priceN1;
  final double priceN2;
  final double priceN3;
  final int unitsPerCarton;
  final bool isActive;
  final List<dynamic> stocks;

  ProductModel({
    required this.id,
    required this.name,
    this.sku,
    required this.barcode,
    this.categoryId,
    this.category,
    this.unit,
    required this.costPrice,
    required this.priceN1,
    required this.priceN2,
    required this.priceN3,
    required this.unitsPerCarton,
    this.isActive = true,
    this.stocks = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sku: json['sku'],
      barcode: json['barcode'] ?? '',
      categoryId: json['category_id'],
      category: json['category'],
      unit: json['unit'],
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      priceN1: double.tryParse(json['price_n1']?.toString() ?? '0') ?? 0.0,
      priceN2: double.tryParse(json['price_n2']?.toString() ?? '0') ?? 0.0,
      priceN3: double.tryParse(json['price_n3']?.toString() ?? '0') ?? 0.0,
      unitsPerCarton: json['units_per_carton'] ?? 1,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      stocks: json['stocks'] ?? [],
    );
  }
}
