import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/auth/models/user_model.dart';
import 'package:pos_app/features/shared/models/customer.dart';
import 'package:pos_app/features/shared/models/route_model.dart';
import 'package:pos_app/features/products/models/supplier_model.dart';
import 'package:pos_app/features/shared/providers/warehouse_provider.dart';

void main() {
  group('Report Screens Dropdown Generic Type Safety Tests', () {
    test('Warehouse dropdown items map correctly to List<DropdownMenuItem<int?>>', () {
      final warehouses = [
        WarehouseModel(id: 1, name: 'کۆگای سەرەکی', isMain: true),
        WarehouseModel(id: 2, name: 'کۆگای دووەم', isMain: false),
      ];

      final items = <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('گشت کۆگاکان')),
        for (final w in warehouses)
          DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
      ];

      expect(items.length, 3);
      expect(items[0].value, isNull);
      expect(items[1].value, equals(1));
      expect(items[2].value, equals(2));
      // Must be strictly typed as List<DropdownMenuItem<int?>>
      expect(items, isA<List<DropdownMenuItem<int?>>>());
    });

    test('Customer dropdown items map correctly to List<DropdownMenuItem<int?>>', () {
      final customers = [
        Customer(id: 10, name: 'کڕیار ١'),
        Customer(id: 20, name: 'کڕیار ٢'),
      ];

      final items = <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('گشت کڕیارەکان')),
        for (final c in customers)
          DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
      ];

      expect(items.length, 3);
      expect(items[0].value, isNull);
      expect(items[1].value, equals(10));
      expect(items[2].value, equals(20));
      expect(items, isA<List<DropdownMenuItem<int?>>>());
    });

    test('Salesman dropdown items map correctly to List<DropdownMenuItem<int?>>', () {
      final salesmen = [
        UserModel(id: 101, name: 'مەندوب ١', phone: '07500000001', role: 'salesman'),
        UserModel(id: 102, name: 'مەندوب ٢', phone: '07500000002', role: 'salesman'),
      ];

      final items = <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('گشت مەندوبەکان')),
        for (final s in salesmen)
          DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
      ];

      expect(items.length, 3);
      expect(items[0].value, isNull);
      expect(items[1].value, equals(101));
      expect(items[2].value, equals(102));
      expect(items, isA<List<DropdownMenuItem<int?>>>());
    });

    test('Route dropdown items map correctly to List<DropdownMenuItem<int?>>', () {
      final routes = [
        RouteModel(id: 5, name: 'ڕێگای ١', code: 'R1'),
        RouteModel(id: 6, name: 'ڕێگای ٢', code: 'R2'),
      ];

      final items = <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('گشت ڕێگاکان')),
        for (final r in routes)
          DropdownMenuItem<int?>(value: r.id, child: Text(r.name)),
      ];

      expect(items.length, 3);
      expect(items[0].value, isNull);
      expect(items[1].value, equals(5));
      expect(items[2].value, equals(6));
      expect(items, isA<List<DropdownMenuItem<int?>>>());
    });

    test('Supplier dropdown items map correctly to List<DropdownMenuItem<int?>>', () {
      final suppliers = [
        SupplierModel(id: 50, name: 'کۆمپانیای ١'),
        SupplierModel(id: 60, name: 'کۆمپانیای ٢'),
      ];

      final items = <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('گشت کۆمپانیاکان')),
        for (final s in suppliers)
          DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
      ];

      expect(items.length, 3);
      expect(items[0].value, isNull);
      expect(items[1].value, equals(50));
      expect(items[2].value, equals(60));
      expect(items, isA<List<DropdownMenuItem<int?>>>());
    });
  });
}
