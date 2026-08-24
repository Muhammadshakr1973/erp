import sys
import re

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update Unit Autocomplete label
content = content.replace("labelText: 'یەکە (دانە، کیلۆ...)'", "labelText: 'یەکە'")

# 2. Update Image URL textfield to add margin
content = content.replace("""                        // Image URL and Preview
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _imageUrlController,
                                labelText: 'لینکی وێنەی کاڵا',
                                hintText: 'لینک لێرە دابنێ (بۆ نموونە https://...)',""", """                        // Image URL and Preview
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _imageUrlController,
                                labelText: 'لینکی وێنە',
                                hintText: 'لینک دابنێ',""")

# 3. Replace Basic Info (Remove isMobile check and use Row)
basic_info_pattern = re.compile(r"// Basic Info.*?\] else \.\.\.\[", re.DOTALL)
basic_info_replacement = """// Basic Info
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                controller: _nameController,
                                labelText: 'ناوی کاڵا',
                                hintText: 'ناوی کاڵا',
                                validator: (v) => v!.isEmpty ? 'ناوی کاڵا پێویستە' : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 1,
                              child: AppTextField(
                                controller: _barcodeController,
                                labelText: 'بارکۆد',
                                hintText: 'بارکۆد',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner),
                                  onPressed: () {
                                    CameraBarcodeScanner.show(context, (scanned) {
                                      setState(() {
                                        _barcodeController.text = scanned;
                                      });
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 1,
                              child: AppTextField(
                                controller: _skuController,
                                labelText: 'SKU',
                                hintText: 'SKU',
                              ),
                            ),
                          ],
                        ),
                        // Removed else ...["""
content = basic_info_pattern.sub(basic_info_replacement, content)

# Remove the trailing `],` from the old else block of basic info
# Wait, it's easier to just replace the whole body from `// Basic Info` to the end of `// Quantities & Status`
