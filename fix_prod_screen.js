const fs = require('fs');
let c = fs.readFileSync('lib/features/admin/views/admin_products_screen.dart', 'utf8');

if (!c.includes('AdminCategoriesDialog')) {
  c = c.replace(/import 'product_form_dialog.dart';/, `import 'product_form_dialog.dart';\nimport 'admin_categories_dialog.dart';`);
  
  c = c.replace(/IconButton\(\s*icon: const Icon\(AppIcons.add\),\s*onPressed: \(\) {[^}]*}\),\s*/, `IconButton(
              icon: const Icon(Icons.category),
              tooltip: 'بەڕێوەبردنی جۆرەکان',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AdminCategoriesDialog(),
                );
              }),
          IconButton(
              icon: const Icon(AppIcons.add),
              tooltip: 'زیادکردنی کاڵا',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ProductFormDialog(),
                );
              }),
          `);
  fs.writeFileSync('lib/features/admin/views/admin_products_screen.dart', c);
}
