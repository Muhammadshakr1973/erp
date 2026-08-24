import sys

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('پاشگەزبوونەوە'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, newCategoryName),
              child: const Text('زیادکردن'),
            ),
          ],"""

replacement = """          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, newCategoryName),
              child: const Text('زیادکردن'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('داخستن'),
            ),
          ],"""

content = content.replace(target, replacement)

with open('lib/features/products/views/product_form_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched category dialog")
