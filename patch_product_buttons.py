import sys

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('پاشگەزبوونەوە'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: isMobile ? 120 : 140,
                      child: AppButton(
                        text: 'پاشەکەوتکردن',
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),"""

replacement = """                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: isMobile ? 120 : 140,
                      child: AppButton(
                        text: 'پاشەکەوت',
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('داخستن'),
                    ),
                  ],
                ),"""

content = content.replace(target, replacement)

with open('lib/features/products/views/product_form_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched form buttons")
