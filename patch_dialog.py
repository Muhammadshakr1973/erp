import sys

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add the validation method
target_method = """  @override
  void dispose() {"""
replacement_method = """  bool _isValidImageUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  void dispose() {"""
content = content.replace(target_method, replacement_method)

# Replace the if condition for showing the image
target_if = "if (_imageUrlController.text.isNotEmpty) ...["
replacement_if = "if (_isValidImageUrl(_imageUrlController.text)) ...["
content = content.replace(target_if, replacement_if)

with open('lib/features/products/views/product_form_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched successfully")
