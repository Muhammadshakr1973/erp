class UserModel {
  final int id;
  final String name;
  final String phone;
  final String role; // owner, admin, salesman, warehouse, driver

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String roleName = 'salesman';
    if (json['role'] is Map) {
      roleName = json['role']['name'] ?? 'salesman';
    } else if (json['role'] is String) {
      roleName = json['role'];
    }

    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: roleName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
    };
  }
}
