class UserModel {
  final int id;
  final String name;
  final String phone;
  final String role; // owner, admin, salesman, warehouse, driver
  final int? roleId;
  final double? commissionRate;
  final String? barcode;
  final bool? isActive;
  final int? warehouseId;
  final List<String>? permissions;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.roleId,
    this.commissionRate,
    this.barcode,
    this.isActive,
    this.warehouseId,
    this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String roleName = 'salesman';
    int? roleIdVal;
    List<String>? parsedPermissions;

    if (json['role'] is Map) {
      roleName = json['role']['name'] ?? 'salesman';
      roleIdVal = json['role']['id'];
      if (json['role']['permissions'] is List) {
        parsedPermissions = (json['role']['permissions'] as List)
            .map((e) => e.toString())
            .toList();
      }
    } else if (json['role'] is String) {
      roleName = json['role'];
    }

    if (parsedPermissions == null && json['permissions'] is List) {
      parsedPermissions = (json['permissions'] as List)
          .map((e) => e.toString())
          .toList();
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
      warehouseId: json['warehouse_id'],
      permissions: parsedPermissions,
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
      'warehouse_id': warehouseId,
      'permissions': permissions,
    };
  }

  bool get isAdmin {
    final lowerRole = role.toLowerCase();
    return lowerRole == 'admin' || lowerRole == 'owner';
  }

  bool hasPermission(String permission) {
    final lowerRole = role.toLowerCase();

    // Admin and Owner have all permissions
    if (lowerRole == 'admin' || lowerRole == 'owner') {
      return true;
    }

    // If server sent dynamic permissions, check them
    if (permissions != null && permissions!.isNotEmpty) {
      return permissions!.contains(permission) || permissions!.contains('*');
    }

    // Role-specific static permissions mapping (aligns 100% with backend RoleSeeder)
    final Map<String, List<String>> rolePermissions = {
      'salesman': [
        'orders.create',
        'orders.view',
        'customers.view',
        'customers.create',
        'products.view',
        'commissions.view',
        'suppliers.view',
      ],
      'warehouse': [
        'stock.view',
        'stock.pack',
        'stock.reconcile',
        'stock.transfer',
        'stock.adjust',
        'purchases.receive',
      ],
      'driver': [
        'delivery.view',
        'delivery.update',
        'delivery.confirm',
      ],
    };

    final rolePerms = rolePermissions[lowerRole] ?? [];
    return rolePerms.contains(permission);
  }
}
