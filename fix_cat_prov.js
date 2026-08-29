const fs = require('fs');
let c = fs.readFileSync('lib/features/products/providers/categories_provider.dart', 'utf8');

if (!c.includes('updateCategory')) {
  c = c.replace(/}\s*$/, `
  Future<CategoryModel> updateCategory(int id, String name) async {
    try {
      final response = await api.client.put('/categories/$id', data: {'name': name});
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
`);
  fs.writeFileSync('lib/features/products/providers/categories_provider.dart', c);
}
