class CategoryModel {
  final int id;
  final String name;
  final int productsCount;

  CategoryModel({
    required this.id,
    required this.name,
    this.productsCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawCount = json['products_count'];
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      productsCount: rawCount is int
          ? rawCount
          : int.tryParse(rawCount?.toString() ?? '') ?? 0,
    );
  }
}
