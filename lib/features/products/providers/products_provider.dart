import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_model.dart';

final productsListProvider = FutureProvider<List<ProductModel>>((ref) async {
  ref.watch(authProvider.select((state) => state.user?.id));
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  // Subscribe to real-time product/stock updates
  pusher.subscribeToChannel('private-products', (eventData) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    pusher.unsubscribeFromChannel('private-products');
  });

  try {
    final response = await api.client.get('/products');
    if (response.statusCode == 200) {
      final resData = response.data;
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed products response payload)',
        );
      }
      final List data = resData['data'] as List;
      return data.map((json) => ProductModel.fromJson(json)).toList();
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

class ProductSearchNotifier extends StateNotifier<String> {
  ProductSearchNotifier() : super('');

  void search(String query) {
    state = query;
  }
}

final productSearchProvider =
    StateNotifierProvider<ProductSearchNotifier, String>((ref) {
      return ProductSearchNotifier();
    });

final selectedCategoryFilterProvider = StateProvider<int?>((ref) => null);

final filteredProductsProvider = Provider<AsyncValue<List<ProductModel>>>((
  ref,
) {
  final productsAsync = ref.watch(productsListProvider);
  final searchQuery = ref.watch(productSearchProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryFilterProvider);

  return productsAsync.whenData((products) {
    return products.where((p) {
      final matchesQuery =
          searchQuery.isEmpty ||
          p.name.toLowerCase().contains(searchQuery) ||
          p.barcode.toLowerCase().contains(searchQuery) ||
          (p.sku != null && p.sku!.toLowerCase().contains(searchQuery));

      final matchesCategory =
          selectedCategory == null || p.categoryId == selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
  });
});

final productActionsProvider = Provider<ProductActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return ProductActions(api, ref);
});

class ProductActions {
  final ApiClient api;
  final Ref ref;

  ProductActions(this.api, this.ref);

  Future<void> addProduct(Map<String, dynamic> data) async {
    try {
      await api.client.post('/products', data: data);
      ref.invalidate(productsListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      await api.client.put('/products/$id', data: data);
      ref.invalidate(productsListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await api.client.delete('/products/$id');
      ref.invalidate(productsListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
