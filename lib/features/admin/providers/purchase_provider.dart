import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../products/providers/products_provider.dart';
import '../../products/providers/suppliers_provider.dart';
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

class PurchaseOrdersNotifier extends AsyncNotifier<List<PurchaseOrderModel>> {
  final Map<int, PurchaseOrderModel> _localOrders = {};
  final Set<int> _removedOrderIds = {};

  @override
  Future<List<PurchaseOrderModel>> build() async {
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
      final orders = data
          .map((json) => PurchaseOrderModel.fromJson(json))
          .toList();
      final fetchedIds = orders.map((order) => order.id).toSet();
      _removedOrderIds.removeWhere((id) => !fetchedIds.contains(id));
      _localOrders.removeWhere((id, _) => fetchedIds.contains(id));
      orders.removeWhere((order) => _removedOrderIds.contains(order.id));
      return _mergeOrders(orders, _localOrders.values);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  void upsertOrderLocally(PurchaseOrderModel order) {
    _removedOrderIds.remove(order.id);
    _localOrders[order.id] = order;
    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      state = AsyncData(_mergeOrders(currentOrders, [order]));
    }
  }

  void removeOrderLocally(int orderId) {
    _localOrders.remove(orderId);
    _removedOrderIds.add(orderId);
    final currentOrders = state.valueOrNull;
    if (currentOrders != null) {
      state = AsyncData(
        currentOrders.where((order) => order.id != orderId).toList(),
      );
    }
  }

