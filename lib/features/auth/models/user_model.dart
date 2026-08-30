class UserModel {
  final int id;
  final String name;
  final String phone;
  final String role; // owner, admin, salesman, warehouse, driver
  final int? roleId;
  final double? commissionRate;
  final String? barcode;
  final bool? isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.roleId,
    this.commissionRate,
    this.barcode,
    this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String roleName = 'salesman';
    int? roleIdVal;
    if (json['role'] is Map) {
      roleName = json['role']['name'] ?? 'salesman';
      roleIdVal = json['role']['id'];
    } else if (json['role'] is String) {
      roleName = json['role'];
    }

    double? commRate;
    if (json['commission_rate'] != null) {
      commRate = double.tryParse(json['commission_rate'].toString());
    }

    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: roleName,
      roleId: json['role_id'] ?? roleIdVal,
      commissionRate: commRate,
      barcode: json['barcode'],
      isActive: json['is_active'] is bool
          ? json['is_active']
          : (json['is_active'] == 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'role_id': roleId,
      'commission_rate': commissionRate,
      'barcode': barcode,
      'is_active': isActive,
    };
  }

  bool hasPermission(String permission) {
    final lowerRole = role.toLowerCase();

    // Admin and Owner have all permissions
    if (lowerRole == 'admin' || lowerRole == 'owner') {
      return true;
    }

    // Role-specific static permissions mapping (aligns 100% with backend seeders)
    final Map<String, List<String>> rolePermissions = {
      'salesman': ['orders.create', 'customers.view'],
      'warehouse': ['stock.view', 'stock.pack'],
      'driver': ['delivery.view', 'delivery.update'],
    };

    final permissions = rolePermissions[lowerRole] ?? [];
    return permissions.contains(permission);
  }
}
