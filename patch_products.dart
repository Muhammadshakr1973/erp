import 'dart:io';

void main() {
  var file = File('lib/features/admin/views/admin_products_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../products/providers/products_provider.dart';"
  );
  
  content = content.replaceFirst(
    "class AdminProductsScreen extends StatelessWidget {",
    "class AdminProductsScreen extends ConsumerWidget {"
  );
  
  content = content.replaceFirst(
    "Widget build(BuildContext context) {",
    "Widget build(BuildContext context, WidgetRef ref) {\n    final productsAsync = ref.watch(productsListProvider);"
  );
  
  content = content.replaceFirst(
    "IconButton(icon: const Icon(AppIcons.add), onPressed: () {}),",
    "IconButton(icon: const Icon(AppIcons.add), onPressed: () {}),\n          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(productsListProvider)),"
  );
  
  content = content.replaceFirst(
    "Expanded(\n            child: ListView.separated(",
    "Expanded(\n            child: RefreshIndicator(\n              onRefresh: () async => ref.invalidate(productsListProvider),\n              child: productsAsync.when(\n                loading: () => const Center(child: CircularProgressIndicator()),\n                error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا: \$error')),\n                data: (products) {\n                  if (products.isEmpty) return const Center(child: Text('هیچ کاڵایەک نییە'));\n                  return ListView.separated("
  );
  
  content = content.replaceFirst(
    "itemCount: 20,",
    "itemCount: products.length,"
  );
  
  content = content.replaceFirst(
    "final int stock = index % 4 == 0 ? 5 : 150; // Simulate low stock",
    "final product = products[index];\n                      int totalStock = 0;\n                      for (var stock in product.stocks) {\n                        totalStock += (stock['quantity'] as int?) ?? 0;\n                      }\n                      final int stock = totalStock;"
  );
  
  content = content.replaceFirst(
    "Text('شامپۆی سەر \${index + 1}'",
    "Text(product.name"
  );
  
  content = content.replaceFirst(
    "Text('کارتۆن: 12 دانە • بارکۆد: 123456789'",
    "Text('کارتۆن: \${product.unitsPerCarton} دانە • بارکۆد: \${product.barcode}'"
  );
  
  content = content.replaceFirst(
    "Text('15,000 د.ع'",
    "Text('\${product.priceN1.toInt()} د.ع'"
  );

  content = content.replaceFirst(
    "              },\n            ),\n          ),\n        ],\n      ),\n    );\n  }\n}",
    "              },\n                  );\n                },\n              ),\n            ),\n          ),\n        ],\n      ),\n    );\n  }\n}"
  );

  file.writeAsStringSync(content);
}
