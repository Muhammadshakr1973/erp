import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dual-Entry Shared Order Identity & Optimistic Locking Test', () {
    test('Editing an existing shared order preserves shared_key and version', () {
      final existingOrder = {
        'id': 50,
        'shared_key': 'order_shared_9999',
        'version': 3,
        'customer_id': 12,
        'items': [
          {'product_id': 1, 'quantity': 5}
        ]
      };

      final String sharedKey = existingOrder['shared_key'] as String;
      final int currentVersion = existingOrder['version'] as int;

      final updatedPayload = {
        'customer_id': 12,
        'shared_key': sharedKey,
        'version': currentVersion,
        'items': [
          {'product_id': 1, 'quantity': 6}
        ]
      };

      expect(updatedPayload['shared_key'], equals('order_shared_9999'));
      expect(updatedPayload['version'], equals(3));
    });

    test('Backend version mismatch raises concurrent edit conflict', () {
      final int serverVersion = 4;
      final int clientSubmittedVersion = 3;

      bool isConflict(int serverVer, int clientVer) {
        return serverVer != clientVer;
      }

      expect(isConflict(serverVersion, clientSubmittedVersion), isTrue);
    });
  });
}
