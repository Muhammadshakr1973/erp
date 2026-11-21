import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../../core/models/paginated_response.dart';
import '../../admin/views/providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../salesman/providers/salesman_dashboard_provider.dart';
import '../models/customer.dart';
import '../models/customer_ledger_model.dart';
import '../models/customer_reconciliation_model.dart';

class CustomerFilters {
  final int page;
  final int? routeId;
  final bool onlyDebtors;
  final String searchQuery;
  final int? perPage;

  const CustomerFilters({
    this.page = 1,
    this.routeId,
    this.onlyDebtors = false,
    this.searchQuery = '',
    this.perPage,
  });

  Map<String, dynamic> toMap() {
    return {
      'page': page,
      if (routeId != null) 'route_id': routeId,
      if (onlyDebtors) 'has_debt': 'true',
      if (searchQuery.isNotEmpty) 'search': searchQuery,
      if (perPage != null) 'per_page': perPage,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerFilters &&
        other.page == page &&
        other.routeId == routeId &&
        other.onlyDebtors == onlyDebtors &&
        other.searchQuery == searchQuery &&
        other.perPage == perPage;
  }

  @override
  int get hashCode => Object.hash(page, routeId, onlyDebtors, searchQuery, perPage);
}

class FilteredCustomerListNotifier
    extends FamilyAsyncNotifier<PaginatedResponse<Customer>, CustomerFilters> {
  final Set<int> _fetchingCustomerIds = {};
  bool _isRefreshingAll = false;

  @override
  FutureOr<PaginatedResponse<Customer>> build(CustomerFilters arg) async {
    final user = ref.watch(authProvider.select((state) => state.user));
    if (user == null) {
      return PaginatedResponse<Customer>(
        data: const [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
        perPage: arg.perPage ?? 15,
      );
    }

    final role = user.role.toLowerCase();
    // Warehouse and driver roles do not have permission to view customer directory
    if (role != 'admin' && role != 'owner' && role != 'salesman') {
      return PaginatedResponse<Customer>(
        data: const [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
        perPage: arg.perPage ?? 15,
      );
    }

    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onCustomerEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received on private-customers channel: $eventData",
      );
      _handleCustomerEvent(eventData);
    }

    pusher.subscribeToChannel('private-customers', onCustomerEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-customers', onCustomerEvent);
    });

    return _fetchCustomersPage(api, arg);
  }

