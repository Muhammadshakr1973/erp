import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/product_model.dart';

final productsListProvider = FutureProvider<List<ProductModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/products');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => ProductModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});
