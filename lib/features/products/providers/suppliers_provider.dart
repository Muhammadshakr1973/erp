import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/supplier_model.dart';
import '../models/supplier_ledger_model.dart';
import '../models/supplier_reconciliation_model.dart';

class SuppliersListNotifier extends AsyncNotifier<List<SupplierModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<SupplierModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSuppliersEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for suppliersListProvider: $eventData");
      final eventType = eventData['event_type']?.toString();
      final supplierId = int.tryParse(eventData['supplier_id']?.toString() ?? '');
      if (eventType == 'delete' && supplierId != null && supplierId > 0) {
        removeSupplierLocally(supplierId);
        return;
      }
      if (supplierId != null &&
          supplierId > 0 &&
          eventData.containsKey('current_balance')) {
        final rawBalance = eventData['current_balance'];
        final parsedBalance = rawBalance is num
            ? rawBalance.round()
            : int.tryParse(rawBalance?.toString() ?? '');
        if (parsedBalance != null &&
            _patchSupplierBalanceLocally(supplierId, parsedBalance)) {
          return;
        }
      }
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-suppliers', onSuppliersEvent);
    pusher.subscribeToChannel('private-purchases', onSuppliersEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-suppliers', onSuppliersEvent);
      pusher.unsubscribeFromChannel('private-purchases', onSuppliersEvent);
    });

    return _fetchSuppliers(api);
  }

  Future<List<SupplierModel>> _fetchSuppliers(ApiClient api) async {
    try {
      final response = await api.client.get('/suppliers');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed suppliers response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data.map((json) => SupplierModel.fromJson(json)).toList();
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  bool _patchSupplierBalanceLocally(int supplierId, int balance) {
    final current = state.valueOrNull;
    if (current == null) return false;
    final idx = current.indexWhere((s) => s.id == supplierId);
    if (idx == -1) return false;
    final old = current[idx];
    if (old.debt == balance) return true;
    final updated = List<SupplierModel>.from(current);
    updated[idx] = SupplierModel(
      id: old.id,
      name: old.name,
      phone: old.phone,
      address: old.address,
      contactPerson: old.contactPerson,
      debt: balance,
    );
    state = AsyncData(updated);
    return true;
  }

  bool _sameList(List<SupplierModel> a, List<SupplierModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final sa = a[i];
      final sb = b[i];
      if (sa.id != sb.id ||
          sa.name != sb.name ||
          sa.phone != sb.phone ||
          sa.address != sb.address ||
          sa.contactPerson != sb.contactPerson ||
          sa.debt != sb.debt) {
        return false;
      }
    }
    return true;
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchSuppliers(api);
      final current = state.valueOrNull;
      if (current != null && _sameList(current, fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current suppliers on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }

  void upsertSupplierLocally(SupplierModel supplier) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((s) => s.id == supplier.id);
    final updated = List<SupplierModel>.from(current);
    if (idx != -1) {
      updated[idx] = supplier;
    } else {
      updated.insert(0, supplier);
    }
    state = AsyncData(updated);
  }

  void removeSupplierLocally(int supplierId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final filtered = current.where((s) => s.id != supplierId).toList();
    if (filtered.length != current.length) {
      state = AsyncData(filtered);
    }
  }
}

final suppliersListProvider =
    AsyncNotifierProvider<SuppliersListNotifier, List<SupplierModel>>(
  SuppliersListNotifier.new,
);

class SupplierLedgerNotifier
    extends FamilyAsyncNotifier<List<SupplierLedgerModel>, int> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<SupplierLedgerModel>> build(int arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSupplierLedgerEvent(Map<String, dynamic> eventData) {
      final eventSupplierId = eventData['supplier_id']?.toString();
      if (eventSupplierId != null && eventSupplierId != arg.toString()) {
        return;
      }
      debugPrint("Realtime update received for supplierLedgerProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-suppliers', onSupplierLedgerEvent);
    pusher.subscribeToChannel('private-purchases', onSupplierLedgerEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-suppliers', onSupplierLedgerEvent);
      pusher.unsubscribeFromChannel('private-purchases', onSupplierLedgerEvent);
    });

    return _fetchLedger(api, arg);
  }

  Future<List<SupplierLedgerModel>> _fetchLedger(
    ApiClient api,
    int supplierId,
  ) async {
    try {
      final response = await api.client.get('/suppliers/$supplierId/ledger');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier ledger response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data
            .map((json) => SupplierLedgerModel.fromJson(json))
            .toList();
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchLedger(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current ledger on transient error
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final supplierLedgerProvider = AsyncNotifierProvider.family<
    SupplierLedgerNotifier, List<SupplierLedgerModel>, int>(
  SupplierLedgerNotifier.new,
);

class SupplierReconciliationNotifier
    extends FamilyAsyncNotifier<SupplierReconciliationModel, int> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<SupplierReconciliationModel> build(int arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر چۆتە دەرەوە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSupplierReconcileEvent(Map<String, dynamic> eventData) {
      final eventSupplierId = eventData['supplier_id']?.toString();
      if (eventSupplierId != null && eventSupplierId != arg.toString()) {
        return;
      }
      debugPrint(
        "Realtime update received for supplierReconciliationProvider: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-suppliers', onSupplierReconcileEvent);
    pusher.subscribeToChannel('private-purchases', onSupplierReconcileEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-suppliers', onSupplierReconcileEvent);
      pusher.unsubscribeFromChannel('private-purchases', onSupplierReconcileEvent);
    });

    return _fetchReconcile(api, arg);
  }

  Future<SupplierReconciliationModel> _fetchReconcile(
    ApiClient api,
    int supplierId,
  ) async {
    try {
      final response =
          await api.client.get('/suppliers/$supplierId/reconcile');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed reconciliation response payload)',
          );
        }
        return SupplierReconciliationModel.fromJson(
          Map<String, dynamic>.from(resData['data']),
        );
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchReconcile(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current reconciliation on transient error
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }

  void setReconciliationLocally(SupplierReconciliationModel model) {
    state = AsyncData(model);
  }
}

final supplierReconciliationProvider = AsyncNotifierProvider.family<
    SupplierReconciliationNotifier, SupplierReconciliationModel, int>(
  SupplierReconciliationNotifier.new,
);

final supplierActionsProvider = Provider<SupplierActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return SupplierActions(api, ref);
});

class SupplierActions {
  final ApiClient api;
  final Ref ref;

  SupplierActions(this.api, this.ref);

  Future<SupplierModel> addSupplier(
    String name, {
    String? phone,
    String? address,
    String? contactPerson,
    int? initialDebt,
  }) async {
    try {
      final response = await api.client.post(
        '/suppliers',
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          'contact_person': contactPerson,
          'initial_debt': initialDebt,
        },
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier response payload)',
        );
      }
      final created = SupplierModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      if (ref.exists(suppliersListProvider)) {
        ref.read(suppliersListProvider.notifier).upsertSupplierLocally(created);
      }
      return created;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<SupplierModel> updateSupplier(
    int id,
    String name, {
    String? phone,
    String? address,
    String? contactPerson,
  }) async {
    try {
      final response = await api.client.put(
        '/suppliers/$id',
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          'contact_person': contactPerson,
        },
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier response payload)',
        );
      }
      final updated = SupplierModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      if (ref.exists(suppliersListProvider)) {
        ref.read(suppliersListProvider.notifier).upsertSupplierLocally(updated);
      }
      return updated;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteSupplier(int id) async {
    try {
      await api.client.delete('/suppliers/$id');
      if (ref.exists(suppliersListProvider)) {
        ref.read(suppliersListProvider.notifier).removeSupplierLocally(id);
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<SupplierModel> paySupplier(
    int id,
    int amount, {
    String? paymentMethod,
    String? notes,
  }) async {
    try {
      final response = await api.client.post(
        '/suppliers/$id/pay',
        data: {
          'amount': amount,
          'payment_method': paymentMethod ?? 'cash',
          'notes': notes,
        },
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier response payload)',
        );
      }
      final updated = SupplierModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      if (ref.exists(suppliersListProvider)) {
        ref.read(suppliersListProvider.notifier).upsertSupplierLocally(updated);
      }
      if (ref.exists(supplierLedgerProvider(id))) {
        unawaited(ref.read(supplierLedgerProvider(id).notifier).refreshSilently());
      }
      return updated;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<SupplierReconciliationModel> fixSupplierBalance(int id) async {
    try {
      final response = await api.client.post(
        '/suppliers/$id/reconcile',
        data: {'fix': true},
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed reconciliation response payload)',
        );
      }
      final result = SupplierReconciliationModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      if (ref.exists(suppliersListProvider)) {
        unawaited(ref.read(suppliersListProvider.notifier).refreshSilently());
      }
      if (ref.exists(supplierReconciliationProvider(id))) {
        ref
            .read(supplierReconciliationProvider(id).notifier)
            .setReconciliationLocally(result);
      }
      return result;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
