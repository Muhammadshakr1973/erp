import sys

with open('lib/features/admin/views/admin_products_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر'),
          ),
          TextButton(
            onPressed: () {
              ref.read(productActionsProvider).deleteProduct(product.id);
              Navigator.pop(context);
            },
            child: const Text('بەڵێ', style: TextStyle(color: AppColors.danger)),
          ),
        ],"""

replacement = """        actions: [
          TextButton(
            onPressed: () {
              ref.read(productActionsProvider).deleteProduct(product.id);
              Navigator.pop(context);
            },
            child: const Text('بەڵێ', style: TextStyle(color: AppColors.danger)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر'),
          ),
        ],"""

content = content.replace(target, replacement)

with open('lib/features/admin/views/admin_products_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched delete dialog")
