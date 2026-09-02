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
}
