import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../models/customer.dart';

class CustomerFilters {
  final int page;
  final int? routeId;
  final bool onlyDebtors;
  final String searchQuery;

  const CustomerFilters({
    this.page = 1,
    this.routeId,
    this.onlyDebtors = false,
    this.searchQuery = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'page': page,
      if (routeId != null) 'route_id': routeId,
      if (onlyDebtors) 'has_debt': 'true',
      if (searchQuery.isNotEmpty) 'search': searchQuery,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerFilters &&
        other.page == page &&
        other.routeId == routeId &&
        other.onlyDebtors == onlyDebtors &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode => Object.hash(page, routeId, onlyDebtors, searchQuery);
}

final filteredCustomerListProvider =
    FutureProvider.family<List<Customer>, CustomerFilters>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/customers',
          queryParameters: filters.toMap(),
        );
        if (response.statusCode == 200) {
          var rawData = response.data['data'];
          List data = [];
          if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
            data = rawData['data'] ?? [];
          } else if (rawData is List) {
            data = rawData;
          }
          return data.map((json) => Customer.fromJson(json)).toList();
        }
        return [];
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  return ref.watch(
    filteredCustomerListProvider(const CustomerFilters()).future,
  );
});

final singleCustomerProvider = FutureProvider.family<Customer, int>((
  ref,
  id,
) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/customers/$id');
    if (response.statusCode == 200) {
      return Customer.fromJson(response.data['data']);
    }
    throw Exception('Failed to load customer');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final customerActionsProvider = Provider<CustomerActions>((ref) {
  final api = ref.watch(apiClientProvider);
  final syncService = ref.watch(syncServiceProvider);
  return CustomerActions(api, syncService, ref);
});

class CustomerActions {
  final ApiClient api;
  final SyncService syncService;
  final Ref ref;

  CustomerActions(this.api, this.syncService, this.ref);

  Future<void> addCustomer({
    required String name,
    String? phone,
    String? phone2,
    String? address,
    String? imageUrl,
    int? routeId,
    String? priceType,
    int? initialDebt,
    double? latitude,
    double? longitude,
  }) async {
    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';

    await syncService.enqueueOperation(
      entityId: localId,
      operationType: 'CREATE_CUSTOMER',
      payload: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (phone2 != null && phone2.isNotEmpty) 'phone2': phone2,
        if (address != null && address.isNotEmpty) 'address': address,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (routeId != null) 'route_id': routeId,
        if (priceType != null) 'price_type': priceType,
        if (initialDebt != null && initialDebt > 0)
          'initial_debt': initialDebt,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    ref.invalidate(customerListProvider);
  }

  Future<void> updateCustomer(
    int id, {
    required String name,
    String? phone,
    String? phone2,
    String? address,
    String? imageUrl,
    int? routeId,
    String? priceType,
    bool? isActive,
    double? latitude,
    double? longitude,
  }) async {
    await syncService.enqueueOperation(
      entityId: id.toString(),
      operationType: 'UPDATE_CUSTOMER',
      payload: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (phone2 != null && phone2.isNotEmpty) 'phone2': phone2,
        if (address != null && address.isNotEmpty) 'address': address,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (routeId != null) 'route_id': routeId,
        if (priceType != null) 'price_type': priceType,
        if (isActive != null) 'is_active': isActive,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    ref.invalidate(customerListProvider);
    ref.invalidate(singleCustomerProvider(id));
  }

  Future<void> deleteCustomer(int id) async {
    try {
      await api.client.delete('/customers/$id');
      ref.invalidate(customerListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
