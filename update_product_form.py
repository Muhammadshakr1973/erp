import re

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add imports
content = content.replace(
    "import '../providers/categories_provider.dart';",
    "import '../providers/categories_provider.dart';\nimport '../providers/suppliers_provider.dart';"
)

# Replace dialog width
content = content.replace("width: isMobile ? double.infinity : 500,", "width: isMobile ? double.infinity : 800,")

