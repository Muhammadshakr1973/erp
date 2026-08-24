import sys

with open('lib/features/products/models/product_model.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("final dynamic category;", "final dynamic category;\n  final dynamic supplier;")
content = content.replace("this.category,", "this.category,\n    this.supplier,")
content = content.replace("category: json['category'],", "category: json['category'],\n      supplier: json['supplier'],")

with open('lib/features/products/models/product_model.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched ProductModel")
