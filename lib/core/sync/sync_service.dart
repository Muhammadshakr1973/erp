import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../api_client.dart';
import 'sync_queue_entry.dart';

enum SyncStatus {
  synced,
  pending,
  syncing,
  error,
  offline,
  idle,
  completed,
  failed,
}

final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return SyncStatus.synced;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final api = ref.watch(apiClientProvider);
  final service = SyncService(api: api, ref: ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class SyncService {
  final ApiClient _api;
  final Ref _ref;
  Box<SyncQueueEntry>? _box;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;

  SyncService({
    required ApiClient api,
    required Ref ref,
    Box<SyncQueueEntry>? box,
  })  : _api = api,
        _ref = ref,
        _box = box;

  ApiClient get api => _api;
  Ref get ref => _ref;

  Box<SyncQueueEntry> get box {
    if (_box != null) return _box!;
    if (Hive.isBoxOpen('sync_queue')) {
      return Hive.box<SyncQueueEntry>('sync_queue');
    }
    throw StateError(
      'SyncQueue box is not opened yet. Call Hive.openBox<SyncQueueEntry>("sync_queue") first.',
    );
  }

  void dispose() {
    _autoSyncTimer?.cancel();
  }

  Future<void> enqueueOperation({
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
    String? customId,
  }) async {
    final id = customId ??
        '${DateTime.now().millisecondsSinceEpoch}_${operationType.toLowerCase()}_${entityId}_${UniqueKey().hashCode}';

    final entry = SyncQueueEntry(
      id: id,
      entityId: entityId,
      operationType: operationType,
      payloadJson: jsonEncode(payload),
      createdAt: DateTime.now(),
      status: 'PENDING',
    );

    try {
      if (Hive.isBoxOpen('sync_queue')) {
        await Hive.box<SyncQueueEntry>('sync_queue').put(entry.id, entry);
      }
    } catch (e) {
      debugPrint('SyncService enqueueOperation storage error: $e');
    }

    _updateSyncStatus();
  }

  Future<void> syncPendingOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      if (!Hive.isBoxOpen('sync_queue')) {
        _updateSyncStatus();
        return;
      }

      final queueBox = Hive.box<SyncQueueEntry>('sync_queue');
      final pendingEntries = queueBox.values
          .where((e) => e.status == 'PENDING')
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final entry in pendingEntries) {
        entry.status = 'SYNCING';
        try {
          if (entry.isInBox) {
            await entry.save();
          }
        } catch (_) {}

        try {
          final response = await _performOperation(entry);

          if (response.statusCode == 200 || response.statusCode == 201) {
            entry.status = 'COMPLETED';
            entry.syncResult = response.data is Map
                ? Map<String, dynamic>.from(response.data as Map)
                : {'data': response.data};
            entry.errorInformation = null;
            try {
              if (entry.isInBox) {
                await entry.save();
              }
            } catch (_) {}
          } else {
            entry.status = 'PENDING';
            entry.retryCount += 1;
            try {
              if (entry.isInBox) {
                await entry.save();
              }
            } catch (_) {}
          }
        } on DioException catch (e) {
          final statusCode = e.response?.statusCode;
          if (statusCode == 409) {
            // Conflict / in-progress on server: retain PENDING and pause batch
            entry.status = 'PENDING';
            entry.errorInformation =
                'ئەم کردەوەیە ئێستا لە سێرڤەردا لە پرۆسەدایە...';
            try {
              if (entry.isInBox) {
                await entry.save();
              }
            } catch (_) {}
            break; // Pause sync batch
          } else if (statusCode == 422 || statusCode == 400) {
            // Permanent client error / payload mismatch: mark FAILED
            entry.status = 'FAILED';
            entry.retryCount = 999;
            entry.errorInformation = _api.parseError(e);
            try {
              if (entry.isInBox) {
                await entry.save();
              }
            } catch (_) {}
          } else {
            // Network failure or temporary 500: retain PENDING for retry
            entry.status = 'PENDING';
            entry.retryCount += 1;
            entry.errorInformation = _api.parseError(e);
            try {
              if (entry.isInBox) {
                await entry.save();
              }
            } catch (_) {}
          }
        } catch (e) {
          entry.status = 'PENDING';
          entry.retryCount += 1;
          entry.errorInformation = e.toString();
          try {
            if (entry.isInBox) {
              await entry.save();
            }
          } catch (_) {}
        }
      }
    } finally {
      _isSyncing = false;
      _updateSyncStatus();
    }
  }

  Future<Response> _performOperation(SyncQueueEntry entry) async {
    final headers = <String, dynamic>{
      'X-Idempotency-Key': entry.id,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final payload = entry.payload;

    switch (entry.operationType) {
      case 'CREATE_ORDER':
        return await _api.client.post(
          '/orders',
          data: payload,
          options: Options(headers: headers),
        );
      case 'UPDATE_ORDER':
        return await _api.client.put(
          '/orders/${entry.entityId}',
          data: payload,
          options: Options(headers: headers),
        );
      case 'CREATE_SALES_RETURN':
        return await _api.client.post(
          '/sales-returns',
          data: payload,
          options: Options(headers: headers),
        );
      case 'DELIVER_ORDER':
        return await _api.client.post(
          '/delivery-trips/orders/${entry.entityId}/deliver',
          data: payload,
          options: Options(headers: headers),
        );
      case 'FAIL_ORDER':
        return await _api.client.post(
          '/delivery-trips/orders/${entry.entityId}/fail',
          data: payload,
          options: Options(headers: headers),
        );
      case 'RECORD_PAYMENT':
      case 'CREATE_PAYMENT':
        return await _api.client.post(
          '/payments',
          data: payload,
          options: Options(headers: headers),
        );
      case 'CREATE_PURCHASE_ORDER':
        return await _api.client.post(
          '/purchase-orders',
          data: payload,
          options: Options(headers: headers),
        );
      case 'RECEIVE_PURCHASE_ORDER':
        return await _api.client.post(
          '/purchase-orders/${entry.entityId}/receive',
          data: payload,
          options: Options(headers: headers),
        );
      case 'STOCK_TRANSFER':
        return await _api.client.post(
          '/stock-transfers',
          data: payload,
          options: Options(headers: headers),
        );
      default:
        return await _api.client.post(
          '/sync-operations',
          data: payload,
          options: Options(headers: headers),
        );
    }
  }

  Future<void> clearCompletedOperations() async {
    if (!Hive.isBoxOpen('sync_queue')) return;
    final queueBox = Hive.box<SyncQueueEntry>('sync_queue');
    final completedKeys = queueBox.values
        .where((e) => e.status == 'COMPLETED')
        .map((e) => e.id)
        .toList();
    for (final key in completedKeys) {
      await queueBox.delete(key);
    }
    _updateSyncStatus();
  }

  Future<void> clearFailedOperations() async {
    if (!Hive.isBoxOpen('sync_queue')) return;
    final queueBox = Hive.box<SyncQueueEntry>('sync_queue');
    final failedKeys = queueBox.values
        .where((e) => e.status == 'FAILED')
        .map((e) => e.id)
        .toList();
    for (final key in failedKeys) {
      await queueBox.delete(key);
    }
    _updateSyncStatus();
  }

  void _updateSyncStatus() {
    if (!Hive.isBoxOpen('sync_queue')) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
      return;
    }

    final queueBox = Hive.box<SyncQueueEntry>('sync_queue');
    final entries = queueBox.values.toList();

    if (entries.any((e) => e.status == 'SYNCING')) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    } else if (entries.any((e) => e.status == 'PENDING')) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.pending;
    } else if (entries.any((e) => e.status == 'FAILED')) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    } else {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
    }
  }
}
