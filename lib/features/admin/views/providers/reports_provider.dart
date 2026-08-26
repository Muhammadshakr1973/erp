import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';
import '../../../products/models/supplier_ledger_model.dart';
import '../../../products/models/supplier_model.dart';
import '../../../shared/models/customer_ledger_model.dart';
import '../../../shared/models/payment_history_model.dart';

final supplierDebtsReportProvider = FutureProvider.family<List<SupplierLedgerModel>, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/supplier-debts', queryParameters: filters);
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => SupplierLedgerModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final customerDebtsReportProvider = FutureProvider.family<List<CustomerLedgerModel>, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/customer-debts', queryParameters: filters);
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => CustomerLedgerModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final paymentsHistoryReportProvider = FutureProvider.family<List<PaymentHistoryModel>, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/payments-history', queryParameters: filters);
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => PaymentHistoryModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});
