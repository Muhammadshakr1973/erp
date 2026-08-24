import sys

with open('backend/app/Http/Controllers/Api/V1/ProductController.php', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("with(['category', 'stocks'])", "with(['category', 'supplier', 'stocks'])")

with open('backend/app/Http/Controllers/Api/V1/ProductController.php', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched ProductController for supplier eager load")
