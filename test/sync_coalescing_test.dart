import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
// Note: assuming typical import paths for the project
import '../lib/core/sync/sync_service.dart';
import '../lib/core/sync/sync_queue_entry.dart';
import '../lib/core/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockBox extends Mock implements Box<SyncQueueEntry> {}
class MockRef extends Mock implements Ref {}

void main() {
  group('Sync Coalescing Safety', () {
    late SyncService syncService;
    late MockApiClient mockApi;
    late MockBox mockBox;
    late MockRef mockRef;

    setUp(() {
      mockApi = MockApiClient();
      mockBox = MockBox();
      mockRef = MockRef();
      syncService = SyncService(mockApi, mockBox, mockRef);
    });

    test('UPDATE_ORDER coalesces when pending entry exists', () async {
      final existingEntry = SyncQueueEntry(
        id: '1',
        entityId: '123',
        operationType: 'UPDATE_ORDER',
        payloadJson: '{"status": "OLD"}',
        createdAt: DateTime.now(),
      );
      existingEntry.status = 'PENDING';

      when(mockBox.values).thenReturn([existingEntry]);

      await syncService.enqueueOperation(
        entityId: '123',
        operationType: 'UPDATE_ORDER',
        payload: {'status': 'NEW'},
      );

      // Verify it overwrote the payload and did not add a new entry
      expect(existingEntry.payload['status'], 'NEW');
      verifyNever(mockBox.put(any, any));
      verify(existingEntry.save()).called(1);
    });

    test('STOCK_ADJUSTMENT does not coalesce when pending entry exists', () async {
      final existingEntry = SyncQueueEntry(
        id: '1',
        entityId: 'warehouse_1',
        operationType: 'STOCK_ADJUSTMENT',
        payloadJson: '{"quantity": 5}',
        createdAt: DateTime.now(),
      );
      existingEntry.status = 'PENDING';

      when(mockBox.values).thenReturn([existingEntry]);

      await syncService.enqueueOperation(
        entityId: 'warehouse_1',
        operationType: 'STOCK_ADJUSTMENT',
        payload: {'quantity': 2},
      );

      // Verify it did NOT overwrite the existing entry
      expect(existingEntry.payload['quantity'], 5);
      
      // Verify a NEW entry was added
      verify(mockBox.put(any, any)).called(1);
    });

    test('PAY_SUPPLIER does not coalesce', () async {
      final existingEntry = SyncQueueEntry(
        id: '1',
        entityId: 'supplier_1',
        operationType: 'PAY_SUPPLIER',
        payloadJson: '{"amount": 100}',
        createdAt: DateTime.now(),
      );
      existingEntry.status = 'PENDING';

      when(mockBox.values).thenReturn([existingEntry]);

      await syncService.enqueueOperation(
        entityId: 'supplier_1',
        operationType: 'PAY_SUPPLIER',
        payload: {'amount': 50},
      );

      // Verify it did NOT overwrite the existing entry
      expect(existingEntry.payload['amount'], 100);
      
      // Verify a NEW entry was added
      verify(mockBox.put(any, any)).called(1);
    });
  });
}
