import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/customer.dart';

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/customers');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
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
