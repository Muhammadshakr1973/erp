class ProductModel {
  final int id;
  final String name;
  final String barcode;
  final double costPrice;
  final double priceN1;
  final int unitsPerCarton;
  final List<dynamic> stocks;

  ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.costPrice,
    required this.priceN1,
    required this.unitsPerCarton,
    this.stocks = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      barcode: json['barcode'] ?? '',
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      priceN1: double.tryParse(json['price_n1']?.toString() ?? '0') ?? 0.0,
      unitsPerCarton: json['units_per_carton'] ?? 1,
      stocks: json['stocks'] ?? [],
    );
  }
}
