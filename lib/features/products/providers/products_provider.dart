import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    final user = _ref.read(authProvider).user;
    if (user != null) {
      fetchProducts();
      _subscribeToPusher();
    } else {
      state = const AsyncValue.data([]);
    }
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
      refreshProductsSilently();
      return;
    }

    state.whenData((currentList) {
      if (eventType == 'delete') {
        removeProductLocally(productId);
        return;
      }

      // 1. Granular patch if full or partial product is in payload
      if (data['product'] is Map) {
        final pMap = Map<String, dynamic>.from(data['product'] as Map);
        final index = currentList.indexWhere((p) => p.id == productId);
        if (index != -1) {
          final existing = currentList[index];
          final hasParentIdKey = pMap.containsKey('parent_id');
          final parsedParentId = hasParentIdKey
              ? (pMap['parent_id'] != null
                  ? int.tryParse(pMap['parent_id'].toString())
                  : null)
              : existing.parentId;
          final hasVariantNameKey = pMap.containsKey('variant_name');
          final updated = existing.copyWith(
            parentId: parsedParentId,
            clearParentId: hasParentIdKey && parsedParentId == null,
            isParent: pMap['is_parent'] != null
                ? (pMap['is_parent'] == 1 || pMap['is_parent'] == true)
                : existing.isParent,
            name: pMap['name']?.toString() ?? existing.name,
            variantName: pMap['variant_name']?.toString(),
            clearVariantName: hasVariantNameKey && pMap['variant_name'] == null,
            sku: pMap['sku']?.toString() ?? existing.sku,
            barcode: pMap['barcode']?.toString() ?? existing.barcode,
            useParentPrice: pMap['use_parent_price'] != null
                ? (pMap['use_parent_price'] == 1 || pMap['use_parent_price'] == true)
                : existing.useParentPrice,
            isActive: pMap['is_active'] != null
                ? (pMap['is_active'] == 1 || pMap['is_active'] == true)
                : existing.isActive,
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
      if (!mounted) return;
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

  Future<void> refreshSingleProduct(int productId) async {
    final currentList = state.valueOrNull;
    if (currentList != null) {
      await _fetchSingleProduct(productId, currentList);
    }
  }

  void patchProductsFromOrderData(Map<String, dynamic> orderData) {
    state.whenData((currentList) {
      final items = orderData['items'];
      if (items is! List || items.isEmpty) return;

      bool anyUpdated = false;
      final updatedList = List<ProductModel>.from(currentList);

      for (final item in items) {
        if (item is Map) {
          final prodMap = item['product'];
          final pid = int.tryParse(
            (item['product_id'] ?? prodMap?['id'])?.toString() ?? '',
          );
          if (pid != null && prodMap is Map && prodMap['stocks'] is List) {
            final index = updatedList.indexWhere((p) => p.id == pid);
            if (index != -1) {
              final existing = updatedList[index];
              updatedList[index] = existing.copyWith(
                stocks: prodMap['stocks'] as List,
              );
              anyUpdated = true;
            }
          } else if (pid != null) {
            _fetchSingleProduct(pid, currentList);
          }
        }
      }

      if (anyUpdated) {
        state = AsyncValue.data(updatedList);
      }
    });
  }

  Future<void> fetchProducts() async {
    state = const AsyncValue.loading();
    try {
      final products = await _fetchProductsFromApi();
      if (mounted) state = AsyncValue.data(products);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(_api.parseError(e), st);
    }
  }

  Future<void> refreshProductsSilently() async {
    try {
      final freshProducts = await _fetchProductsFromApi();
      if (!mounted) return;

      final currentProducts = state.valueOrNull;
      if (currentProducts == null) {
        state = AsyncValue.data(freshProducts);
        return;
      }

      final currentById = {
        for (final product in currentProducts) product.id: product,
      };
      final updatedProducts = freshProducts.map((freshProduct) {
        final currentProduct = currentById[freshProduct.id];
        return currentProduct != null &&
                _sameProductData(currentProduct, freshProduct)
            ? currentProduct
            : freshProduct;
      }).toList();

      var hasChanges = currentProducts.length != updatedProducts.length;
      for (var index = 0;
          !hasChanges && index < currentProducts.length;
          index++) {
        hasChanges = !identical(currentProducts[index], updatedProducts[index]);
      }
      if (!hasChanges) {
        return;
      }

      state = AsyncValue.data(updatedProducts);
    } catch (e, st) {
      if (mounted) {
        debugPrint('Silent product refresh failed: $e\n$st');
      }
    }
  }

  Future<List<ProductModel>> _fetchProductsFromApi() async {
    final response = await _api.client.get('/products');
    if (response.statusCode != 200) {
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    }

    final resData = response.data;
    if (resData is! Map || resData['data'] is! List) {
      throw const FormatException(
        'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed products response payload)',
      );
    }

    final List data = resData['data'] as List;
    return data.map((json) => ProductModel.fromJson(json)).toList();
  }

  bool _sameProductData(ProductModel current, ProductModel fresh) {
    return current.id == fresh.id &&
        current.parentId == fresh.parentId &&
        current.isParent == fresh.isParent &&
        current.name == fresh.name &&
        current.variantName == fresh.variantName &&
        current.sku == fresh.sku &&
        current.barcode == fresh.barcode &&
        current.categoryId == fresh.categoryId &&
        current.supplierId == fresh.supplierId &&
        _sameNestedData(current.category, fresh.category) &&
        _sameNestedData(current.supplier, fresh.supplier) &&
        current.unit == fresh.unit &&
        current.costPrice == fresh.costPrice &&
        current.priceN1 == fresh.priceN1 &&
        current.priceN2 == fresh.priceN2 &&
        current.priceN3 == fresh.priceN3 &&
        current.useParentPrice == fresh.useParentPrice &&
        current.unitsPerCarton == fresh.unitsPerCarton &&
        current.imagePath == fresh.imagePath &&
        current.isActive == fresh.isActive &&
        _sameNestedData(current.stocks, fresh.stocks);
  }

  bool _sameNestedData(Object? current, Object? fresh) {
    if (identical(current, fresh)) return true;
    if (current is List && fresh is List) {
      if (current.length != fresh.length) return false;
      for (var index = 0; index < current.length; index++) {
        if (!_sameNestedData(current[index], fresh[index])) return false;
      }
      return true;
    }
    if (current is Map && fresh is Map) {
      if (current.length != fresh.length) return false;
      for (final entry in current.entries) {
        if (!fresh.containsKey(entry.key) ||
            !_sameNestedData(entry.value, fresh[entry.key])) {
          return false;
        }
      }
      return true;
    }
    return current == fresh;
  }

  void patchProductStock(
      int productId, int warehouseId, num newQuantity, {num? reservedQuantity}) {
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

  void upsertProductsLocally(List<ProductModel> products) {
    if (products.isEmpty) return;
    final currentList = state.valueOrNull;
    if (currentList == null) {
      state = AsyncValue.data(products);
      return;
    }
    final updatedList = List<ProductModel>.from(currentList);
    for (final item in products) {
      final index = updatedList.indexWhere((p) => p.id == item.id);
      if (index != -1) {
        updatedList[index] = item;
      } else {
        updatedList.insert(0, item);
      }
    }
    state = AsyncValue.data(updatedList);
  }

  void addProductLocally(ProductModel newProduct) {
    upsertProductsLocally([newProduct]);
  }

  void removeProductLocally(int id) {
    final currentList = state.valueOrNull;
    if (currentList != null) {
      final updatedList = currentList
          .where((p) => p.id != id)
          .map(
            (p) => p.parentId == id
                ? p.copyWith(
                    clearParentId: true,
                    clearVariantName: true,
                    useParentPrice: true,
                  )
                : p,
          )
          .toList();
      state = AsyncValue.data(updatedList);
    }
  }

  void updateCategoryNameLocally(int categoryId, String newName) {
    state.whenData((currentList) {
      bool anyUpdated = false;
      final updatedList = currentList.map((p) {
        if (p.categoryId == categoryId) {
          anyUpdated = true;
          final updatedCategory = p.category is Map
              ? {
                  ...Map<String, dynamic>.from(p.category as Map),
                  'name': newName,
                }
              : {'id': categoryId, 'name': newName};
          return p.copyWith(category: updatedCategory);
        }
        return p;
      }).toList();

      if (anyUpdated) {
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

enum StockFilterMode { all, lessThan, greaterThan }

class StockQuantityFilter {
  final StockFilterMode mode;
  final double? threshold;

  const StockQuantityFilter({
    this.mode = StockFilterMode.all,
    this.threshold,
  });

  bool get isActive => mode != StockFilterMode.all && threshold != null;
}

final selectedCategoryFilterProvider = StateProvider<int?>((ref) => null);
final productStatusFilterProvider = StateProvider<String>((ref) => 'all');
final productStockFilterProvider = StateProvider<StockQuantityFilter>(
  (ref) => const StockQuantityFilter(),
);

final filteredProductsProvider =
    Provider<AsyncValue<List<ProductModel>>>((ref) {
  final productsAsync = ref.watch(productsListProvider);
  final searchQuery = ref.watch(productSearchProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryFilterProvider);
  final statusFilter = ref.watch(productStatusFilterProvider);
  final stockFilter = ref.watch(productStockFilterProvider);

  return productsAsync.whenData((products) {
    final Map<int, List<ProductModel>> variantsByParent = {};
    for (final p in products) {
      if (p.parentId != null) {
        variantsByParent.putIfAbsent(p.parentId!, () => []).add(p);
      }
    }

    return products.where((p) {
      if (p.isVariant) return false;
      final children = p.isParent ? (variantsByParent[p.id] ?? const []) : const <ProductModel>[];

      bool matchesSingleQuery(ProductModel item) {
        return item.name.toLowerCase().contains(searchQuery) ||
            (item.variantName != null && item.variantName!.toLowerCase().contains(searchQuery)) ||
            item.barcode.toLowerCase().contains(searchQuery) ||
            (item.sku != null && item.sku!.toLowerCase().contains(searchQuery));
      }

      final matchesQuery = searchQuery.isEmpty ||
          matchesSingleQuery(p) ||
          children.any(matchesSingleQuery);

      bool matchesCategory = true;
      if (selectedCategory != null) {
        if (selectedCategory == -1) {
          // "بێ جۆر" - Products without a category
          matchesCategory = p.categoryId == null;
        } else {
          matchesCategory = p.categoryId == selectedCategory;
        }
      }

      bool matchesStatus = true;
      if (statusFilter == 'no_image') {
        matchesStatus = p.imagePath == null || p.imagePath!.trim().isEmpty;
      } else if (statusFilter == 'missing_price') {
        if (p.isParent && children.isNotEmpty) {
          matchesStatus = children.any((c) =>
              c.costPrice <= 0 || c.priceN1 <= 0 || c.priceN2 <= 0 || c.priceN3 <= 0);
        } else {
          matchesStatus = p.costPrice <= 0 ||
              p.priceN1 <= 0 ||
              p.priceN2 <= 0 ||
              p.priceN3 <= 0;
        }
      } else if (statusFilter == 'no_supplier') {
        matchesStatus = p.supplierId == null;
      } else if (statusFilter == 'no_barcode') {
        if (p.isParent && children.isNotEmpty) {
          matchesStatus = children.any((c) => c.barcode.trim().isEmpty);
        } else {
          matchesStatus = p.barcode.trim().isEmpty;
        }
      } else if (statusFilter == 'no_unit') {
        matchesStatus = p.unit == null || p.unit!.trim().isEmpty;
      }

      bool matchesStock = true;
      final effectiveStock = p.isParent
          ? children.fold<double>(0.0, (sum, c) => sum + c.totalStock)
          : p.totalStock;
      if (stockFilter.mode == StockFilterMode.lessThan &&
          stockFilter.threshold != null) {
        matchesStock = effectiveStock < stockFilter.threshold!;
      } else if (stockFilter.mode == StockFilterMode.greaterThan &&
          stockFilter.threshold != null) {
        matchesStock = effectiveStock > stockFilter.threshold!;
      }

      return matchesQuery && matchesCategory && matchesStatus && matchesStock;
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

  Future<ProductModel> addProduct(Map<String, dynamic> data) async {
    try {
      final response = await api.client.post('/products', data: data);
      final rawData = response.data['data'] ?? response.data;
      final newProduct = ProductModel.fromJson(
        Map<String, dynamic>.from(rawData as Map),
      );
      final toUpsert = <ProductModel>[newProduct];
      if (response.data is Map && response.data['variants'] is List) {
        for (final v in response.data['variants'] as List) {
          if (v is Map) {
            toUpsert.add(ProductModel.fromJson(Map<String, dynamic>.from(v)));
          }
        }
      }
      ref.read(productsListProvider.notifier).upsertProductsLocally(toUpsert);
      return newProduct;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<ProductModel> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      final response = await api.client.put('/products/$id', data: data);
      final rawData = response.data['data'] ?? response.data;
      final updatedProduct = ProductModel.fromJson(
        Map<String, dynamic>.from(rawData as Map),
      );
      final toUpsert = <ProductModel>[updatedProduct];
      if (response.data is Map) {
        if (response.data['variants'] is List) {
          for (final v in response.data['variants'] as List) {
            if (v is Map) {
              toUpsert.add(ProductModel.fromJson(Map<String, dynamic>.from(v)));
            }
          }
        }
        if (response.data['detached_variants'] is List) {
          for (final v in response.data['detached_variants'] as List) {
            if (v is Map) {
              toUpsert.add(ProductModel.fromJson(Map<String, dynamic>.from(v)));
            }
          }
        }
      }
      ref.read(productsListProvider.notifier).upsertProductsLocally(toUpsert);
      return updatedProduct;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<ProductModel> detachVariant(int id) async {
    try {
      final response = await api.client.post('/products/$id/detach-variant');
      final rawData = response.data['data'] ?? response.data;
      final detached = ProductModel.fromJson(
        Map<String, dynamic>.from(rawData as Map),
      );
      ref.read(productsListProvider.notifier).addProductLocally(detached);
      return detached;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      final response = await api.client.delete('/products/$id');
      final notifier = ref.read(productsListProvider.notifier);
      notifier.removeProductLocally(id);
      if (response.data is Map && response.data['detached_variants'] is List) {
        final detached = <ProductModel>[];
        for (final v in response.data['detached_variants'] as List) {
          if (v is Map) {
            detached.add(ProductModel.fromJson(Map<String, dynamic>.from(v)));
          }
        }
        if (detached.isNotEmpty) {
          notifier.upsertProductsLocally(detached);
        }
      }
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
