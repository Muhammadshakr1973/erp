import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/category_model.dart';

final categoriesListProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/categories');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

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
      ref.invalidate(categoriesListProvider);
      return CategoryModel.fromJson(response.data['data']);
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
      ref.invalidate(categoriesListProvider);
      return CategoryModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await api.client.delete('/categories/$id');
      ref.invalidate(categoriesListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
