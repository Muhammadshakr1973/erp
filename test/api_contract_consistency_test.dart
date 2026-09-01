import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/shared/models/report_models.dart';
import 'package:pos_app/features/orders/models/order_model.dart';
import 'package:pos_app/features/shared/models/customer.dart';
import 'package:pos_app/features/driver/models/delivery_trip_model.dart';
import 'package:pos_app/features/products/models/supplier_model.dart';
import 'package:pos_app/features/products/models/supplier_ledger_model.dart';
import 'package:pos_app/features/shared/models/customer_ledger_model.dart';

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
        'status': 'in_progress',
        'total_orders': 2,
        'total_amount_collected': 45000,
        'orders': [
          {
            'id': 1,
            'delivery_trip_id': 1,
            'sales_order_id': 10,
            'status': 'delivered',
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
  });
}
