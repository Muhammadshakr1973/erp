import sys

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(child: categoryDropdown),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: supplierDropdown),
                          ],
                        ),"""

replacement = """                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: categoriesAsync.when(
                                data: (categories) {
                                  final int? validValue = categories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null;
                                  return DropdownButtonFormField<int>(
                                    value: validValue,
                                    decoration: InputDecoration(
                                      labelText: 'جۆر',
                                      labelStyle: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      filled: true,
                                      fillColor: theme.colorScheme.surface,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                                    ),
                                    items: [
                                      ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                      const DropdownMenuItem(value: -1, child: Text('+ جۆرێکی نوێ زیادبکە', style: TextStyle(color: AppColors.primary))),
                                    ],
                                    onChanged: (v) {
                                      if (v == -1) {
                                        _showAddCategoryDialog(context, ref);
                                      } else {
                                        setState(() => _selectedCategoryId = v);
                                      }
                                    },
                                  );
                                },
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (err, stack) => const Text('کێشە لە هێنانی جۆرەکان'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: suppliersAsync.when(
                                data: (suppliers) {
                                  final int? validValue = suppliers.any((s) => s.id == _selectedSupplierId) ? _selectedSupplierId : null;
                                  return DropdownButtonFormField<int>(
                                    value: validValue,
                                    decoration: InputDecoration(
                                      labelText: 'سەپڵایەر',
                                      labelStyle: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      filled: true,
                                      fillColor: theme.colorScheme.surface,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                                    ),
                                    items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                    onChanged: (v) => setState(() => _selectedSupplierId = v),
                                  );
                                },
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (err, stack) => const Text('کێشە لە هێنانی سەپڵایەرەکان'),
                              ),
                            ),
                          ],
                        ),"""

content = content.replace(target, replacement)

with open('lib/features/products/views/product_form_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched dropdowns")
