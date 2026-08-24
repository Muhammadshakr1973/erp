import sys

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update Unit Autocomplete label
content = content.replace("labelText: 'یەکە (دانە، کیلۆ...)'", "labelText: 'یەکە'")

# 2. Image URL Label
content = content.replace("labelText: 'لینکی وێنەی کاڵا',", "labelText: 'لینکی وێنە',")
content = content.replace("hintText: 'لینک لێرە دابنێ (بۆ نموونە https://...)',", "hintText: 'https://...',")

# 3. Category & Supplier label
content = content.replace("labelText: 'جۆری کاڵا (Category)',", "labelText: 'جۆر',")
content = content.replace("labelText: 'سەپڵایەر (Supplier)',", "labelText: 'سەپڵایەر',")


# We need to replace the entire `if (isMobile)` blocks for layout to just be Rows.
# Let's replace the whole section starting from `// Basic Info` down to `// Quantities & Status` block end.
import re

start_str = "// Basic Info"
end_str = "Row(\n                  mainAxisAlignment: MainAxisAlignment.end,"

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    new_section = """// Basic Info
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
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(child: categoryDropdown),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: supplierDropdown),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Prices
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _costPriceController,
                                labelText: 'کڕین',
                                hintText: 'کڕین',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppTextField(
                                controller: _priceN1Controller,
                                labelText: 'فرۆشتن ١',
                                hintText: 'فرۆشتن ١',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppTextField(
                                controller: _priceN2Controller,
                                labelText: 'فرۆشتن ٢',
                                hintText: 'فرۆشتن ٢',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppTextField(
                                controller: _priceN3Controller,
                                labelText: 'فرۆشتن ٣',
                                hintText: 'فرۆشتن ٣',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Quantities & Status
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _unitsPerCartonController,
                                labelText: 'کارتۆن',
                                hintText: 'کارتۆن',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildUnitAutocomplete(theme),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppTextField(
                                controller: _stockController,
                                labelText: 'ستۆک',
                                hintText: 'ستۆک',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('چالاکە', style: AppTextStyles.caption),
                                  Switch(
                                    value: _isActive,
                                    onChanged: (v) => setState(() => _isActive = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                """
    content = content[:start_idx] + new_section + content[end_idx:]

with open('lib/features/products/views/product_form_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched basic info, prices, and quantities")
