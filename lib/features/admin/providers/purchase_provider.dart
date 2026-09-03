import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../models/purchase_requirement_model.dart';
import '../models/purchase_order_model.dart';

final purchaseRequirementsProvider =
    FutureProvider<List<PurchaseRequirementModel>>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      try {
        final response = await apiClient.client.get('/purchase-requirements');
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed purchase requirements response payload)',
          );
        }
        final List<dynamic> data = resData['data'] as List;
        return data
            .map((json) => PurchaseRequirementModel.fromJson(json))
            .toList();
      } catch (e) {
        throw Exception(apiClient.parseError(e));
      }
    });


final purchaseRequirementsGroupProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.client.get('/purchase-requirements/group');
    final resData = response.data;
    if (resData is! Map || resData['data'] is! List) {
      throw FormatException(
        'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed grouped purchase requirements response payload)',
      );
    }
    return resData['data'] as List<dynamic>;
  } catch (e) {
    throw Exception(apiClient.parseError(e));
  }
});

final purchaseOrdersProvider = FutureProvider<List<PurchaseOrderModel>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.client.get('/purchase-orders');
    final resData = response.data;
    if (resData is! Map || resData['data'] is! List) {
      throw FormatException(
        'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed purchase orders response payload)',
      );
    }
    final List<dynamic> data = resData['data'] as List;
    return data.map((json) => PurchaseOrderModel.fromJson(json)).toList();
  } catch (e) {
    throw Exception(apiClient.parseError(e));
  }
});

final purchaseActionsProvider = Provider<PurchaseActions>((ref) {
  return PurchaseActions(ref);
});

class PurchaseActions {
  final Ref _ref;

  PurchaseActions(this._ref);

  Future<void> convertRequirementsToPO({
    required List<int> requirementIds,
    String? notes,
    String? idempotencyKey,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final sortedIds = List<int>.from(requirementIds)..sort();
      final key = idempotencyKey ??
          'convert_${sortedIds.join('_')}_${_deterministicHash(notes ?? 'none')}';

      await apiClient.client.post(
        '/purchase-requirements/convert',
        data: {'requirement_ids': sortedIds, 'notes': notes},
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      // Invalidate the lists to trigger a refresh
      _ref.invalidate(purchaseRequirementsProvider);
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> confirmPurchaseOrder(int orderId, {String? idempotencyKey}) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final key = idempotencyKey ?? 'confirm_po_$orderId';
      await apiClient.client.post(
        '/purchase-orders/$orderId/confirm',
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> receivePurchaseOrder(int orderId, {List<Map<String, dynamic>>? items}) async {
    final apiClient = _ref.read(apiClientProvider);
    final syncService = _ref.read(syncServiceProvider);
    try {
      final payload = <String, dynamic>{};
      if (items != null && items.isNotEmpty) {
        payload['items'] = items;
      }
      await syncService.enqueueOperation(
        entityId: orderId.toString(),
        operationType: 'PURCHASE_RECEIVE',
        payload: payload,
      );
      await syncService.syncPendingOperations();
      // Invalidate purchase orders provider to refresh list
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> cancelPurchaseOrder(int orderId, {String? idempotencyKey}) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final key = idempotencyKey ?? 'cancel_po_$orderId';
      await apiClient.client.post(
        '/purchase-orders/$orderId/cancel',
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      // Invalidate both lists
      _ref.invalidate(purchaseOrdersProvider);
      _ref.invalidate(purchaseRequirementsProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }
}

String _deterministicHash(String input) {
  final bytes = utf8.encode(input);
  // FNV-1a 32-bit
  int fnvHash = 2166136261;
  for (final byte in bytes) {
    fnvHash ^= byte;
    fnvHash = (fnvHash * 16777619) & 0xFFFFFFFF;
  }

  // DJB2 hash
  int djbHash = 5381;
  for (final byte in bytes) {
    djbHash = ((djbHash << 5) + djbHash) + byte;
    djbHash = djbHash & 0xFFFFFFFF;
  }

  final fnvHex = fnvHash.toRadixString(16).padLeft(8, '0');
  final djbHex = djbHash.toRadixString(16).padLeft(8, '0');
  return '$fnvHex$djbHex';
}
