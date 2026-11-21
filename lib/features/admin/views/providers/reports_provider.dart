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
      final pusher = ref.watch(pusherServiceProvider);

      void onSupplierDebtsEvent(Map<String, dynamic> eventData) {
        debugPrint("Realtime update for supplierDebtsReportProvider: $eventData");
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-suppliers', onSupplierDebtsEvent);
      pusher.subscribeToChannel('private-purchases', onSupplierDebtsEvent);
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromChannel('private-suppliers', onSupplierDebtsEvent);
        pusher.unsubscribeFromChannel('private-purchases', onSupplierDebtsEvent);
      });

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
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
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
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
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
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
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
      final pusher = ref.watch(pusherServiceProvider);

      void onProfitReportEvent(Map<String, dynamic> eventData) {
        debugPrint("Realtime update for profitReportProvider: $eventData");
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-orders', onProfitReportEvent);
      pusher.subscribeToChannel('private-delivery-trips', onProfitReportEvent);
      pusher.subscribeToChannel('private-products', onProfitReportEvent);
      pusher.subscribeToChannel('private-categories', onProfitReportEvent);
      pusher.subscribeToChannel('private-purchases', onProfitReportEvent);
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromChannel('private-orders', onProfitReportEvent);
        pusher.unsubscribeFromChannel('private-delivery-trips', onProfitReportEvent);
        pusher.unsubscribeFromChannel('private-products', onProfitReportEvent);
        pusher.unsubscribeFromChannel('private-categories', onProfitReportEvent);
        pusher.unsubscribeFromChannel('private-purchases', onProfitReportEvent);
      });

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
      final pusher = ref.watch(pusherServiceProvider);

      void onSalesBySalesmanEvent(Map<String, dynamic> eventData) {
        debugPrint(
          "Realtime update for salesBySalesmanReportProvider: $eventData",
        );
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-orders', onSalesBySalesmanEvent);
      pusher.subscribeToChannel('private-delivery-trips', onSalesBySalesmanEvent);
      pusher.subscribeToChannel('private-customers', onSalesBySalesmanEvent);
      pusher.subscribeToChannel('private-commissions', onSalesBySalesmanEvent);
      pusher.subscribeToChannel('private-users', onSalesBySalesmanEvent);
      pusher.subscribeToChannel('private-routes', onSalesBySalesmanEvent);
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromChannel('private-orders', onSalesBySalesmanEvent);
        pusher.unsubscribeFromChannel(
          'private-delivery-trips',
          onSalesBySalesmanEvent,
        );
        pusher.unsubscribeFromChannel(
          'private-customers',
          onSalesBySalesmanEvent,
        );
        pusher.unsubscribeFromChannel(
          'private-commissions',
          onSalesBySalesmanEvent,
        );
        pusher.unsubscribeFromChannel('private-users', onSalesBySalesmanEvent);
        pusher.unsubscribeFromChannel('private-routes', onSalesBySalesmanEvent);
      });

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
      final pusher = ref.watch(pusherServiceProvider);

      void onLowStockReportEvent(Map<String, dynamic> eventData) {
        debugPrint("Realtime update for lowStockReportProvider: $eventData");
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-products', onLowStockReportEvent);
      pusher.subscribeToChannel('private-orders', onLowStockReportEvent);
      pusher.subscribeToChannel('private-categories', onLowStockReportEvent);
      pusher.subscribeToChannel('private-suppliers', onLowStockReportEvent);
      pusher.subscribeToChannel('private-purchases', onLowStockReportEvent);
      pusher.subscribeToChannel('private-warehouses', onLowStockReportEvent);
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromChannel('private-products', onLowStockReportEvent);
        pusher.unsubscribeFromChannel('private-orders', onLowStockReportEvent);
        pusher.unsubscribeFromChannel('private-categories', onLowStockReportEvent);
        pusher.unsubscribeFromChannel('private-suppliers', onLowStockReportEvent);
        pusher.unsubscribeFromChannel('private-purchases', onLowStockReportEvent);
        pusher.unsubscribeFromChannel('private-warehouses', onLowStockReportEvent);
      });

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

// Stock Transfers Provider
final stockTransfersReportProvider =
    FutureProvider.family<StockTransfersReportData, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      final pusher = ref.watch(pusherServiceProvider);

      void onStockTransfersReportEvent(Map<String, dynamic> eventData) {
        debugPrint(
          "Realtime update for stockTransfersReportProvider: $eventData",
        );
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel(
        'private-stock-transfers',
        onStockTransfersReportEvent,
      );
      pusher.subscribeToChannel(
        'private-warehouses',
        onStockTransfersReportEvent,
      );
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromChannel(
          'private-stock-transfers',
          onStockTransfersReportEvent,
        );
        pusher.unsubscribeFromChannel(
          'private-warehouses',
          onStockTransfersReportEvent,
        );
      });

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
