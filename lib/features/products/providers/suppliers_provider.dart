import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/supplier_model.dart';
import '../models/supplier_ledger_model.dart';
import '../models/supplier_reconciliation_model.dart';

final suppliersListProvider = FutureProvider<List<SupplierModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
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
});

final supplierLedgerProvider =
    FutureProvider.family<List<SupplierLedgerModel>, int>((
      ref,
      supplierId,
    ) async {
      final api = ref.watch(apiClientProvider);
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
    });

final supplierReconciliationProvider =
    FutureProvider.family<SupplierReconciliationModel, int>((
      ref,
      supplierId,
    ) async {
      final api = ref.watch(apiClientProvider);
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
    });

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
      ref.invalidate(suppliersListProvider);
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier response payload)',
        );
      }
      return SupplierModel.fromJson(Map<String, dynamic>.from(resData['data']));
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
      ref.invalidate(suppliersListProvider);
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier response payload)',
        );
      }
      return SupplierModel.fromJson(Map<String, dynamic>.from(resData['data']));
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteSupplier(int id) async {
    try {
      await api.client.delete('/suppliers/$id');
      ref.invalidate(suppliersListProvider);
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
      ref.invalidate(suppliersListProvider);
      ref.invalidate(supplierLedgerProvider(id));
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier response payload)',
        );
      }
      return SupplierModel.fromJson(Map<String, dynamic>.from(resData['data']));
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
      ref.invalidate(suppliersListProvider);
      ref.invalidate(supplierReconciliationProvider(id));
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed reconciliation response payload)',
        );
      }
      return SupplierReconciliationModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