  Future<PaginatedResponse<Customer>> _fetchCustomersPage(
    ApiClient api,
    CustomerFilters filters,
  ) async {
    try {
      final response = await api.client.get(
        '/customers',
        queryParameters: filters.toMap(),
      );
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed customer response payload)',
          );
        }
        final rawData = resData['data'];
        if (rawData is Map) {
          return PaginatedResponse<Customer>.fromJson(
            Map<String, dynamic>.from(rawData),
            (json) => Customer.fromJson(json),
          );
        } else if (rawData is List) {
          return PaginatedResponse<Customer>(
            data: rawData
                .map((json) => Customer.fromJson(Map<String, dynamic>.from(json as Map)))
                .toList(),
            currentPage: 1,
            lastPage: 1,
            total: rawData.length,
            perPage: rawData.length,
          );
        } else {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed customer list structure)',
          );
        }
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  void _handleCustomerEvent(Map<String, dynamic> eventData) {
    final eventType = eventData['event_type']?.toString();
    final customerId = int.tryParse(
      (eventData['customer_id'] ?? eventData['id'])?.toString() ?? '',
    );

    if (customerId == null) {
      unawaited(refreshSilently());
      return;
    }

    if (eventType == 'delete') {
      removeCustomerLocally(customerId);
      return;
    }

    unawaited(refreshSingleCustomer(customerId));
  }

  bool _matchesFilters(Customer customer) {
    if (arg.routeId != null && customer.routeId != arg.routeId) {
      return false;
    }
    if (arg.onlyDebtors && customer.balance <= 0) {
      return false;
    }
    if (arg.searchQuery.trim().isNotEmpty) {
      final q = arg.searchQuery.trim().toLowerCase();
      final nameMatch = customer.name.toLowerCase().contains(q);
      final phoneMatch = (customer.phone ?? '').toLowerCase().contains(q);
      final custNameMatch =
          (customer.customerName ?? '').toLowerCase().contains(q);
      if (!nameMatch && !phoneMatch && !custNameMatch) {
        return false;
      }
    }
    return true;
  }

  bool _sameCustomerData(Customer a, Customer b) {
    if (a.id != b.id ||
        a.name != b.name ||
        a.phone != b.phone ||
        a.customerName != b.customerName ||
        a.address != b.address ||
        a.imageUrl != b.imageUrl ||
        a.balance != b.balance ||
        a.creditLimit != b.creditLimit ||
        a.salesmanId != b.salesmanId ||
        a.routeId != b.routeId ||
        a.priceType != b.priceType ||
        a.permanentDiscount != b.permanentDiscount ||
        a.isActive != b.isActive ||
        a.latitude != b.latitude ||
        a.longitude != b.longitude ||
        a.visitOrder != b.visitOrder ||
        a.canLogin != b.canLogin ||
        a.loginCode != b.loginCode ||
        a.route?.id != b.route?.id ||
        a.route?.name != b.route?.name) {
      return false;
    }
    if (a.allowedCategoryIds.length != b.allowedCategoryIds.length) {
      return false;
    }
    for (int i = 0; i < a.allowedCategoryIds.length; i++) {
      if (a.allowedCategoryIds[i] != b.allowedCategoryIds[i]) return false;
    }
    if (a.specialPrices.length != b.specialPrices.length) {
      return false;
    }
    for (final entry in a.specialPrices.entries) {
      if (b.specialPrices[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<void> refreshSilently() async {
    if (_isRefreshingAll) return;
    _isRefreshingAll = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchCustomersPage(api, arg);
      final current = state.valueOrNull;
      if (current != null &&
          current.data.length == fresh.data.length &&
          current.total == fresh.total) {
        bool allSame = true;
        for (int i = 0; i < fresh.data.length; i++) {
          if (!_sameCustomerData(current.data[i], fresh.data[i])) {
            allSame = false;
            break;
          }
        }
        if (allSame) return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current state on transient failure
    } finally {
      _isRefreshingAll = false;
    }
  }

  Future<void> refreshSingleCustomer(int customerId) async {
    if (customerId <= 0) return;
    if (_fetchingCustomerIds.contains(customerId)) return;
    _fetchingCustomerIds.add(customerId);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.client.get('/customers/$customerId');
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['data'] is Map) {
        final freshCustomer = Customer.fromJson(
          Map<String, dynamic>.from(response.data['data']),
        );
        upsertCustomerLocally(freshCustomer);
      }
    } catch (_) {
      // Ignore 403/404/transient network errors cleanly for background updates
    } finally {
      _fetchingCustomerIds.remove(customerId);
    }
  }

  void upsertCustomerLocally(Customer customer) {
    final currentPage = state.valueOrNull;
    if (currentPage == null) return;

    final currentList = currentPage.data;
    final index = currentList.indexWhere((c) => c.id == customer.id);

    if (!_matchesFilters(customer)) {
      if (index != -1) {
        final updatedList = List<Customer>.from(currentList)..removeAt(index);
        state = AsyncData(
          PaginatedResponse<Customer>(
            data: updatedList,
            currentPage: currentPage.currentPage,
            lastPage: currentPage.lastPage,
            total: (currentPage.total - 1).clamp(0, 1 << 30),
            perPage: currentPage.perPage,
          ),
        );
      }
      return;
    }

    if (index != -1) {
      if (_sameCustomerData(currentList[index], customer)) return;
      final updatedList = List<Customer>.from(currentList);
      updatedList[index] = customer;
      state = AsyncData(
        PaginatedResponse<Customer>(
          data: updatedList,
          currentPage: currentPage.currentPage,
          lastPage: currentPage.lastPage,
          total: currentPage.total,
          perPage: currentPage.perPage,
        ),
      );
    } else if (arg.page == 1) {
      final updatedList = [customer, ...currentList];
      state = AsyncData(
        PaginatedResponse<Customer>(
          data: updatedList,
          currentPage: currentPage.currentPage,
          lastPage: currentPage.lastPage,
          total: currentPage.total + 1,
          perPage: currentPage.perPage,
        ),
      );
    }
  }

  void removeCustomerLocally(int id) {
    final currentPage = state.valueOrNull;
    if (currentPage == null) return;
    final hadCustomer = currentPage.data.any((c) => c.id == id);
    if (!hadCustomer) return;

    final updatedList = currentPage.data.where((c) => c.id != id).toList();
    state = AsyncData(
      PaginatedResponse<Customer>(
        data: updatedList,
        currentPage: currentPage.currentPage,
        lastPage: currentPage.lastPage,
        total: (currentPage.total - 1).clamp(0, 1 << 30),
        perPage: currentPage.perPage,
      ),
    );
  }
}

final filteredCustomerListProvider = AsyncNotifierProvider.family<
    FilteredCustomerListNotifier, PaginatedResponse<Customer>, CustomerFilters>(
  FilteredCustomerListNotifier.new,
);

const CustomerFilters defaultCustomerDirectoryFilters =
    CustomerFilters(perPage: 500);

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final user = ref.watch(authProvider.select((state) => state.user));
  final role = user?.role.toLowerCase();
  if (user == null ||
      (role != 'admin' && role != 'owner' && role != 'salesman')) {
    return const [];
  }
  final paginated = await ref.watch(
    filteredCustomerListProvider(defaultCustomerDirectoryFilters).future,
  );
  return paginated.data;
});

