class Product {
  final int id;
  final String name;
  final String? barcode;
  final String? unit;
  final double sellingPrice;
  final double purchasePrice;
  final int? categoryId;
  final String? image;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.unit,
    this.sellingPrice = 0.0,
    this.purchasePrice = 0.0,
    this.categoryId,
    this.image,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      barcode: json['barcode'],
      unit: json['unit'],
      sellingPrice: double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0.0,
      purchasePrice: double.tryParse(json['purchase_price']?.toString() ?? '0') ?? 0.0,
      categoryId: json['category_id'],
      image: json['image'],
    );
  }
}
