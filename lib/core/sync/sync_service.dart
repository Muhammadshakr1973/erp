import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
    // Duplicate prevention: check if a pending operation for the exact same entity and type exists
    // to avoid redundant submissions, while preserving ordering integrity
    final existingPending = box.values
        .where(
          (e) =>
              e.entityId == entityId &&
              e.operationType == operationType &&
              (e.status == 'PENDING' || e.status == 'FAILED'),
        )
        .toList();

    if (existingPending.isNotEmpty) {
      // Overwrite the payload of the existing one to avoid duplicates of the exact same operation
      final entry = existingPending.first;
      entry.payload = payload;
      entry.status = 'PENDING';
      entry.errorInformation = null;
      entry.retryCount = 0;
      await entry.save();
    } else {
      final randomHex = _generateRandomHex(8);
      final uniqueId = '${DateTime.now().microsecondsSinceEpoch}_${entityId}_$randomHex';
      
      final entry = SyncQueueEntry(
        id: uniqueId,
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

    final Map<String, dynamic> idMap = {};
    try {
      final idMappingsBox = await Hive.openBox<String>('id_mappings');
      for (final key in idMappingsBox.keys) {
        final val = idMappingsBox.get(key);
        if (val != null) {
          idMap[key.toString()] = val;
        }
      }
    } catch (_) {}

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
        // Resolve ordering dependencies / replace temporary IDs with actual server IDs
        _resolvePendingEntryWithMap(entry, idMap);

        // Dependency Guard: If entityId is still a temporary local ID ('local_...') for a non-creation operation,
        // it means its parent creation operation has not resolved a server ID yet.
        final isCreationOp = entry.operationType == 'CREATE_ORDER' ||
            entry.operationType == 'CREATE_CUSTOMER' ||
            entry.operationType == 'STORE_DELIVERY' ||
            entry.operationType == 'STOCK_TRANSFER_CREATE' ||
            entry.operationType == 'CREATE_SALES_RETURN';

        if (!isCreationOp && entry.entityId != null && entry.entityId!.startsWith('local_')) {
          // Parent creation has not finished or failed; keep this operation PENDING and wait for parent resolution
          entry.status = 'PENDING';
          entry.errorInformation = 'چاوەڕوانی ته‌واوبوونی داواکاری سەرەکی؛ شوێنکەوتوو PENDING دەمێنێتەوە';
          await entry.save();
          break;
        }

        entry.status = 'SYNCING';
        await entry.save();

        try {
          final result = await _performOperation(entry);
          entry.status = 'COMPLETED';
          entry.syncResult = result;
          await entry.save();

          // If the entry created an entity (e.g. customer/order) and had a temporary ID, map it to server ID
          if (entry.entityId != null && entry.entityId!.startsWith('local_')) {
            dynamic serverId;
            if (result is Map) {
              if (result['data'] != null && result['data']['id'] != null) {
                serverId = result['data']['id'];
              } else if (result['id'] != null) {
                serverId = result['id'];
              }
            }
            if (serverId != null) {
              idMap[entry.entityId!] = serverId;

              try {
                final idMappingsBox = await Hive.openBox<String>('id_mappings');
                await idMappingsBox.put(entry.entityId!, serverId.toString());

                // Generate and save negative integer ID mapping support
                final cleanStr = entry.entityId!.replaceAll(RegExp(r'[^0-9]'), '');
                final val = int.tryParse(cleanStr);
                if (val != null) {
                  final intId = -1 * (val % 1000000000);
                  idMap[intId.toString()] = serverId;
                  await idMappingsBox.put(intId.toString(), serverId.toString());
                }
              } catch (_) {}

              // Reconcile and migrate optimistic cached order if this was CREATE_ORDER
              if (entry.operationType == 'CREATE_ORDER') {
                try {
                  final localBox = await Hive.openBox<String>('local_orders');
                  final cachedStr = localBox.get(entry.entityId);
                  if (cachedStr != null) {
                    final Map<String, dynamic> cachedJson = Map<String, dynamic>.from(jsonDecode(cachedStr));
                    cachedJson['id'] = serverId;

                    if (result is Map) {
                      final responseData = result['data'] ?? result;
                      if (responseData is Map) {
                        if (responseData['order_number'] != null) {
                          cachedJson['order_number'] = responseData['order_number'];
                        }
                        if (responseData['status'] != null) {
                          cachedJson['status'] = responseData['status'];
                        }
                        if (responseData['created_at'] != null) {
                          cachedJson['created_at'] = responseData['created_at'];
                        }
                      }
                    }
                    cachedJson['pending_sync'] = false;

                    // Migrate: save with server ID as key, remove the local ID key
                    await localBox.put(serverId.toString(), jsonEncode(cachedJson));
                    await localBox.delete(entry.entityId);
                  }
                } catch (_) {}
              }
            }
          }
        } on DioException catch (e) {
          final statusCode = e.response?.statusCode;

          if (statusCode == 401 || statusCode == 403) {
            // Authentication issue: stop synchronization immediately, keep entry pending/failed
            entry.status = 'PENDING';
            entry.errorInformation = 'متمانەکردن بەسەرچووە، تکایە دووبارە بچۆ ژوورەوە';
            await entry.save();
            break; // Pause syncing loop
          } else if (statusCode == 409) {
            // Idempotency Conflict / already processing
            entry.status = 'PENDING';
            entry.errorInformation = 'ئەم کردەوەیە ئێستا لە سێرڤەردا لە پرۆسەدایە...';
            await entry.save();
            break; // Pause syncing loop
          } else if (statusCode == 422 || statusCode == 400) {
            // Validation/Client errors: inherently invalid request
            // Mark as FAILED and set retry count to max to prevent infinite retry loops
            entry.status = 'FAILED';
            entry.retryCount = 999; 
            entry.errorInformation = 'داتاکانی نێردراو ڕەتکرانەوە: ${api.parseError(e)}';
            await entry.save();
          } else if (_isNetworkError(e)) {
            entry.status = 'PENDING'; // Keep pending for network recovery
            entry.errorInformation = 'کێشەی هێڵ: ${api.parseError(e)}';
            await entry.save();
            break; // Stop syncing other items if network is down
          } else {
            entry.status = 'FAILED';
            entry.retryCount += 1;
            entry.errorInformation = api.parseError(e);
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

  void _resolvePendingEntryWithMap(SyncQueueEntry entry, Map<String, dynamic> idMap) {
    if (idMap.isEmpty) return;

    // 1. Resolve entityId itself if it was mapped from a temporary local ID
    if (entry.entityId != null && idMap.containsKey(entry.entityId)) {
      entry.entityId = idMap[entry.entityId].toString();
    }

    // 2. Resolve recursive occurrences of local IDs inside the payload
    try {
      final decoded = entry.payload;
      final resolved = _resolveValue(decoded, idMap);
      entry.payload = resolved as Map<String, dynamic>;
    } catch (_) {}
  }

  dynamic _resolveValue(dynamic value, Map<String, dynamic> idMap) {
    if (value is String && idMap.containsKey(value)) {
      return idMap[value];
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _resolveValue(v, idMap)));
    }
    if (value is List) {
      return value.map((v) => _resolveValue(v, idMap)).toList();
    }
    return value;
  }

  Future<Map<String, dynamic>> _performOperation(SyncQueueEntry entry) async {
    final options = Options(
      headers: {
        'X-Idempotency-Key': entry.id,
      },
    );

    // Map operationType to actual API calls
    switch (entry.operationType) {
      case 'CREATE_ORDER':
        final response = await api.client.post(
          '/orders',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'UPDATE_ORDER':
        final response = await api.client.put(
          '/orders/${entry.entityId}',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'UPDATE_ORDER_STATUS':
        final response = await api.client.post(
          '/orders/${entry.entityId}/status',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'CREATE_CUSTOMER':
        final response = await api.client.post(
          '/customers',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'UPDATE_CUSTOMER':
        final response = await api.client.put(
          '/customers/${entry.entityId}',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'CREATE_PAYMENT':
        final response = await api.client.post(
          '/payments',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'STORE_DELIVERY':
        final response = await api.client.post(
          '/delivery-trips',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'DELIVER_ORDER':
        final response = await api.client.post(
          '/delivery-trips/orders/${entry.entityId}/deliver',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'FAIL_ORDER':
        final response = await api.client.post(
          '/delivery-trips/orders/${entry.entityId}/fail',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'CREATE_SALES_RETURN':
        final response = await api.client.post(
          '/sales-returns',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'PURCHASE_RECEIVE':
        final response = await api.client.post(
          '/purchase-orders/${entry.entityId}/receive',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'STOCK_TRANSFER_CREATE':
        final response = await api.client.post(
          '/stock-transfers',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'STOCK_TRANSFER_COMPLETE':
        final response = await api.client.post(
          '/stock-transfers/${entry.entityId}/complete',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'STOCK_TRANSFER_CANCEL':
        final response = await api.client.post(
          '/stock-transfers/${entry.entityId}/cancel',
          data: entry.payload,
          options: options,
        );
        return response.data;
      case 'STOCK_ADJUSTMENT':
        final warehouseId = entry.payload['warehouse_id'] ?? entry.entityId;
        final productId = entry.payload['product_id'];
        final response = await api.client.post(
          '/warehouses/$warehouseId/stock/$productId/adjust',
          data: entry.payload,
          options: options,
        );
        return response.data;
      default:
        throw Exception('Unknown operation type: ${entry.operationType}');
    }
  }

  String _generateRandomHex(int length) {
    final random = Random();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
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