  List<PurchaseOrderModel> _mergeOrders(
    Iterable<PurchaseOrderModel> currentOrders,
    Iterable<PurchaseOrderModel> updates,
  ) {
    final ordersById = {
      for (final order in currentOrders) order.id: order,
      for (final order in updates) order.id: order,
    };
    final orders = ordersById.values.toList();
    orders.sort((a, b) {
      final aDate = a.createdAt == null
          ? null
          : DateTime.tryParse(a.createdAt!);
      final bDate = b.createdAt == null
          ? null
          : DateTime.tryParse(b.createdAt!);
      if (aDate == null) return bDate == null ? 0 : 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return orders;
  }
}

final purchaseOrdersProvider =
    AsyncNotifierProvider<PurchaseOrdersNotifier, List<PurchaseOrderModel>>(
      PurchaseOrdersNotifier.new,
    );

final purchaseActionsProvider = Provider<PurchaseActions>((ref) {
  return PurchaseActions(ref);
});

class PurchaseActions {
  final Ref _ref;

  PurchaseActions(this._ref);

  Future<PurchaseOrderModel> createPurchaseOrder({
    required int? supplierId,
    required int warehouseId,
    required List<Map<String, dynamic>> items,
    num? paidAmount,
    bool autoReceive = true,
    String? notes,
    bool refreshRelatedProviders = true,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final payload = <String, dynamic>{
        'supplier_id': supplierId,
        'warehouse_id': warehouseId,
        'items': items,
        'paid_amount': paidAmount ?? 0,
        'auto_receive': autoReceive,
        'notes': notes,
      };

      final response = await apiClient.client.post(
        '/purchase-orders',
        data: payload,
      );

      final resData = response.data;
      final poData = resData['data'];
      final order = PurchaseOrderModel.fromJson(poData);
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);

      if (refreshRelatedProviders) {
        _ref.invalidate(purchaseRequirementsProvider);
        _ref.invalidate(purchaseRequirementsGroupProvider);
        _ref.invalidate(productsListProvider);
        _ref.invalidate(suppliersListProvider);
      }

      return order;
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<PurchaseOrderModel> updatePurchaseOrder({
    required int orderId,
    int? supplierId,
    int? warehouseId,
    List<Map<String, dynamic>>? items,
    num? paidAmount,
    bool? autoReceive,
    String? notes,
    bool refreshRelatedProviders = true,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final payload = <String, dynamic>{
        if (supplierId != null) 'supplier_id': supplierId,
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (items != null) 'items': items,
        if (paidAmount != null) 'paid_amount': paidAmount,
        if (autoReceive != null) 'auto_receive': autoReceive,
        if (notes != null) 'notes': notes,
      };

      final response = await apiClient.client.put(
        '/purchase-orders/$orderId',
        data: payload,
      );

      final resData = response.data;
      final poData = resData['data'];
      final order = PurchaseOrderModel.fromJson(poData);
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);

      if (refreshRelatedProviders) {
        _ref.invalidate(purchaseRequirementsProvider);
        _ref.invalidate(purchaseRequirementsGroupProvider);
        _ref.invalidate(productsListProvider);
        _ref.invalidate(suppliersListProvider);
      }

      return order;
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> deletePurchaseOrder(int orderId) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.client.delete('/purchase-orders/$orderId');
      _ref.read(purchaseOrdersProvider.notifier).removeOrderLocally(orderId);
      _ref.invalidate(purchaseRequirementsProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> convertRequirementsToPO({
    required List<int> requirementIds,
    List<Map<String, dynamic>>? requirementItems,
    List<Map<String, dynamic>>? additionalItems,
    String? notes,
    String? idempotencyKey,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final sortedIds = List<int>.from(requirementIds)..sort();
      final payload = <String, dynamic>{'notes': notes};
      if (requirementItems != null) {
        payload['requirement_items'] = requirementItems;
      } else {
        payload['requirement_ids'] = sortedIds;
      }
      if (additionalItems != null && additionalItems.isNotEmpty) {
        payload['additional_items'] = additionalItems;
      }
      final key = idempotencyKey ??
          'convert_${_deterministicHash(jsonEncode(payload))}';

      final response = await apiClient.client.post(
        '/purchase-requirements/convert',
        data: payload,
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed created purchase orders response payload)',
        );
      }
      for (final orderData in resData['data'] as List) {
        if (orderData is! Map) {
          throw FormatException(
            'داتای پسوڵەی کڕین لە وەڵامی سێرڤەر نادروستە',
          );
        }
        _ref
            .read(purchaseOrdersProvider.notifier)
            .upsertOrderLocally(
              PurchaseOrderModel.fromJson(
                Map<String, dynamic>.from(orderData),
              ),
            );
      }
      _ref.invalidate(purchaseRequirementsProvider);
      _ref.invalidate(purchaseRequirementsGroupProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> confirmPurchaseOrder(int orderId, {String? idempotencyKey}) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final key = idempotencyKey ?? 'confirm_po_$orderId';
      final response = await apiClient.client.post(
        '/purchase-orders/$orderId/confirm',
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      final order = _purchaseOrderFromResponse(response.data);
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }

  Future<void> receivePurchaseOrder(int orderId, {List<Map<String, dynamic>>? items}) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final payload = <String, dynamic>{};
      if (items != null && items.isNotEmpty) {
        payload['items'] = items;
      }
      final key = 'receive_po_${orderId}_${DateTime.now().microsecondsSinceEpoch}';
      final response = await apiClient.client.post(
        '/purchase-orders/$orderId/receive',
        data: payload,
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      final order = _purchaseOrderFromResponse(response.data);
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);
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
      final response = await apiClient.client.get(
        '/purchase-orders/$orderId',
      );
      final order = _purchaseOrderFromResponse(response.data);
      _ref.read(purchaseOrdersProvider.notifier).upsertOrderLocally(order);
      _ref.invalidate(purchaseRequirementsProvider);
    } catch (e) {
      throw Exception(apiClient.parseError(e));
    }
  }
}

PurchaseOrderModel _purchaseOrderFromResponse(dynamic responseData) {
  if (responseData is! Map || responseData['data'] is! Map) {
    throw FormatException(
      'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed purchase order response payload)',
    );
  }
  return PurchaseOrderModel.fromJson(
    Map<String, dynamic>.from(responseData['data']),
  );
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
