import sys

with open('lib/features/admin/views/admin_products_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "'${product.unit ?? 'کارتۆن'}: ${product.unitsPerCarton} دانە'",
    "'${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە'"
)

content = content.replace(
    "'${product.unit == null || product.unit != 'دانە' ? '${product.unit ?? 'کارتۆن'}: ${product.unitsPerCarton} دانە • ' : ''}بارکۆد: ${product.barcode}'",
    "'${product.unit == null || product.unit != 'دانە' ? '${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە • ' : ''}بارکۆد: ${product.barcode}'"
)

with open('lib/features/admin/views/admin_products_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched equal sign")
