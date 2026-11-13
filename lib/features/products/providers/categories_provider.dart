import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/category_model.dart';
import 'products_provider.dart';

class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() async {
    final api = ref.watch(apiClientProvider);
    try {
      final response = await api.client.get('/categories');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed categories response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data.map((json) => CategoryModel.fromJson(json)).toList();
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  void addLocally(CategoryModel category) {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final updated = [
      ...current.where((c) => c.id != category.id),
      category,
    ]..sort((a, b) => a.name.compareTo(b.name));
    state = AsyncValue.data(updated);
  }

  void updateLocally(CategoryModel category) {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final updated = current
        .map((c) => c.id == category.id ? category : c)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    state = AsyncValue.data(updated);
  }

  void removeLocally(int id) {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncValue.data(current.where((c) => c.id != id).toList());
  }
}

final categoriesListProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(
  CategoriesNotifier.new,
);

final categoryActionsProvider = Provider<CategoryActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return CategoryActions(api, ref);
});

class CategoryActions {
  final ApiClient api;
  final Ref ref;

  CategoryActions(this.api, this.ref);

  Future<CategoryModel> addCategory(String name) async {
    try {
      final response = await api.client.post(
        '/categories',
        data: {'name': name},
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed category response payload)',
        );
      }
      final category = CategoryModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      ref.read(categoriesListProvider.notifier).addLocally(category);
      return category;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<CategoryModel> updateCategory(int id, String name) async {
    try {
      final response = await api.client.put(
        '/categories/$id',
        data: {'name': name},
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed category response payload)',
        );
      }
      final updatedCategory = CategoryModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      ref.read(categoriesListProvider.notifier).updateLocally(updatedCategory);
      ref
          .read(productsListProvider.notifier)
          .updateCategoryNameLocally(updatedCategory.id, updatedCategory.name);
      return updatedCategory;
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await api.client.delete('/categories/$id');
      ref.read(categoriesListProvider.notifier).removeLocally(id);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
