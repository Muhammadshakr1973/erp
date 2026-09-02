import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/auth/models/user_model.dart';
import 'package:pos_app/features/shared/models/customer_reconciliation_model.dart';

void main() {
  group('Customer Reconciliation Model Tests', () {
    test('Should parse consistent reconciliation response correctly', () {
      final json = {
        'is_consistent': true,
        'stored_balance': 50000.0,
        'recalculated_balance': 50000.0,
        'discrepancies': [],
      };

      final model = CustomerReconciliationModel.fromJson(json);

      expect(model.isConsistent, isTrue);
      expect(model.storedBalance, 50000.0);
      expect(model.recalculatedBalance, 50000.0);
      expect(model.discrepancies, isEmpty);
      expect(model.discrepancyAmount, 0.0);
    });

    test('Should parse inconsistent reconciliation response correctly', () {
      final json = {
        'is_consistent': false,
        'stored_balance': 60000.0,
        'recalculated_balance': 50000.0,
        'discrepancies': ['Entry ID 123: mismatch'],
      };

      final model = CustomerReconciliationModel.fromJson(json);

      expect(model.isConsistent, isFalse);
      expect(model.storedBalance, 60000.0);
      expect(model.recalculatedBalance, 50000.0);
      expect(model.discrepancies, hasLength(1));
      expect(model.discrepancyAmount, 10000.0);
    });
  });

  group('Customer Reconciliation Authorization Tests', () {
    test('Admin user should have canFix authority', () {
      final adminUser = UserModel(id: 1, name: 'Admin', phone: '123', role: 'admin');
      
      final canFix = adminUser.isAdmin && adminUser.hasPermission('users.manage');
      
      expect(adminUser.isAdmin, isTrue);
      expect(canFix, isTrue);
    });

    test('Owner user should have canFix authority', () {
      final ownerUser = UserModel(id: 2, name: 'Owner', phone: '456', role: 'owner');
      
      final canFix = ownerUser.isAdmin && ownerUser.hasPermission('users.manage');
      
      expect(ownerUser.isAdmin, isTrue);
      expect(canFix, isTrue);
    });

    test('Non-admin user with users.manage permission should NOT have canFix authority', () {
      // Role is salesman, but manually given users.manage permission
      final salesmanUser = UserModel(
        id: 3, 
        name: 'Salesman', 
        phone: '789', 
        role: 'salesman',
        permissions: ['users.manage'],
      );
      
      final canFix = salesmanUser.isAdmin && salesmanUser.hasPermission('users.manage');
      
      expect(salesmanUser.isAdmin, isFalse);
      expect(salesmanUser.hasPermission('users.manage'), isTrue);
      expect(canFix, isFalse, reason: 'Backend requires isAdmin() even if permission is present');
    });

    test('Standard user without permission should NOT have canFix authority', () {
      final driverUser = UserModel(id: 4, name: 'Driver', phone: '000', role: 'driver');
      
      final canFix = driverUser.isAdmin && driverUser.hasPermission('users.manage');
      
      expect(driverUser.isAdmin, isFalse);
      expect(canFix, isFalse);
    });
  });

  group('Customer Reconciliation UI Visibility Tests', () {
    test('User with users.manage permission should see reconciliation action', () {
      final manager = UserModel(
        id: 10,
        name: 'Manager',
        phone: '111',
        role: 'salesman',
        permissions: ['users.manage'],
      );

      final canViewReconciliation = manager.hasPermission('users.manage');
      expect(canViewReconciliation, isTrue);
    });

    test('User without users.manage permission should NOT see reconciliation action', () {
      final salesman = UserModel(
        id: 11,
        name: 'Salesman',
        phone: '222',
        role: 'salesman',
        permissions: ['orders.create'],
      );

      final canViewReconciliation = salesman.hasPermission('users.manage');
      expect(canViewReconciliation, isFalse);
    });

    test('Admin user should see reconciliation action by default', () {
      final admin = UserModel(
        id: 12,
        name: 'Admin',
        phone: '333',
        role: 'admin',
      );

      final canViewReconciliation = admin.hasPermission('users.manage');
      expect(admin.isAdmin, isTrue);
      expect(canViewReconciliation, isTrue);
    });
  });
}
