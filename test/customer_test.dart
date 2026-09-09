import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/shared/models/customer.dart';
import 'package:pos_app/features/shared/models/route_model.dart';
import 'package:pos_app/features/shared/providers/customer_provider.dart';

void main() {
  group('Customer Model Tests', () {
    test('Customer.fromJson correctly parses full customer payload with route', () {
      final json = {
        'id': 10,
        'name': 'کۆمپانیای سەردەم',
        'phone': '07501234567',
        'phone2': '07701234567',
        'address': 'هەولێر - شەقامی ٦٠ مەتری',
        'image_url': 'https://example.com/customer.png',
        'current_balance': '150000',
        'credit_limit': '5000000',
        'salesman_id': 2,
        'route_id': 4,
        'price_type': 'N3',
        'permanent_discount': '5.5',
        'is_active': 1,
        'latitude': '36.1901',
        'longitude': '44.0091',
        'visit_order': '3',
        'route': {
          'id': 4,
          'name': 'ڕێگای ١',
          'color': '#FF5733',
          'is_active': true,
        },
      };

      final customer = Customer.fromJson(json);

      expect(customer.id, equals(10));
      expect(customer.name, equals('کۆمپانیای سەردەم'));
      expect(customer.phone, equals('07501234567'));
      expect(customer.phone2, equals('07701234567'));
      expect(customer.address, equals('هەولێر - شەقامی ٦٠ مەتری'));
      expect(customer.imageUrl, equals('https://example.com/customer.png'));
      expect(customer.balance, equals(150000.0));
      expect(customer.creditLimit, equals(5000000.0));
      expect(customer.salesmanId, equals(2));
      expect(customer.routeId, equals(4));
      expect(customer.priceType, equals('N3'));
      expect(customer.permanentDiscount, equals(5.5));
      expect(customer.isActive, isTrue);
      expect(customer.latitude, equals(36.1901));
      expect(customer.longitude, equals(44.0091));
      expect(customer.visitOrder, equals(3));
      expect(customer.route, isNotNull);
      expect(customer.route!.id, equals(4));
      expect(customer.route!.name, equals('ڕێگای ١'));
    });

    test('Customer.fromJson handles fallbacks and null values safely', () {
      final json = {
        'id': 5,
        'name': 'مارکێتی بەختیاری',
      };

      final customer = Customer.fromJson(json);

      expect(customer.id, equals(5));
      expect(customer.name, equals('مارکێتی بەختیاری'));
      expect(customer.phone, isNull);
      expect(customer.balance, equals(0.0));
      expect(customer.creditLimit, equals(0.0));
      expect(customer.priceType, equals('N2'));
      expect(customer.isActive, isTrue);
      expect(customer.route, isNull);
    });

    test('Customer reflects updated information upon editing', () {
      final original = Customer(
        id: 7,
        name: 'کڕیاری کۆن',
        phone: '07500000000',
        routeId: 1,
        priceType: 'N1',
      );

      final updated = Customer(
        id: original.id,
        name: 'کڕیاری نوێ',
        phone: '07509999999',
        address: 'سلێمانی',
        routeId: 2,
        priceType: 'N3',
        isActive: original.isActive,
        balance: original.balance,
      );

      expect(updated.id, equals(original.id));
      expect(updated.name, equals('کڕیاری نوێ'));
      expect(updated.phone, equals('07509999999'));
      expect(updated.address, equals('سلێمانی'));
      expect(updated.routeId, equals(2));
      expect(updated.priceType, equals('N3'));
    });
  });

  group('CustomerFilters Tests', () {
    test('CustomerFilters.toMap correctly serializes query parameters', () {
      const filters = CustomerFilters(
        page: 2,
        routeId: 3,
        onlyDebtors: true,
        searchQuery: 'ئازاد',
      );

      final map = filters.toMap();

      expect(map['page'], equals(2));
      expect(map['route_id'], equals(3));
      expect(map['has_debt'], equals('true'));
      expect(map['search'], equals('ئازاد'));
    });

    test('CustomerFilters equality and hashCode work as expected', () {
      const filtersA = CustomerFilters(page: 1, routeId: 2, onlyDebtors: false, searchQuery: 'test');
      const filtersB = CustomerFilters(page: 1, routeId: 2, onlyDebtors: false, searchQuery: 'test');
      const filtersC = CustomerFilters(page: 2, routeId: 2, onlyDebtors: false, searchQuery: 'test');

      expect(filtersA, equals(filtersB));
      expect(filtersA.hashCode, equals(filtersB.hashCode));
      expect(filtersA, isNot(equals(filtersC)));
    });
  });
}
