class RouteModel {
  final int id;
  final String name;
  final String code;
  final String? description;
  final String? color;
  final bool isActive;

  RouteModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.color,
    this.isActive = true,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
      color: json['color'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}
