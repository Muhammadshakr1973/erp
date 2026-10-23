import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/orders/models/order_model.dart';
import 'package:pos_app/features/shared/models/payment_history_model.dart';
import 'package:pos_app/features/shared/models/receipt_data.dart';

void main() {
  group('ReceiptData', () {
    test('keeps order totals, RTL text, and real contact values', () {
      final order = _order(items: [_item(1, 'کاڵای تایبەت')]);

      final receipt = ReceiptData.fromOrder(order);

      expect(receipt.receiptNumber, 'S-101');
      expect(receipt.partyName, 'کڕیار');
      expect(receipt.partyPhone, '07501234567');
      expect(receipt.salesmanName, 'مەندوب');
      expect(receipt.salesmanPhone, '07507654321');
      expect(receipt.items.single.name, 'کاڵای تایبەت');
      expect(
        receipt.amounts.map((amount) => amount.label),
        ['کۆی کاڵاکان', 'داشکان', 'کۆی گشتی'],
      );
      expect(receipt.amounts.map((amount) => amount.amount), [300, 20, 280]);
    });

    test('shows only the total when an order has no discount', () {
      final receipt = ReceiptData.fromOrder(
        _order(
          items: [_item(1, 'کاڵای تایبەت')],
          permanentDiscountAmount: 0,
          discountAmount: 0,
          totalAmount: 300,
        ),
      );

      expect(receipt.amounts, hasLength(1));
      expect(receipt.amounts.single.label, 'کۆی گشتی');
      expect(receipt.amounts.single.amount, 300);
    });

    test('derives discount from order totals when discount fields are absent', () {
      final receipt = ReceiptData.fromOrder(
        _order(
          items: [_item(1, 'کاڵای تایبەت')],
          permanentDiscountAmount: 0,
          discountAmount: 0,
          totalAmount: 280,
        ),
      );

      expect(receipt.amounts.map((amount) => amount.label), [
        'کۆی کاڵاکان',
        'داشکان',
        'کۆی گشتی',
      ]);
      expect(receipt.amounts.map((amount) => amount.amount), [300, 20, 280]);
    });

    test('preserves long product names and a large item list', () {
      final longName = List.filled(80, 'کاڵا').join(' ');
      final receipt = ReceiptData.fromOrder(
        _order(items: List.generate(120, (index) => _item(index, longName))),
      );

      expect(receipt.items, hasLength(120));
      expect(receipt.items.first.name, longName);
      expect(receipt.items.last.name, longName);
    });

    test('accepts empty return data without fabricating totals', () {
      final receipt = ReceiptData.fromSalesReturn(
        {'return_number': 'R-12', 'items': <dynamic>[]},
        fallbackNumber: '12',
      );

      expect(receipt.receiptNumber, 'R-12');
      expect(receipt.items, isEmpty);
      expect(receipt.amounts, isEmpty);
    });

    test('uses the source payment amount as paid amount', () {
      final receipt = ReceiptData.fromPayment(
        PaymentHistoryModel(
          id: 8,
          type: 'customer',
          partyName: 'کڕیار',
          partyId: 3,
          amount: 25000,
          paymentMethod: 'CASH',
          paidAt: '2026-10-22',
          reference: 'PAY-8',
        ),
      );

      expect(receipt.amounts.single.label, 'بڕی پارە');
      expect(receipt.amounts.single.amount, 25000);
    });
  });
}

OrderModel _order({
  List<OrderItemModel> items = const [],
  double permanentDiscountAmount = 10,
  double discountAmount = 10,
  double totalAmount = 280,
}) {
  return OrderModel(
    id: 101,
    orderNumber: 'S-101',
    customerId: 3,
    salesmanId: 4,
    subtotal: 300,
    permanentDiscountAmount: permanentDiscountAmount,
    discountAmount: discountAmount,
    discountPercent: 0,
    totalAmount: totalAmount,
    totalProfit: 0,
    status: OrderModel.statusDelivered,
    createdAt: '2026-10-22T08:30:00Z',
    customer: {'name': 'کڕیار', 'phone': '07501234567'},
    salesman: {'name': 'مەندوب', 'phone': '07507654321'},
    items: items,
  );
}

OrderItemModel _item(int id, String name) {
  return OrderItemModel(
    id: id,
    orderId: 101,
    productId: id,
    productName: name,
    quantity: 1,
    unitPrice: 3,
    subtotal: 3,
    isPacked: false,
    productUnit: 'دانە',
  );
}