class SingleCustomerNotifier extends FamilyAsyncNotifier<Customer, int> {
  bool _isRefreshing = false;

  @override
  FutureOr<Customer> build(int arg) async {
    final user = ref.watch(authProvider.select((state) => state.user));
    if (user == null) {
      throw Exception('بەکارهێنەر چۆتە دەرەوە (User is logged out)');
    }
    final role = user.role.toLowerCase();
    final isOwnPortalCustomer = role == 'customer' && user.customer?.id == arg;
    if (role != 'admin' &&
        role != 'owner' &&
        role != 'salesman' &&
        !isOwnPortalCustomer) {
      throw Exception('بەکارهێنەر مۆڵەتی بینینی زانیارییەکانی ئەم کڕیارەی نییە');
    }

    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSingleCustomerEvent(Map<String, dynamic> eventData) {
      final eventCustomerId = int.tryParse(
        (eventData['customer_id'] ?? eventData['id'])?.toString() ?? '',
      );
      if (eventCustomerId != null && eventCustomerId != arg) {
        return;
      }
      debugPrint(
        "Realtime update received on private-customers channel for singleCustomer ($arg): $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-customers', onSingleCustomerEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-customers', onSingleCustomerEvent);
    });

    return _fetchSingleCustomer(api, arg);
  }

  Future<Customer> _fetchSingleCustomer(ApiClient api, int id) async {
    try {
      final response = await api.client.get('/customers/$id');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed customer detail payload)',
          );
        }
        return Customer.fromJson(Map<String, dynamic>.from(resData['data']));
      }
      throw Exception('Failed to load customer');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchSingleCustomer(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Keep current state on transient errors
    } finally {
      _isRefreshing = false;
    }
  }

  void setCustomerLocally(Customer customer) {
    if (customer.id == arg) {
      state = AsyncData(customer);
    }
  }
}

final singleCustomerProvider =
    AsyncNotifierProvider.family<SingleCustomerNotifier, Customer, int>(
  SingleCustomerNotifier.new,
);

final customerReconciliationProvider =
    FutureProvider.family<CustomerReconciliationModel, int>((ref, id) async {
      final user = ref.watch(authProvider.select((state) => state.user));
      if (user == null) {
        throw Exception('بەکارهێنەر چۆتە دەرەوە (User is logged out)');
      }
      final role = user.role.toLowerCase();
      if (role != 'admin' && role != 'owner') {
        throw Exception('تەنها بەڕێوەبەر مۆڵەتی ئەم بەشەی هەیە');
      }
      final api = ref.watch(apiClientProvider);
      final pusher = ref.watch(pusherServiceProvider);

      void onReconcileEvent(Map<String, dynamic> eventData) {
        final eventCustId = eventData['customer_id']?.toString();
        if (eventCustId == null || eventCustId == id.toString()) {
          ref.invalidateSelf();
        }
      }

      pusher.subscribeToChannel('private-customers', onReconcileEvent);
      pusher.subscribeToChannel('private-orders', onReconcileEvent);
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromChannel('private-customers', onReconcileEvent);
        pusher.unsubscribeFromChannel('private-orders', onReconcileEvent);
      });

      try {
        final response = await api.client.get('/customers/$id/reconcile');
        if (response.statusCode == 200) {
          final resData = response.data;
          if (resData is! Map || resData['data'] is! Map) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed reconciliation response)',
            );
          }
          return CustomerReconciliationModel.fromJson(
            Map<String, dynamic>.from(resData['data']),
          );
        }
        throw Exception('Failed to fetch reconciliation report');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

