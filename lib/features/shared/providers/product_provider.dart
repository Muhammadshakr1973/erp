import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/product.dart';

final productListProvider = FutureProvider<List<Product>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    // Assuming you have a /products endpoint in your Laravel API, if not we will adjust later.
    // If it's not public yet, we'll ensure it exists.
    final response = await api.client.get('/products');
    if (response.statusCode == 200) {
      final List data =
          response.data['data'] ??
          response.data; // Handles paginated or direct array
      return data.map((json) => Product.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});
