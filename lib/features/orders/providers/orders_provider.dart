import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/order_model.dart';

final ordersListProvider = FutureProvider<List<OrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/orders');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => OrderModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final customerOrdersProvider = FutureProvider.family<List<OrderModel>, int>((ref, customerId) async {
  final orders = await ref.watch(ordersListProvider.future);
  return orders.where((order) => order.customerId == customerId).toList();
});
