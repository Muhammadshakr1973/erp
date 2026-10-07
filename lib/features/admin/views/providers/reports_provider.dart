import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../../products/models/supplier_ledger_model.dart';
import '../../../shared/models/customer_ledger_model.dart';
import '../../../shared/models/payment_history_model.dart';
import '../../../shared/models/report_models.dart';

final supplierDebtsReportProvider =
    FutureProvider.family<List<SupplierLedgerModel>, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/reports/supplier-debts',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! List) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed supplier debts response payload)',
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

final customerDebtsReportProvider =
    FutureProvider.family<List<CustomerLedgerModel>, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      final pusher = ref.watch(pusherServiceProvider);

      void onCustomerDebtsEvent(Map<String, dynamic> eventData) {
        debugPrint("Realtime update for customerDebtsReportProvider: $eventData");
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-customers', onCustomerDebtsEvent);
      pusher.subscribeToChannel('private-orders', onCustomerDebtsEvent);
      pusher.subscribeToChannel('private-delivery-trips', onCustomerDebtsEvent);

      ref.onDispose(() {
        pusher.unsubscribeFromChannel('private-customers', onCustomerDebtsEvent);
        pusher.unsubscribeFromChannel('private-orders', onCustomerDebtsEvent);
        pusher.unsubscribeFromChannel('private-delivery-trips', onCustomerDebtsEvent);
      });

      try {
        final response = await api.client.get(
          '/reports/customer-debts',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! List) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed customer debts response payload)',
            );
          }
          final List data = resData['data'] as List;
          return data
              .map((json) => CustomerLedgerModel.fromJson(json))
              .toList();
        }
        throw Exception(
          'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
        );
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

final paymentsHistoryReportProvider =
    FutureProvider.family<List<PaymentHistoryModel>, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      final pusher = ref.watch(pusherServiceProvider);

      void onPaymentsEvent(Map<String, dynamic> eventData) {
        debugPrint("Realtime update for paymentsHistoryReportProvider: $eventData");
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-customers', onPaymentsEvent);
      pusher.subscribeToChannel('private-delivery-trips', onPaymentsEvent);

      ref.onDispose(() {
        pusher.unsubscribeFromChannel('private-customers', onPaymentsEvent);
        pusher.unsubscribeFromChannel('private-delivery-trips', onPaymentsEvent);
      });

      try {
        final response = await api.client.get(
          '/reports/payments-history',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! List) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed payments history response payload)',
            );
          }
          final List data = resData['data'] as List;
          return data
              .map((json) => PaymentHistoryModel.fromJson(json))
              .toList();
        }
        throw Exception(
          'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
        );
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

// Sales Report Provider
final salesReportProvider =
    FutureProvider.family<SalesReportData, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      final pusher = ref.watch(pusherServiceProvider);

      void onSalesReportEvent(Map<String, dynamic> eventData) {
        debugPrint("Realtime update for salesReportProvider: $eventData");
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-orders', onSalesReportEvent);
      pusher.subscribeToChannel('private-delivery-trips', onSalesReportEvent);

      ref.onDispose(() {
        pusher.unsubscribeFromChannel('private-orders', onSalesReportEvent);
        pusher.unsubscribeFromChannel('private-delivery-trips', onSalesReportEvent);
      });

      try {
        final response = await api.client.get(
          '/reports/sales',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! Map) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed sales report payload)',
            );
          }
          return SalesReportData.fromJson(Map<String, dynamic>.from(resData['data']));
        }
        throw Exception('نەتوانرا داتای ڕاپۆرتی فرۆشتن بهێنرێت');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

// Profit Report Provider
final profitReportProvider =
    FutureProvider.family<ProfitReportData, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/reports/profit',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! Map) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed profit report payload)',
            );
          }
          return ProfitReportData.fromJson(Map<String, dynamic>.from(resData['data']));
        }
        throw Exception('نەتوانرا داتای ڕاپۆرتی قازانج بهێنرێت');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

// Sales by Salesman Provider
final salesBySalesmanReportProvider =
    FutureProvider.family<SalesBySalesmanReportData, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/reports/sales-by-salesman',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! Map) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed sales by salesman report payload)',
            );
          }
          return SalesBySalesmanReportData.fromJson(
            Map<String, dynamic>.from(resData['data']),
          );
        }
        throw Exception('نەتوانرا داتای فرۆشتنی مەندوبەکان بهێنرێت');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

// Low Stock Alert Provider
final lowStockReportProvider =
    FutureProvider.family<LowStockReportData, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/reports/low-stock',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! Map) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed low stock report payload)',
            );
          }
          return LowStockReportData.fromJson(Map<String, dynamic>.from(resData['data']));
        }
        throw Exception('نەتوانرا داتای کاڵا کەمبووەکان بهێنرێت');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

// Stock Movements Provider
final stockMovementsReportProvider =
    FutureProvider.family<StockMovementsReportData, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/reports/stock-movements',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! Map) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed stock movements report payload)',
            );
          }
          return StockMovementsReportData.fromJson(Map<String, dynamic>.from(resData['data']));
        }
        throw Exception('نەتوانرا داتای جوڵەی ستۆک بهێنرێت');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

// Stock Transfers Provider
final stockTransfersReportProvider =
    FutureProvider.family<StockTransfersReportData, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/reports/stock-transfers',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! Map) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed stock transfers report payload)',
            );
          }
          return StockTransfersReportData.fromJson(Map<String, dynamic>.from(resData['data']));
        }
        throw Exception('نەتوانرا داتای گواستنەوەکان بهێنرێت');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });
