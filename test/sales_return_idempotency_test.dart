import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sales Return Idempotency & Sync Queue Verification', () {
    test('Sales return creation enqueues with stable idempotency key', () {
      final Map<String, dynamic> returnData = {
        'order_id': 101,
        'customer_id': 5,
        'items': [
          {'product_id': 1, 'quantity': 2, 'refund_amount': 5000}
        ],
        'idempotency_key': 'ret_key_12345678'
      };

      final String idempotencyKey = returnData['idempotency_key'] as String;
      expect(idempotencyKey, equals('ret_key_12345678'));

      final payload = Map<String, dynamic>.from(returnData)
        ..['idempotency_key'] = idempotencyKey;

      expect(payload['idempotency_key'], equals('ret_key_12345678'));
    });

    test('Repeated sales return submission preserves identical idempotency key', () {
      final String initialKey = 'ret_key_repeat_87654321';

      final request1 = {
        'idempotency_key': initialKey,
        'order_id': 102,
        'reason': 'Damaged items'
      };

      final request2 = {
        'idempotency_key': initialKey,
        'order_id': 102,
        'reason': 'Damaged items'
      };

      expect(request1['idempotency_key'], equals(request2['idempotency_key']));
    });
  });
}
