import sys

with open('lib/features/admin/views/admin_products_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# DESKTOP CHANGES
desktop_target1 = """                        return AppCard(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ProductFormDialog(product: product),
                            );
                          },"""
desktop_replacement1 = """                        return AppCard(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ProductFormDialog(product: product),
                            );
                          },
                          onLongPress: () => _showDeleteDialog(context, ref, product),"""
content = content.replace(desktop_target1, desktop_replacement1)

desktop_target2 = """                                      if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                                        Text(
                                          'بارکۆد: ${product.barcode}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (product.unit == null || product.unit != 'دانە')
                                        Text(
                                          '${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە',
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),"""
desktop_replacement2 = """                                      if (product.unit == null || product.unit != 'دانە') ...[
                                        Text(
                                          '${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە',
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (product.barcode != null && product.barcode!.isNotEmpty)
                                        Text(
                                          'بارکۆد: ${product.barcode}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),"""
content = content.replace(desktop_target2, desktop_replacement2)

desktop_target3 = """                                const SizedBox(width: AppSpacing.xs),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.danger, size: 22),
                                  onPressed: () => _showDeleteDialog(context, ref, product),
                                ),"""
desktop_replacement3 = """                                const SizedBox(width: AppSpacing.md),"""
content = content.replace(desktop_target3, desktop_replacement3)


# MOBILE CHANGES
mobile_target1 = """                      return AppCard(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => ProductFormDialog(product: product),
                          );
                        },"""
mobile_replacement1 = """                      return AppCard(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => ProductFormDialog(product: product),
                          );
                        },
                        onLongPress: () => _showDeleteDialog(context, ref, product),"""
content = content.replace(mobile_target1, mobile_replacement1)

mobile_target2 = """                                  Text(
                                    '${product.unit == null || product.unit != 'دانە' ? '${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە • ' : ''}بارکۆد: ${product.barcode}',
                                    style: AppTextStyles.caption,
                                  ),"""
mobile_replacement2 = """                                  if (product.unit == null || product.unit != 'دانە') ...[
                                    Text(
                                      '${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە',
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  if (product.barcode != null && product.barcode!.isNotEmpty)
                                    Text(
                                      'بارکۆد: ${product.barcode}',
                                      style: AppTextStyles.caption,
                                    ),"""
content = content.replace(mobile_target2, mobile_replacement2)

mobile_target3 = """                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.danger),
                              onPressed: () => _showDeleteDialog(context, ref, product),
                            )"""
mobile_replacement3 = """                            const SizedBox(width: AppSpacing.md),"""
content = content.replace(mobile_target3, mobile_replacement3)

with open('lib/features/admin/views/admin_products_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched admin products screen final")
