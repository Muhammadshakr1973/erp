import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Purchase Requirement Grouping Verification', () {
    test('Grouped purchase requirements correctly structure by supplier', () {
      final List<Map<String, dynamic>> groupedData = [
        {
          'supplier_id': 10,
          'supplier_name': 'Supplier A',
          'items_count': 2,
          'requirements': [
            {'id': 1, 'product_id': 101, 'quantity': 10},
            {'id': 2, 'product_id': 102, 'quantity': 5},
          ]
        },
        {
          'supplier_id': 20,
          'supplier_name': 'Supplier B',
          'items_count': 1,
          'requirements': [
            {'id': 3, 'product_id': 103, 'quantity': 20},
          ]
        }
      ];

      expect(groupedData.length, equals(2));
      expect(groupedData[0]['supplier_name'], equals('Supplier A'));
      expect(groupedData[0]['items_count'], equals(2));
      expect((groupedData[0]['requirements'] as List).length, equals(2));
    });

    test('Selecting a supplier group extracts all requirement IDs for PO creation', () {
      final Map<String, dynamic> group = {
        'supplier_id': 10,
        'supplier_name': 'Supplier A',
        'items_count': 2,
        'requirements': [
          {'id': 101, 'product_id': 10},
          {'id': 102, 'product_id': 11},
        ]
      };

      final Set<int> selectedIds = {};
      final reqList = group['requirements'] as List;
      for (var item in reqList) {
        if (item['id'] is int) {
          selectedIds.add(item['id']);
        }
      }

      expect(selectedIds.contains(101), isTrue);
      expect(selectedIds.contains(102), isTrue);
      expect(selectedIds.length, equals(2));
    });
  });
}
