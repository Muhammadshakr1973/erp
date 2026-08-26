import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/customer.dart';

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/customers');
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

final singleCustomerProvider = FutureProvider.family<Customer, int>((ref, id) async {
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
  return CustomerActions(api, ref);
});

class CustomerActions {
  final ApiClient api;
  final Ref ref;

  CustomerActions(this.api, this.ref);

  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? phone2,
    String? address,
    int? routeId,
    String? priceType,
    int? initialDebt,
  }) async {
    try {
      final response = await api.client.post('/customers', data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (phone2 != null && phone2.isNotEmpty) 'phone2': phone2,
        if (address != null && address.isNotEmpty) 'address': address,
        if (routeId != null) 'route_id': routeId,
        if (priceType != null) 'price_type': priceType,
        if (initialDebt != null && initialDebt > 0) 'initial_debt': initialDebt,
      });
      ref.invalidate(customerListProvider);
      return Customer.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<Customer> updateCustomer(
    int id, {
    required String name,
    String? phone,
    String? phone2,
    String? address,
    int? routeId,
    String? priceType,
    bool? isActive,
  }) async {
    try {
      final response = await api.client.put('/customers/$id', data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (phone2 != null && phone2.isNotEmpty) 'phone2': phone2,
        if (address != null && address.isNotEmpty) 'address': address,
        if (routeId != null) 'route_id': routeId,
        if (priceType != null) 'price_type': priceType,
        if (isActive != null) 'is_active': isActive,
      });
      ref.invalidate(customerListProvider);
      ref.invalidate(singleCustomerProvider(id));
      return Customer.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
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

