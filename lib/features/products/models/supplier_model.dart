class SupplierModel {
  final int id;
  final String name;

  SupplierModel({required this.id, required this.name});

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}
