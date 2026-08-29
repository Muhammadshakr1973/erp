import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';
import '../../../products/models/supplier_ledger_model.dart';
import '../../../shared/models/customer_ledger_model.dart';
import '../../../shared/models/payment_history_model.dart';
import '../../../shared/models/report_models.dart';

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

// Sales Report Provider
final salesReportProvider = FutureProvider.family<SalesReportData, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/sales', queryParameters: filters);
    if (response.statusCode == 200) {
      return SalesReportData.fromJson(response.data['data'] ?? {});
    }
    throw Exception('نەتوانرا داتای ڕاپۆرتی فرۆشتن بهێنرێت');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

// Profit Report Provider
final profitReportProvider = FutureProvider.family<ProfitReportData, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/profit', queryParameters: filters);
    if (response.statusCode == 200) {
      return ProfitReportData.fromJson(response.data['data'] ?? {});
    }
    throw Exception('نەتوانرا داتای ڕاپۆرتی قازانج بهێنرێت');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

// Sales by Salesman Provider
final salesBySalesmanReportProvider = FutureProvider.family<SalesBySalesmanReportData, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/sales-by-salesman', queryParameters: filters);
    if (response.statusCode == 200) {
      return SalesBySalesmanReportData.fromJson(response.data['data'] ?? {});
    }
    throw Exception('نەتوانرا داتای فرۆشتنی مەندوبەکان بهێنرێت');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

// Low Stock Alert Provider
final lowStockReportProvider = FutureProvider.family<LowStockReportData, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/low-stock', queryParameters: filters);
    if (response.statusCode == 200) {
      return LowStockReportData.fromJson(response.data['data'] ?? {});
    }
    throw Exception('نەتوانرا داتای کاڵا کەمبووەکان بهێنرێت');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

// Stock Movements Provider
final stockMovementsReportProvider = FutureProvider.family<StockMovementsReportData, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/stock-movements', queryParameters: filters);
    if (response.statusCode == 200) {
      return StockMovementsReportData.fromJson(response.data['data'] ?? {});
    }
    throw Exception('نەتوانرا داتای جوڵەی ستۆک بهێنرێت');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

// Stock Transfers Provider
final stockTransfersReportProvider = FutureProvider.family<StockTransfersReportData, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/reports/stock-transfers', queryParameters: filters);
    if (response.statusCode == 200) {
      return StockTransfersReportData.fromJson(response.data['data'] ?? {});
    }
    throw Exception('نەتوانرا داتای گواستنەوەکان بهێنرێت');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});
