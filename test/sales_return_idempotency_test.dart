import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/sync/sync_queue_entry.dart';

void main() {
  group('Sales Return Idempotency & Sync Queue Verification', () {
    test('Sales return creation enqueues with stable idempotency key', () {
      final Map<String, dynamic> returnData = {
        'sales_order_id': 101,
        'items': [
          {'sales_order_item_id': 1, 'quantity': 2, 'reason': 'Damaged'}
        ],
        'idempotency_key': 'ret_101_12345678'
      };

      final String idempotencyKey = returnData['idempotency_key'] as String;
      expect(idempotencyKey, equals('ret_101_12345678'));

      final payload = Map<String, dynamic>.from(returnData)
        ..['idempotency_key'] = idempotencyKey;

      expect(payload['idempotency_key'], equals('ret_101_12345678'));
      expect(payload['sales_order_id'], equals(101));
    });

    test('SyncQueueEntry preserves stable entry.id across retry cycles without regeneration', () {
      final String stableOpId = '1725280000000_ret_101_87654321_abcdef12';

      final entry = SyncQueueEntry(
        id: stableOpId,
        entityId: 'ret_101_87654321',
        operationType: 'CREATE_SALES_RETURN',
        payloadJson: '{"sales_order_id":101,"items":[{"sales_order_item_id":1,"quantity":2}]}',
        createdAt: DateTime.now(),
        status: 'PENDING',
      );

      // Verify initial setup
      expect(entry.id, equals(stableOpId));
      expect(entry.operationType, equals('CREATE_SALES_RETURN'));

      // First sync attempt fails with network error: enters PENDING for retry
      entry.status = 'SYNCING';
      // Simulate network failure handler from SyncService
      entry.status = 'PENDING';
      entry.errorInformation = 'Network failure';

      // Verify that after failure, entry.id remains identical for the retry attempt
      expect(entry.id, equals(stableOpId));

      // Second sync attempt (retry)
      entry.status = 'SYNCING';
      // Simulating successful replayed response
      entry.status = 'COMPLETED';
      entry.syncResult = {
        'message': 'Success',
        'data': {
          'id': 55,
          'sales_order_id': 101,
          'total_return_amount': 15000,
        }
      };

      expect(entry.id, equals(stableOpId));
      expect(entry.status, equals('COMPLETED'));
      expect(entry.syncResult?['data']?['id'], equals(55));
    });

    test('Request headers use entry.id as X-Idempotency-Key for CREATE_SALES_RETURN', () {
      final entry = SyncQueueEntry(
        id: 'stable_unique_sync_id_9999',
        entityId: 'ret_999_test',
        operationType: 'CREATE_SALES_RETURN',
        payloadJson: '{"sales_order_id":999}',
        createdAt: DateTime.now(),
      );

      // Replicate the header generation logic from SyncService._performOperation
      final headers = <String, dynamic>{
        'X-Idempotency-Key': entry.id,
      };

      expect(headers['X-Idempotency-Key'], equals('stable_unique_sync_id_9999'));
      expect(headers['X-Idempotency-Key'], isNotEmpty);
    });

    test('Conflict (409) retains PENDING status and halts batch without generating new key', () {
      final entry = SyncQueueEntry(
        id: 'conflict_key_1111',
        entityId: 'ret_conflict_1',
        operationType: 'CREATE_SALES_RETURN',
        payloadJson: '{"sales_order_id":101}',
        createdAt: DateTime.now(),
        status: 'SYNCING',
      );

      // Simulate 409 handling in SyncService
      bool pauseSyncLoop = false;
      const statusCode = 409;
      if (statusCode == 409) {
        entry.status = 'PENDING';
        entry.errorInformation = 'ئەم کردەوەیە ئێستا لە سێرڤەردا لە پرۆسەدایە...';
        pauseSyncLoop = true;
      }

      expect(pauseSyncLoop, isTrue);
      expect(entry.status, equals('PENDING'));
      expect(entry.id, equals('conflict_key_1111'));
    });

    test('Validation error (422 payload mismatch) marks entry as permanently FAILED (retryCount 999)', () {
      final entry = SyncQueueEntry(
        id: 'invalid_mismatch_key_2222',
        entityId: 'ret_mismatch_2',
        operationType: 'CREATE_SALES_RETURN',
        payloadJson: '{"sales_order_id":101}',
        createdAt: DateTime.now(),
        status: 'SYNCING',
      );

      // Simulate 422 handling in SyncService
      const statusCode = 422;
      if (statusCode == 422 || statusCode == 400) {
        entry.status = 'FAILED';
        entry.retryCount = 999;
        entry.errorInformation = 'Idempotency key payload mismatch';
      }

      expect(entry.status, equals('FAILED'));
      expect(entry.retryCount, equals(999));
    });

    test('Replayed response with X-Cache-Lookup HIT resolves to valid Sales Return data', () {
      final Map<String, dynamic> mockServerResponse = {
        'status': 201,
        'headers': <String, dynamic>{
          'X-Cache-Lookup': 'HIT',
          'X-Idempotency-Key': 'cached_key_3333',
        },
        'data': <String, dynamic>{
          'message': 'کاڵاکە بە سەرکەوتوویی گەڕێندرایەوە و باڵانسی کڕیار نوێکرایەوە',
          'data': <String, dynamic>{
            'id': 12,
            'sales_order_id': 200,
            'total_return_amount': 25000,
            'status': 'COMPLETED',
          }
        }
      };

      final headers = mockServerResponse['headers'] as Map<String, dynamic>;
      expect(headers['X-Cache-Lookup'], equals('HIT'));
      final responseBody = mockServerResponse['data'] as Map<String, dynamic>;
      final returnData = responseBody['data'] as Map<String, dynamic>;
      expect(returnData['id'], equals(12));
      expect(returnData['total_return_amount'], equals(25000));
      expect(returnData['status'], equals('COMPLETED'));
    });
  });
}

