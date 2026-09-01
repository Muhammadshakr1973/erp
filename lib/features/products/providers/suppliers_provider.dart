import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/supplier_model.dart';
import '../models/supplier_ledger_model.dart';

final suppliersListProvider = FutureProvider<List<SupplierModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/suppliers');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
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
          final List data = response.data['data'] ?? [];
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
      return SupplierModel.fromJson(response.data['data']);
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
      return SupplierModel.fromJson(response.data['data']);
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
      return SupplierModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
