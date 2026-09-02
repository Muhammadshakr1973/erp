import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/shared/models/report_models.dart';
import 'package:pos_app/features/orders/models/order_model.dart';
import 'package:pos_app/features/shared/models/customer.dart';
import 'package:pos_app/features/driver/models/delivery_trip_model.dart';
import 'package:pos_app/features/products/models/supplier_model.dart';
import 'package:pos_app/features/products/models/supplier_ledger_model.dart';
import 'package:pos_app/features/shared/models/customer_ledger_model.dart';
import 'package:pos_app/features/shared/models/commission_model.dart';
import 'package:pos_app/features/admin/models/purchase_requirement_model.dart';

void main() {
  group('API Contract Consistency & Response Parsing Tests', () {
    test('Audit Log Paginated JSON Contract Unwrapping', () {
      final paginatedApiResponse = {
        'message': 'لیستی تۆمارەکانی چاودێری',
        'data': {
          'current_page': 1,
          'data': [
            {
              'id': 1,
              'action': 'ORDER_CREATED',
              'entity_type': 'SalesOrder',
              'entity_id': 101,
              'created_at': '2026-03-01T12:00:00.000000Z',
              'user': {'id': 1, 'name': 'Admin'},
            }
          ],
          'total': 1,
        }
      };

      final raw = paginatedApiResponse['data'];
      List<dynamic> logs = [];
      if (raw is List) {
        logs = raw;
      } else if (raw is Map && raw['data'] is List) {
        logs = raw['data'] as List;
      }

      expect(logs.length, equals(1));
      expect(logs.first['action'], equals('ORDER_CREATED'));
    });

    test('Sales Report JSON Contract Verification', () {
      final json = {
        'summary': {
          'total_orders_count': 10,
          'total_delivered_count': 8,
          'total_gross_amount': 100000,
          'total_discount_amount': 5000,
          'total_net_sales': 95000,
          'total_cost_amount': 70000,
          'total_profit_amount': 25000,
          'average_order_value': 9500,
        },
        'breakdown': {
          'by_salesman': [
            {
              'salesman_id': 1,
              'salesman_name': 'Ahmad',
              'orders_count': 5,
              'total_sales': 50000,
              'total_profit': 15000,
            }
          ],
          'by_route': [
            {
              'route_id': 2,
              'route_name': 'Route A',
              'orders_count': 5,
              'total_sales': 50000,
            }
          ],
        },
        'orders': {
          'data': [
            {
              'id': 1,
              'order_number': 'ORD-001',
              'order_date': '2026-03-01',
              'status': 'DELIVERED',
              'customer': {'name': 'Customer 1', 'route': {'name': 'Route A'}},
              'salesman': {'name': 'Ahmad'},
              'warehouse': {'name': 'Main Warehouse'},
              'subtotal': 10000,
              'discount_amount': 500,
              'total_amount': 9500,
              'total_profit': 2500,
            }
          ]
        }
      };

      final report = SalesReportData.fromJson(json);
      expect(report.summary.totalOrdersCount, equals(10));
      expect(report.summary.totalNetSales, equals(95000));
      expect(report.bySalesman.length, equals(1));
      expect(report.bySalesman.first.salesmanName, equals('Ahmad'));
      expect(report.byRoute.length, equals(1));
      expect(report.orders.length, equals(1));
      expect(report.orders.first.customerName, equals('Customer 1'));
    });

    test('Profit Report JSON Contract Verification', () {
      final json = {
        'summary': {
          'total_revenue': 100000,
          'total_cost': 75000,
          'total_profit': 25000,
          'total_units_sold': 500,
          'profit_margin_percent': 25.0,
        },
        'breakdown': {
          'by_product': [
            {
              'product_id': 1,
              'product_name': 'Product A',
              'sku': 'SKU-001',
              'category_name': 'Drinks',
              'units_sold': 200,
              'total_revenue': 40000,
              'total_cost': 30000,
              'total_profit': 10000,
              'margin_percent': 25.0,
            }
          ]
        }
      };

      final profitData = ProfitReportData.fromJson(json);
      expect(profitData.summary.totalRevenue, equals(100000));
      expect(profitData.summary.profitMarginPercent, equals(25.0));
      expect(profitData.topProducts.length, equals(1));
      expect(profitData.topProducts.first.productName, equals('Product A'));
    });

    test('Order Model JSON Contract Verification', () {
      final json = {
        'id': 10,
        'order_number': 'ORD-2026-001',
        'shared_key': 'key-123',
        'version': 2,
        'customer_id': 5,
        'salesman_id': 3,
        'warehouse_id': 1,
        'subtotal': 50000,
        'discount_amount': 2500,
        'discount_percent': 5.0,
        'discount_type': 'PERCENT',
        'total_amount': 47500,
        'total_profit': 12000,
        'status': 'CONFIRMED',
        'items': [
          {
            'id': 1,
            'sales_order_id': 10,
            'product_id': 101,
            'product': {'name': 'Item 1'},
            'quantity': 10,
            'unit_price': 5000,
            'subtotal': 50000,
            'is_packed': true,
          }
        ],
      };

      final order = OrderModel.fromJson(json);
      expect(order.id, equals(10));
      expect(order.orderNumber, equals('ORD-2026-001'));
      expect(order.status, equals('CONFIRMED'));
      expect(order.items.length, equals(1));
      expect(order.items.first.productName, equals('Item 1'));
      expect(order.items.first.isPacked, isTrue);
    });

    test('Delivery Trip Model JSON Contract Verification', () {
      final json = {
        'id': 1,
        'trip_number': 'TRIP-001',
        'driver_id': 4,
        'trip_date': '2026-03-01',
        'status': 'IN_PROGRESS',
        'total_orders': 2,
        'total_amount_collected': 45000,
        'orders': [
          {
            'id': 1,
            'delivery_trip_id': 1,
            'sales_order_id': 10,
            'status': 'DELIVERED',
            'delivery_order': 1,
            'received_amount': 45000,
          }
        ]
      };

      final trip = DeliveryTripModel.fromJson(json);
      expect(trip.id, equals(1));
      expect(trip.tripNumber, equals('TRIP-001'));
      expect(trip.orders.length, equals(1));
      expect(trip.orders.first.receivedAmount, equals(45000));
    });

    test('Supplier Model JSON Contract Verification', () {
      final json = {
        'id': 1,
        'name': 'Darya Co',
        'phone': '07501234567',
        'address': 'Sulaymaniyah',
        'contact_person': 'Soran',
        'current_balance': 1500000,
        'debt': 1500000,
      };

      final supplier = SupplierModel.fromJson(json);
      expect(supplier.id, equals(1));
      expect(supplier.name, equals('Darya Co'));
      expect(supplier.debt, equals(1500000));
    });

    test('Supplier Ledger Model JSON Contract Verification', () {
      final json = {
        'id': 12,
        'supplier_id': 1,
        'entry_type': 'PAYMENT',
        'type': 'debit',
        'debit': 500000,
        'credit': 0,
        'amount': 500000,
        'balance_before': 1500000,
        'balance_after': 1000000,
        'description': 'Paid invoice #5',
        'created_at': '2026-03-01T15:00:00.000000Z',
      };

      final ledger = SupplierLedgerModel.fromJson(json);
      expect(ledger.id, equals(12));
      expect(ledger.debit, equals(500000));
      expect(ledger.balanceAfter, equals(1000000));
    });

    test('Commission Model JSON Contract Verification', () {
      final json = {
        'id': 5,
        'salesman_id': 3,
        'salesman_name': 'Hakar',
        'period_from': '2026-02-01',
        'period_to': '2026-02-28',
        'total_sales': 12000000,
        'total_profit': 3000000,
        'commission_rate': '0.05',
        'commission_amount': 150000,
        'status': 'APPROVED',
        'details': [
          {
            'id': 20,
            'sales_order_id': 101,
            'sales_amount': 2000000,
            'profit_amount': 500000,
            'commission_amount': 25000,
            'order': {
              'order_number': 'ORD-101',
              'customer': {
                'name': 'Rewan Shop'
              }
            }
          }
        ]
      };

      final commission = CommissionModel.fromJson(json);
      expect(commission.id, equals(5));
      expect(commission.status, equals('approved'));
      expect(commission.commissionAmount, equals(150000));
      expect(commission.details.length, equals(1));
      expect(commission.details.first.customerName, equals('Rewan Shop'));
      expect(commission.details.first.orderNumber, equals('ORD-101'));
    });

    test('Purchase Requirement Model JSON Contract Verification', () {
      final json = {
        'id': 8,
        'product_id': 50,
        'product': {'name': 'Soft Drink'},
        'warehouse_id': 2,
        'warehouse': {'name': 'Koya Wh'},
        'supplier_id': 1,
        'supplier': {'name': 'Darya Co'},
        'required_quantity': 100,
        'current_stock': 10,
        'is_urgent': 1,
        'status': 'OPEN',
      };

      final req = PurchaseRequirementModel.fromJson(json);
      expect(req.id, equals(8));
      expect(req.productName, equals('Soft Drink'));
      expect(req.warehouseName, equals('Koya Wh'));
      expect(req.supplierName, equals('Darya Co'));
      expect(req.requiredQuantity, equals(100));
      expect(req.isUrgent, isTrue);
    });
  });
}
