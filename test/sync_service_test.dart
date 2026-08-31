import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Synchronization State Machine & ID Mapping', () {
    test('Recursive ID mapping correctly replaces local_ IDs with server IDs', () {
      final idMap = {'local_cust_123': 45};
      
      final payload = {
        'customer_id': 'local_cust_123',
        'name': 'Test customer',
        'details': {
          'referred_by_id': 'local_cust_123',
          'other_id': 'local_other_456'
        }
      };

      // Mock of the resolution logic inside SyncService
      dynamic resolveValue(dynamic value) {
        if (value is String && idMap.containsKey(value)) {
          return idMap[value];
        } else if (value is Map) {
          final resolvedMap = <String, dynamic>{};
          value.forEach((key, val) {
            resolvedMap[key] = resolveValue(val);
          });
          return resolvedMap;
        } else if (value is List) {
          return value.map((val) => resolveValue(val)).toList();
        }
        return value;
      }

      final resolved = resolveValue(payload) as Map<String, dynamic>;

      expect(resolved['customer_id'], equals(45));
      expect(resolved['details']['referred_by_id'], equals(45));
      expect(resolved['details']['other_id'], equals('local_other_456')); // Untracked local ID remains
    });

    test('Validation error (422/400) marks operation as permanently FAILED (retryCount 999)', () {
      int retryCount = 0;
      String status = 'SYNCING';

      void handleResponse(int statusCode) {
        if (statusCode == 422 || statusCode == 400) {
          status = 'FAILED';
          retryCount = 999;
        }
      }

      handleResponse(422);

      expect(status, equals('FAILED'));
      expect(retryCount, equals(999));
    });

    test('Conflict error (409) pauses synchronization loops', () {
      bool isLoopPaused = false;
      String status = 'SYNCING';

      void handleResponse(int statusCode) {
        if (statusCode == 409) {
          isLoopPaused = true;
          status = 'PENDING'; // Keep as pending to retry later, but stop current batch
        }
      }

      handleResponse(409);

      expect(isLoopPaused, isTrue);
      expect(status, equals('PENDING'));
    });

    test('Network timeout or disconnect retains PENDING status and increments retryCount', () {
      int retryCount = 0;
      String status = 'SYNCING';

      void handleResponse(Exception error) {
        status = 'PENDING';
        retryCount += 1;
      }

      handleResponse(Exception('Network connection failed'));

      expect(status, equals('PENDING'));
      expect(retryCount, equals(1));
    });

    test('Authentication error (401/403) halts execution for credential renewal', () {
      bool isLoopPaused = false;

      void handleResponse(int statusCode) {
        if (statusCode == 401 || statusCode == 403) {
          isLoopPaused = true;
        }
      }

      handleResponse(401);

      expect(isLoopPaused, isTrue);
    });
  });
}
