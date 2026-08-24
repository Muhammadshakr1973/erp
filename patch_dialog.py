import sys

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """    if (result != null && result.trim().isNotEmpty) {
      try {
        final newCategory = await ref.read(categoryActionsProvider).addCategory(result.trim());
        setState(() {
          _selectedCategoryId = newCategory.id;
        });
      } catch (e) {"""

replacement = """    if (result != null && result.trim().isNotEmpty) {
      try {
        final newCategory = await ref.read(categoryActionsProvider).addCategory(result.trim());
        // چاوەڕێ دەکەین تا لیستەکە نوێ دەبێتەوە
        await ref.read(categoriesListProvider.future);
        
        if (mounted) {
          setState(() {
            _selectedCategoryId = newCategory.id;
          });
        }
      } catch (e) {"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/features/products/views/product_form_dialog.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched successfully")
else:
    print("Target not found")