class CustomerLedgerNotifier
    extends FamilyAsyncNotifier<List<CustomerLedgerModel>, Map<String, dynamic>> {
  bool _isRefreshing = false;

  @override
  FutureOr<List<CustomerLedgerModel>> build(Map<String, dynamic> arg) async {
    final user = ref.watch(authProvider.select((state) => state.user));
    if (user == null) return const [];
    final role = user.role.toLowerCase();
    if (role != 'admin' && role != 'owner' && role != 'salesman') {
      return const [];
    }

    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);
    final customerId = arg['customer_id'];

    void onLedgerEvent(Map<String, dynamic> eventData) {
      final eventCustomerId = eventData['customer_id']?.toString();
      if (eventCustomerId != null &&
          customerId != null &&
          eventCustomerId != customerId.toString()) {
        return;
      }
      debugPrint(
        "Realtime update received for customer ledger ($customerId): $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-customers', onLedgerEvent);
    pusher.subscribeToChannel('private-orders', onLedgerEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-customers', onLedgerEvent);
      pusher.unsubscribeFromChannel('private-orders', onLedgerEvent);
    });

    return _fetchLedger(api, arg);
  }

  Future<List<CustomerLedgerModel>> _fetchLedger(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
    final customerId = filters['customer_id'];
    try {
      final response = await api.client.get(
        '/customers/$customerId/ledger',
        queryParameters: filters,
      );
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed customer ledger response payload)',
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
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchLedger(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current ledger rows on transient error
    } finally {
      _isRefreshing = false;
    }
  }
}

final customerLedgerProvider = AsyncNotifierProvider.family<
    CustomerLedgerNotifier, List<CustomerLedgerModel>, Map<String, dynamic>>(
  CustomerLedgerNotifier.new,
);

final customerActionsProvider = Provider<CustomerActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return CustomerActions(api, ref);
});

class CustomerActions {
  final ApiClient api;
  final Ref ref;

  CustomerActions(this.api, this.ref);

  Future<void> refreshSingleCustomerEverywhere(int customerId) async {
    if (customerId <= 0) return;
    await Future.wait([
      ref
          .read(
            filteredCustomerListProvider(defaultCustomerDirectoryFilters)
                .notifier,
          )
          .refreshSingleCustomer(customerId),
      ref.read(singleCustomerProvider(customerId).notifier).refreshSilently(),
    ]);
  }

