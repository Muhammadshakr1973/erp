import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/products/models/supplier_reconciliation_model.dart';

void main() {
  group('Supplier Reconciliation Model Tests', () {
    test('fromJson should parse valid data correctly', () {
      final json = {
        'is_consistent': false,
        'stored_balance': 1000,
        'recalculated_balance': 1200,
        'discrepancies': ['Discrepancy 1', 'Discrepancy 2'],
      };

      final model = SupplierReconciliationModel.fromJson(json);

      expect(model.isConsistent, false);
      expect(model.storedBalance, 1000);
      expect(model.recalculatedBalance, 1200);
      expect(model.discrepancies.length, 2);
      expect(model.discrepancies[0], 'Discrepancy 1');
    });

    test('fromJson should handle missing fields gracefully', () {
      final json = <String, dynamic>{};

      final model = SupplierReconciliationModel.fromJson(json);

      expect(model.isConsistent, false);
      expect(model.storedBalance, 0);
      expect(model.recalculatedBalance, 0);
      expect(model.discrepancies, isEmpty);
    });
  });

  group('Supplier Reconciliation Logic Tests', () {
    test('discrepancy detection in model', () {
      final model = SupplierReconciliationModel(
        isConsistent: false,
        storedBalance: 500,
        recalculatedBalance: 600,
        discrepancies: ['Balance mismatch'],
      );

      expect(model.isConsistent, isFalse);
      expect(model.discrepancies, contains('Balance mismatch'));
    });
  });
}
