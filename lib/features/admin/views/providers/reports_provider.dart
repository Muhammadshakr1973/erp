import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../products/models/supplier_ledger_model.dart';
import '../../../shared/models/customer_ledger_model.dart';
import '../../../shared/models/payment_history_model.dart';
import '../../../shared/models/report_models.dart';

class SupplierDebtsReportNotifier
    extends FamilyAsyncNotifier<List<SupplierLedgerModel>, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<SupplierLedgerModel>> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSupplierDebtsEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update for supplierDebtsReportProvider: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-suppliers', onSupplierDebtsEvent);
    pusher.subscribeToChannel('private-purchases', onSupplierDebtsEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-suppliers', onSupplierDebtsEvent);
      pusher.unsubscribeFromChannel('private-purchases', onSupplierDebtsEvent);
    });

    return _fetch(api, arg);
  }

  Future<List<SupplierLedgerModel>> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final supplierDebtsReportProvider = AsyncNotifierProvider.family<
    SupplierDebtsReportNotifier,
    List<SupplierLedgerModel>,
    Map<String, dynamic>>(SupplierDebtsReportNotifier.new);

class CustomerDebtsReportNotifier
    extends FamilyAsyncNotifier<List<CustomerLedgerModel>, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<CustomerLedgerModel>> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onCustomerDebtsEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update for customerDebtsReportProvider: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-customers', onCustomerDebtsEvent);
    pusher.subscribeToChannel('private-orders', onCustomerDebtsEvent);
    pusher.subscribeToChannel('private-delivery-trips', onCustomerDebtsEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-customers', onCustomerDebtsEvent);
      pusher.unsubscribeFromChannel('private-orders', onCustomerDebtsEvent);
      pusher.unsubscribeFromChannel(
        'private-delivery-trips',
        onCustomerDebtsEvent,
      );
    });

    return _fetch(api, arg);
  }

  Future<List<CustomerLedgerModel>> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final customerDebtsReportProvider = AsyncNotifierProvider.family<
    CustomerDebtsReportNotifier,
    List<CustomerLedgerModel>,
    Map<String, dynamic>>(CustomerDebtsReportNotifier.new);

class PaymentsHistoryReportNotifier
    extends FamilyAsyncNotifier<List<PaymentHistoryModel>, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<PaymentHistoryModel>> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onPaymentsEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update for paymentsHistoryReportProvider: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-customers', onPaymentsEvent);
    pusher.subscribeToChannel('private-delivery-trips', onPaymentsEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-customers', onPaymentsEvent);
      pusher.unsubscribeFromChannel('private-delivery-trips', onPaymentsEvent);
    });

    return _fetch(api, arg);
  }

  Future<List<PaymentHistoryModel>> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final paymentsHistoryReportProvider = AsyncNotifierProvider.family<
    PaymentsHistoryReportNotifier,
    List<PaymentHistoryModel>,
    Map<String, dynamic>>(PaymentsHistoryReportNotifier.new);

class SalesReportNotifier
    extends FamilyAsyncNotifier<SalesReportData, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<SalesReportData> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر لۆگئۆت بووە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSalesReportEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update for salesReportProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-orders', onSalesReportEvent);
    pusher.subscribeToChannel('private-delivery-trips', onSalesReportEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-orders', onSalesReportEvent);
      pusher.unsubscribeFromChannel(
        'private-delivery-trips',
        onSalesReportEvent,
      );
    });

    return _fetch(api, arg);
  }

  Future<SalesReportData> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
        return SalesReportData.fromJson(
          Map<String, dynamic>.from(resData['data']),
        );
      }
      throw Exception('نەتوانرا داتای ڕاپۆرتی فرۆشتن بهێنرێت');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final salesReportProvider = AsyncNotifierProvider.family<
    SalesReportNotifier, SalesReportData, Map<String, dynamic>>(
  SalesReportNotifier.new,
);

