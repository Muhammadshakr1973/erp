import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/orders/models/order_model.dart';
import 'package:pos_app/features/orders/providers/orders_provider.dart';

void main() {
  group('Admin Order Filter Tests', () {
    final testOrders = [
      OrderModel(
        id: 1,
        orderNumber: 'ORD-001',
        customerId: 10,
        salesmanId: 100,
        subtotal: 50000,
        discountAmount: 0,
        discountPercent: 0,
        totalAmount: 50000,
        totalProfit: 5000,
        status: 'CONFIRMED',
        createdAt: '2026-09-01T10:00:00.000Z',
        customer: {'id': 10, 'name': 'مارکێتی دیلان'},
        salesman: {'id': 100, 'name': 'ئەحمەد فەرهاد'},
      ),
      OrderModel(
        id: 2,
        orderNumber: 'ORD-002',
        customerId: 20,
        salesmanId: 100,
        subtotal: 25000,
        discountAmount: 0,
        discountPercent: 0,
        totalAmount: 25000,
        totalProfit: 2500,
        status: 'IN_DELIVERY',
        createdAt: '2026-09-02T11:30:00.000Z',
        customer: {'id': 20, 'name': 'مارکێتی کوردستان'},
        salesman: {'id': 100, 'name': 'ئەحمەد فەرهاد'},
      ),
      OrderModel(
        id: 3,
        orderNumber: 'ORD-003',
        customerId: 10,
        salesmanId: 200,
        subtotal: 75000,
        discountAmount: 0,
        discountPercent: 0,
        totalAmount: 75000,
        totalProfit: 7500,
        status: 'DELIVERED',
        createdAt: '2026-09-03T14:00:00.000Z',
        customer: {'id': 10, 'name': 'مارکێتی دیلان'},
        salesman: {'id': 200, 'name': 'سەردار عەلی'},
      ),
      OrderModel(
        id: 4,
        orderNumber: 'ORD-004',
        customerId: 30,
        salesmanId: 200,
        subtotal: 10000,
        discountAmount: 0,
        discountPercent: 0,
        totalAmount: 10000,
        totalProfit: 1000,
        status: 'DELIVERED',
        createdAt: '2026-09-04T09:15:00.000Z',
        customer: {'id': 30, 'name': 'فرۆشگای ئازادی'},
        salesman: {'id': 200, 'name': 'سەردار عەلی'},
      ),
    ];

    test('Filter by status tab correctly partitions orders', () {
      final allOrders = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'هەمووی',
        filterState: const AdminOrderFilterState(),
      );
      expect(allOrders.length, 4);

      final inDeliveryOrders = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'لە گەیاندن',
        filterState: const AdminOrderFilterState(),
      );
      expect(inDeliveryOrders.length, 2);
      expect(inDeliveryOrders.map((o) => o.id), containsAll([1, 2]));

      final deliveredOrders = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'گەیشتووە',
        filterState: const AdminOrderFilterState(),
      );
      expect(deliveredOrders.length, 2);
      expect(deliveredOrders.map((o) => o.id), containsAll([3, 4]));
    });

    test('Filter by customer ID returns only that customer orders', () {
      final filtered = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'هەمووی',
        filterState: const AdminOrderFilterState(customerId: 10),
      );
      expect(filtered.length, 2);
      expect(filtered.every((o) => o.customerId == 10), isTrue);
    });

    test('Filter by salesman ID returns only that salesman orders', () {
      final filtered = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'هەمووی',
        filterState: const AdminOrderFilterState(salesmanId: 200),
      );
      expect(filtered.length, 2);
      expect(filtered.every((o) => o.salesmanId == 200), isTrue);
    });

    test('Filter by date range returns orders within start and end boundaries', () {
      final filtered = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'هەمووی',
        filterState: AdminOrderFilterState(
          startDate: DateTime(2026, 9, 2),
          endDate: DateTime(2026, 9, 3),
        ),
      );
      expect(filtered.length, 2);
      expect(filtered.map((o) => o.id), containsAll([2, 3]));
    });

    test('Filter by search query matches order number, customer name, and salesman name', () {
      // By order number
      final searchByNum = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'هەمووی',
        filterState: const AdminOrderFilterState(searchQuery: 'ORD-003'),
      );
      expect(searchByNum.length, 1);
      expect(searchByNum.first.id, 3);

      // By customer name
      final searchByCustomer = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'هەمووی',
        filterState: const AdminOrderFilterState(searchQuery: 'دیلان'),
      );
      expect(searchByCustomer.length, 2);
      expect(searchByCustomer.map((o) => o.id), containsAll([1, 3]));

      // By salesman name
      final searchBySalesman = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'هەمووی',
        filterState: const AdminOrderFilterState(searchQuery: 'سەردار'),
      );
      expect(searchBySalesman.length, 2);
      expect(searchBySalesman.map((o) => o.id), containsAll([3, 4]));
    });

    test('Combined multi-criteria filtering works conjunctively', () {
      final filtered = applyAdminOrderFilters(
        orders: testOrders,
        tabFilter: 'گەیشتووە',
        filterState: const AdminOrderFilterState(
          customerId: 10,
          salesmanId: 200,
        ),
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, 3);
    });
  });
}
