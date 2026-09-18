import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/auth/models/user_model.dart';

void main() {
  group('UserModel Role & Permission Tests', () {
    test('Warehouse role has stock.pack and stock.view permissions', () {
      final warehouseUser = UserModel(
        id: 1,
        name: 'Warehouse Keeper',
        phone: '07701234567',
        role: 'warehouse',
      );

      expect(warehouseUser.hasPermission('stock.pack'), isTrue);
      expect(warehouseUser.hasPermission('stock.view'), isTrue);
      expect(warehouseUser.hasPermission('orders.create'), isFalse);
      expect(warehouseUser.hasPermission('users.manage'), isFalse);
    });

    test('Salesman role has orders.create and customers.view permissions', () {
      final salesmanUser = UserModel(
        id: 2,
        name: 'Salesman',
        phone: '07701234568',
        role: 'salesman',
      );

      expect(salesmanUser.hasPermission('orders.create'), isTrue);
      expect(salesmanUser.hasPermission('customers.view'), isTrue);
      expect(salesmanUser.hasPermission('stock.pack'), isFalse);
    });

    test('Admin and Owner have all permissions wildcard', () {
      final adminUser = UserModel(
        id: 3,
        name: 'Admin',
        phone: '07701234569',
        role: 'admin',
      );

      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.hasPermission('stock.pack'), isTrue);
      expect(adminUser.hasPermission('users.manage'), isTrue);
    });
  });
}