class ProfitReportNotifier
    extends FamilyAsyncNotifier<ProfitReportData, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<ProfitReportData> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر لۆگئۆت بووە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onProfitReportEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update for profitReportProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-orders', onProfitReportEvent);
    pusher.subscribeToChannel('private-delivery-trips', onProfitReportEvent);
    pusher.subscribeToChannel('private-products', onProfitReportEvent);
    pusher.subscribeToChannel('private-categories', onProfitReportEvent);
    pusher.subscribeToChannel('private-purchases', onProfitReportEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-orders', onProfitReportEvent);
      pusher.unsubscribeFromChannel(
        'private-delivery-trips',
        onProfitReportEvent,
      );
      pusher.unsubscribeFromChannel('private-products', onProfitReportEvent);
      pusher.unsubscribeFromChannel('private-categories', onProfitReportEvent);
      pusher.unsubscribeFromChannel('private-purchases', onProfitReportEvent);
    });

    return _fetch(api, arg);
  }

  Future<ProfitReportData> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
        return ProfitReportData.fromJson(
          Map<String, dynamic>.from(resData['data']),
        );
      }
      throw Exception('نەتوانرا داتای ڕاپۆرتی قازانج بهێنرێت');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final profitReportProvider = AsyncNotifierProvider.family<
    ProfitReportNotifier, ProfitReportData, Map<String, dynamic>>(
  ProfitReportNotifier.new,
);

class SalesBySalesmanReportNotifier
    extends FamilyAsyncNotifier<SalesBySalesmanReportData, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<SalesBySalesmanReportData> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر لۆگئۆت بووە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSalesBySalesmanEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update for salesBySalesmanReportProvider: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-orders', onSalesBySalesmanEvent);
    pusher.subscribeToChannel(
      'private-delivery-trips',
      onSalesBySalesmanEvent,
    );
    pusher.subscribeToChannel('private-customers', onSalesBySalesmanEvent);
    pusher.subscribeToChannel('private-commissions', onSalesBySalesmanEvent);
    pusher.subscribeToChannel('private-users', onSalesBySalesmanEvent);
    pusher.subscribeToChannel('private-routes', onSalesBySalesmanEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
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

    return _fetch(api, arg);
  }

  Future<SalesBySalesmanReportData> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final salesBySalesmanReportProvider = AsyncNotifierProvider.family<
    SalesBySalesmanReportNotifier,
    SalesBySalesmanReportData,
    Map<String, dynamic>>(SalesBySalesmanReportNotifier.new);

class LowStockReportNotifier
    extends FamilyAsyncNotifier<LowStockReportData, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<LowStockReportData> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر لۆگئۆت بووە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onLowStockReportEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update for lowStockReportProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-products', onLowStockReportEvent);
    pusher.subscribeToChannel('private-orders', onLowStockReportEvent);
    pusher.subscribeToChannel('private-categories', onLowStockReportEvent);
    pusher.subscribeToChannel('private-suppliers', onLowStockReportEvent);
    pusher.subscribeToChannel('private-purchases', onLowStockReportEvent);
    pusher.subscribeToChannel('private-warehouses', onLowStockReportEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-products', onLowStockReportEvent);
      pusher.unsubscribeFromChannel('private-orders', onLowStockReportEvent);
      pusher.unsubscribeFromChannel(
        'private-categories',
        onLowStockReportEvent,
      );
      pusher.unsubscribeFromChannel(
        'private-suppliers',
        onLowStockReportEvent,
      );
      pusher.unsubscribeFromChannel(
        'private-purchases',
        onLowStockReportEvent,
      );
      pusher.unsubscribeFromChannel(
        'private-warehouses',
        onLowStockReportEvent,
      );
    });

    return _fetch(api, arg);
  }

  Future<LowStockReportData> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
        return LowStockReportData.fromJson(
          Map<String, dynamic>.from(resData['data']),
        );
      }
      throw Exception('نەتوانرا داتای کاڵا کەمبووەکان بهێنرێت');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final lowStockReportProvider = AsyncNotifierProvider.family<
    LowStockReportNotifier, LowStockReportData, Map<String, dynamic>>(
  LowStockReportNotifier.new,
);

class StockTransfersReportNotifier
    extends FamilyAsyncNotifier<StockTransfersReportData, Map<String, dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<StockTransfersReportData> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر لۆگئۆت بووە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onStockTransfersReportEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update for stockTransfersReportProvider: $eventData",
      );
      unawaited(refreshSilently());
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
      unawaited(refreshSilently());
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

    return _fetch(api, arg);
  }

  Future<StockTransfersReportData> _fetch(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
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
        return StockTransfersReportData.fromJson(
          Map<String, dynamic>.from(resData['data']),
        );
      }
      throw Exception('نەتوانرا داتای گواستنەوەکان بهێنرێت');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetch(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current report on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final stockTransfersReportProvider = AsyncNotifierProvider.family<
    StockTransfersReportNotifier,
    StockTransfersReportData,
    Map<String, dynamic>>(StockTransfersReportNotifier.new);
