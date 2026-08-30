import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../api_client.dart';
import 'sync_queue_entry.dart';

final syncQueueBoxProvider = Provider<Box<SyncQueueEntry>>((ref) {
  return Hive.box<SyncQueueEntry>('sync_queue');
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final api = ref.watch(apiClientProvider);
  final box = ref.watch(syncQueueBoxProvider);
  return SyncService(api, box, ref);
});

class SyncService {
  final ApiClient api;
  final Box<SyncQueueEntry> box;
  final Ref ref;
  bool _isSyncing = false;

  // To avoid running syncs concurrently
  Timer? _syncTimer;

  SyncService(this.api, this.box, this.ref) {
    // Attempt sync periodically or on init
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      syncPendingOperations();
    });
  }

  void dispose() {
    _syncTimer?.cancel();
  }

  Future<void> enqueueOperation({
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    // Duplicate prevention: check if a pending operation for the same entity and type exists
    final existingPending = box.values
        .where(
          (e) =>
              e.entityId == entityId &&
              e.operationType == operationType &&
              (e.status == 'PENDING' || e.status == 'FAILED'),
        )
        .toList();

    if (existingPending.isNotEmpty) {
      // Overwrite the payload of the existing one to avoid duplicates
      final entry = existingPending.first;
      entry.payload = payload;
      entry.status = 'PENDING';
      entry.errorInformation = null;
      entry.retryCount = 0;
      await entry.save();
    } else {
      final entry = SyncQueueEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        entityId: entityId,
        operationType: operationType,
        payloadJson: '',
        createdAt: DateTime.now(),
      );
      entry.payload = payload;
      await box.put(entry.id, entry);
    }

    // Attempt sync immediately
    syncPendingOperations();
  }

  Future<void> syncPendingOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingEntries =
          box.values
              .where(
                (e) =>
                    e.status == 'PENDING' ||
                    (e.status == 'FAILED' && e.retryCount < 5),
              )
              .toList()
            ..sort(
              (a, b) => a.createdAt.compareTo(b.createdAt),
            ); // Oldest first

      for (var entry in pendingEntries) {
        entry.status = 'SYNCING';
        await entry.save();

        try {
          final result = await _performOperation(entry);
          entry.status = 'COMPLETED';
          entry.syncResult = result;
          await entry.save();
          // Optionally delete completed entries to save space:
          // await entry.delete();
        } on DioException catch (e) {
          if (_isNetworkError(e)) {
            entry.status = 'PENDING'; // Keep pending for network recovery
            entry.errorInformation = 'Network error';
            await entry.save();
            break; // Stop syncing other items if network is down
          } else {
            entry.status = 'FAILED';
            entry.retryCount += 1;
            entry.errorInformation = api.parseError(e);

            // Conflict handling: if it's a 409 conflict, we might need specific logic or let the user resolve it.
            // Server authority: the server's response dictates failure.
            await entry.save();
          }
        } catch (e) {
          entry.status = 'FAILED';
          entry.retryCount += 1;
          entry.errorInformation = e.toString();
          await entry.save();
        }
      }
    } finally {
      _isSyncing = false;
      // Notify listeners of sync status change
      ref.invalidate(syncStatusProvider);
    }
  }

  Future<Map<String, dynamic>> _performOperation(SyncQueueEntry entry) async {
    // Map operationType to actual API calls
    switch (entry.operationType) {
      case 'CREATE_ORDER':
        final response = await api.client.post('/orders', data: entry.payload);
        return response.data;
      case 'UPDATE_ORDER':
        final response2 = await api.client.put(
          '/orders/${entry.entityId}',
          data: entry.payload,
        );
        return response2.data;
      case 'UPDATE_CUSTOMER':
        final response = await api.client.put(
          '/customers/${entry.entityId}',
          data: entry.payload,
        );
        return response.data;
      // Add other operations as needed
      default:
        throw Exception('Unknown operation type: ${entry.operationType}');
    }
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}

// User-visible sync status
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final box = ref.watch(syncQueueBoxProvider);
  final pending = box.values.where((e) => e.status == 'PENDING').length;
  final failed = box.values.where((e) => e.status == 'FAILED').length;

  if (failed > 0) return SyncStatus.error;
  if (pending > 0) return SyncStatus.syncing;
  return SyncStatus.synced;
});

enum SyncStatus { synced, syncing, error }