  void _syncCustomerUpsertLocally(Customer customer) {
    ref
        .read(
          filteredCustomerListProvider(defaultCustomerDirectoryFilters)
              .notifier,
        )
        .upsertCustomerLocally(customer);
    ref
        .read(singleCustomerProvider(customer.id).notifier)
        .setCustomerLocally(customer);
  }

  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? customerName,
    String? address,
    String? imageUrl,
    int? routeId,
    String? priceType,
    int? initialDebt,
    double? latitude,
    double? longitude,
    bool? canLogin,
    String? loginCode,
    List<int>? allowedCategoryIds,
  }) async {
    final payload = {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
      if (address != null && address.isNotEmpty) 'address': address,
      if (imageUrl != null && imageUrl.trim().isNotEmpty) 'image_url': imageUrl.trim(),
      if (routeId != null) 'route_id': routeId,
      if (priceType != null) 'price_type': priceType,
      if (initialDebt != null && initialDebt > 0) 'initial_debt': initialDebt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (canLogin != null) 'can_login': canLogin,
      if (loginCode != null && loginCode.trim().isNotEmpty) 'login_code': loginCode.trim(),
      if (allowedCategoryIds != null) 'allowed_category_ids': allowedCategoryIds,
    };

    try {
      final response = await api.client.post('/customers', data: payload);
      if (response.statusCode != null && response.statusCode! >= 400) {
        throw Exception(api.extractErrorMessage(response.data, defaultMsg: 'کێشەیەک لە زانیارییەکاندا هەیە'));
      }
      final resData = response.data;
      if (resData is Map && resData['data'] is Map) {
        final createdCustomer = Customer.fromJson(Map<String, dynamic>.from(resData['data']));
        _syncCustomerUpsertLocally(createdCustomer);
        unawaited(ref.read(salesmanDashboardProvider.notifier).refreshSilently());
        return createdCustomer;
      }
      throw FormatException('داتای دروستکراوی کڕیار نادروستە');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<Customer> updateCustomer(
    int id, {
    required String name,
    String? phone,
    String? customerName,
    String? address,
    String? imageUrl,
    int? routeId,
    String? priceType,
    bool? isActive,
    double? latitude,
    double? longitude,
    bool? canLogin,
    String? loginCode,
    List<int>? allowedCategoryIds,
  }) async {
    final payload = {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
      if (address != null && address.isNotEmpty) 'address': address,
      'image_url': (imageUrl != null && imageUrl.trim().isNotEmpty) ? imageUrl.trim() : null,
      if (routeId != null) 'route_id': routeId,
      if (priceType != null) 'price_type': priceType,
      if (isActive != null) 'is_active': isActive,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (canLogin != null) 'can_login': canLogin,
      if (loginCode != null && loginCode.trim().isNotEmpty) 'login_code': loginCode.trim(),
      if (allowedCategoryIds != null) 'allowed_category_ids': allowedCategoryIds,
    };

    try {
      final response = await api.client.put('/customers/$id', data: payload);
      if (response.statusCode != null && response.statusCode! >= 400) {
        throw Exception(api.extractErrorMessage(response.data, defaultMsg: 'کێشەیەک لە زانیارییەکاندا هەیە'));
      }
      final resData = response.data;
      if (resData is Map && resData['data'] is Map) {
        final updatedCustomer = Customer.fromJson(Map<String, dynamic>.from(resData['data']));
        _syncCustomerUpsertLocally(updatedCustomer);
        unawaited(ref.read(salesmanDashboardProvider.notifier).refreshSilently());
        return updatedCustomer;
      }
      throw FormatException('داتای نوێکراوەی کڕیار نادروستە');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteCustomer(int id) async {
    try {
      await api.client.delete('/customers/$id');
      ref
          .read(
            filteredCustomerListProvider(defaultCustomerDirectoryFilters)
                .notifier,
          )
          .removeCustomerLocally(id);
      unawaited(ref.read(salesmanDashboardProvider.notifier).refreshSilently());
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<CustomerReconciliationModel> fixCustomerBalance(int id) async {
    try {
      final response = await api.client.post(
        '/customers/$id/reconcile',
        data: {'fix': true},
      );
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map) {
          throw const FormatException('Malformed response from server');
        }

        final result = CustomerReconciliationModel.fromJson(
          Map<String, dynamic>.from(resData['data']),
        );

        await refreshSingleCustomerEverywhere(id);
        ref.invalidate(customerReconciliationProvider(id));
        unawaited(ref.read(salesmanDashboardProvider.notifier).refreshSilently());

        return result;
      } else {
        throw Exception('Failed to fix customer balance');
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<Map<int, double>> fetchSpecialPrices(int customerId) async {
    try {
      final response = await api.client.get('/customers/$customerId/special-prices');
      if (response.statusCode == 200) {
        final resData = response.data;
        final map = <int, double>{};
        if (resData is Map && resData['data'] is List) {
          for (final item in resData['data']) {
            final productId = item['product_id'] as int?;
            final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            if (productId != null) {
              map[productId] = price;
            }
          }
        }
        return map;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<void> setSpecialPrice(int customerId, int productId, double price) async {
    try {
      await api.client.post(
        '/customers/$customerId/special-prices',
        data: {
          'product_id': productId,
          'price': price.toInt(),
        },
      );
      unawaited(refreshSingleCustomerEverywhere(customerId));
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> createPayment({
    required int customerId,
    required int amount,
    int? salesOrderId,
    String? paymentMethod = 'CASH',
    String? notes,
  }) async {
    final payload = {
      'customer_id': customerId,
      'amount': amount,
      if (salesOrderId != null) 'sales_order_id': salesOrderId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    try {
      final response = await api.client.post('/payments', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await refreshSingleCustomerEverywhere(customerId);
        unawaited(ref.read(salesmanDashboardProvider.notifier).refreshSilently());
        ref.invalidate(dashboardProvider);
        return;
      }
      throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteSpecialPrice(int customerId, int productId) async {
    try {
      await api.client.delete('/customers/$customerId/special-prices/$productId');
      unawaited(refreshSingleCustomerEverywhere(customerId));
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<Map<String, dynamic>?> fetchLastProductPrice(
    int customerId,
    int productId, {
    int? excludeOrderId,
  }) async {
    try {
      final query = excludeOrderId != null ? '?exclude_order_id=$excludeOrderId' : '';
      final response = await api.client.get('/customers/$customerId/last-product-price/$productId$query');
      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['found'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

