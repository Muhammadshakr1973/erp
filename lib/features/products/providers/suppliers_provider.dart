import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/supplier_model.dart';

final suppliersListProvider = FutureProvider<List<SupplierModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/suppliers');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => SupplierModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    // If the endpoint doesn't exist yet, return empty list instead of failing
    return [];
  }
});
