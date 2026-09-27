import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_model.dart';

class ProductsListNotifier
    extends StateNotifier<AsyncValue<List<ProductModel>>> {
  final ApiClient _api;
  final PusherService _pusher;
  final Ref _ref;

  ProductsListNotifier(this._api, this._pusher, this._ref)
      : super(const AsyncValue.loading()) {
    fetchProducts();
    _subscribeToPusher();
  }

  void _subscribeToPusher() {
    _pusher.subscribeToChannel('private-products', (eventData) {
      _handleRealtimeEvent(eventData);
    });
  }

  void _handleRealtimeEvent(dynamic eventData) {
    if (eventData == null) return;

    Map<String, dynamic> data;
    if (eventData is Map) {
      data = Map<String, dynamic>.from(eventData);
    } else if (eventData is String) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(eventData));
      } catch (_) {
        return;
      }
    } else {
      return;
    }

    final eventType = data['event_type']?.toString();
    final productId = data['product_id'] != null
        ? int.tryParse(data['product_id'].toString())
        : null;

    if (productId == null) {
      // Fallback only if no product id provided
      fetchProducts();
      return;
    }

    state.whenData((currentList) {
      if (eventType == 'delete') {
        state = AsyncValue.data(
          currentList.where((p) => p.id != productId).toList(),
        );
        return;
      }

      // 1. Granular patch if full or partial product is in payload
      if (data['product'] is Map) {
        final pMap = Map<String, dynamic>.from(data['product'] as Map);
        final index = currentList.indexWhere((p) => p.id == productId);
        if (index != -1) {
          final existing = currentList[index];
          final updated = existing.copyWith(
            costPrice: pMap['cost_price'] != null
                ? (double.tryParse(pMap['cost_price'].toString()) ??
                    existing.costPrice)
                : existing.costPrice,
            priceN1: pMap['price_n1'] != null
                ? (double.tryParse(pMap['price_n1'].toString()) ??
                    existing.priceN1)
                : existing.priceN1,
            priceN2: pMap['price_n2'] != null
                ? (double.tryParse(pMap['price_n2'].toString()) ??
                    existing.priceN2)
                : existing.priceN2,
            priceN3: pMap['price_n3'] != null
                ? (double.tryParse(pMap['price_n3'].toString()) ??
                    existing.priceN3)
                : existing.priceN3,
            stocks: pMap['stocks'] is List
                ? (pMap['stocks'] as List)
                : existing.stocks,
          );
          final updatedList = List<ProductModel>.from(currentList);
          updatedList[index] = updated;
          state = AsyncValue.data(updatedList);
          return;
        }
      }

      // 2. Granular stocks update
      if (data['stocks'] is List) {
        final index = currentList.indexWhere((p) => p.id == productId);
        if (index != -1) {
          final existing = currentList[index];
          final updatedList = List<ProductModel>.from(currentList);
          updatedList[index] =
              existing.copyWith(stocks: data['stocks'] as List);
          state = AsyncValue.data(updatedList);
          return;
        }
      }

      // 3. Granular price update
      if (data['price_n1'] != null || data['cost_price'] != null) {
        final index = currentList.indexWhere((p) => p.id == productId);
        if (index != -1) {
          final existing = currentList[index];
          final updatedList = List<ProductModel>.from(currentList);
          updatedList[index] = existing.copyWith(
            costPrice: data['cost_price'] != null
                ? (double.tryParse(data['cost_price'].toString()) ??
                    existing.costPrice)
                : existing.costPrice,
            priceN1: data['price_n1'] != null
                ? (double.tryParse(data['price_n1'].toString()) ??
                    existing.priceN1)
                : existing.priceN1,
            priceN2: data['price_n2'] != null
                ? (double.tryParse(data['price_n2'].toString()) ??
                    existing.priceN2)
                : existing.priceN2,
            priceN3: data['price_n3'] != null
                ? (double.tryParse(data['price_n3'].toString()) ??
                    existing.priceN3)
                : existing.priceN3,
          );
          state = AsyncValue.data(updatedList);
          return;
        }
      }

      // 4. In case of new product creation
      if (eventType == 'create' && data['product'] is Map) {
        final newProduct = ProductModel.fromJson(
            Map<String, dynamic>.from(data['product'] as Map));
        state = AsyncValue.data([newProduct, ...currentList]);
        return;
      }

      // 5. Targeted single product fetch without downloading the entire product catalog
      _fetchSingleProduct(productId, currentList);
    });
  }

  Future<void> _fetchSingleProduct(
      int productId, List<ProductModel> currentList) async {
    try {
      final response = await _api.client.get('/products/$productId');
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['data'] is Map) {
        final singleProduct = ProductModel.fromJson(
            Map<String, dynamic>.from(response.data['data']));
        final index = currentList.indexWhere((p) => p.id == productId);
        final updatedList = List<ProductModel>.from(currentList);
        if (index != -1) {
          updatedList[index] = singleProduct;
        } else {
          updatedList.insert(0, singleProduct);
        }
        state = AsyncValue.data(updatedList);
      }
    } catch (_) {
      // Background single product patch error ignored to avoid disrupting UI
    }
  }

  Future<void> fetchProducts() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.client.get('/products');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw const FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed products response payload)',
          );
        }
        final List data = resData['data'] as List;
        final products =
            data.map((json) => ProductModel.fromJson(json)).toList();
        state = AsyncValue.data(products);
        return;
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e, st) {
      state = AsyncValue.error(_api.parseError(e), st);
    }
  }

  void patchProductStock(
      int productId, int warehouseId, int newQuantity, {int? reservedQuantity}) {
    state.whenData((currentList) {
      final index = currentList.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final existing = currentList[index];
        final updatedStocks = List<Map<String, dynamic>>.from(
          existing.stocks.map((s) => Map<String, dynamic>.from(s as Map)),
        );
        final stockIndex =
            updatedStocks.indexWhere((s) => s['warehouse_id'] == warehouseId);
        if (stockIndex != -1) {
          updatedStocks[stockIndex]['quantity'] = newQuantity;
          if (reservedQuantity != null) {
            updatedStocks[stockIndex]['reserved_quantity'] = reservedQuantity;
          }
        } else {
          updatedStocks.add({
            'warehouse_id': warehouseId,
            'quantity': newQuantity,
            'reserved_quantity': reservedQuantity ?? 0,
          });
        }
        final updatedList = List<ProductModel>.from(currentList);
        updatedList[index] = existing.copyWith(stocks: updatedStocks);
        state = AsyncValue.data(updatedList);
      }
    });
  }

  @override
  void dispose() {
    _pusher.unsubscribeFromChannel('private-products');
    super.dispose();
  }
}

final productsListProvider = StateNotifierProvider<ProductsListNotifier,
    AsyncValue<List<ProductModel>>>((ref) {
  ref.watch(authProvider.select((state) => state.user?.id));
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);
  return ProductsListNotifier(api, pusher, ref);
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

final filteredProductsProvider =
    Provider<AsyncValue<List<ProductModel>>>((ref) {
  final productsAsync = ref.watch(productsListProvider);
  final searchQuery = ref.watch(productSearchProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryFilterProvider);

  return productsAsync.whenData((products) {
    return products.where((p) {
      final matchesQuery = searchQuery.isEmpty ||
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
