import sys

with open('lib/features/admin/views/admin_products_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the middle column (desktop)
target_middle_desktop = """                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        product.name,
                                        style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      if (product.unit == null || product.unit != 'دانە') ...[
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
                                        ),
                                    ],
                                  ),
                                ),"""

replacement_middle_desktop = """                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        product.name,
                                        style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'جۆر: ${product.category?['name'] ?? '-'} • سەپڵایەر: ${product.supplier?['name'] ?? '-'}',
                                        style: AppTextStyles.caption.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      if (product.unit == null || product.unit != 'دانە') ...[
                                        Text(
                                          '${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە',
                                          style: AppTextStyles.caption.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        'بارکۆد: ${product.barcode}${product.sku != null && product.sku!.isNotEmpty ? ' • SKU: ${product.sku}' : ''}',
                                        style: AppTextStyles.caption.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),"""
content = content.replace(target_middle_desktop, replacement_middle_desktop)

# Replace the middle column (mobile)
target_middle_mobile = """                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: AppTextStyles.bodyBold),
                                  const SizedBox(height: 4),
                                  if (product.unit == null || product.unit != 'دانە') ...[
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
                                    ),
                                ],
                              ),
                            ),"""

replacement_middle_mobile = """                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(
                                    'جۆر: ${product.category?['name'] ?? '-'} • سەپڵایەر: ${product.supplier?['name'] ?? '-'}',
                                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  if (product.unit == null || product.unit != 'دانە') ...[
                                    Text(
                                      '${product.unit ?? 'کارتۆن'} = ${product.unitsPerCarton} دانە',
                                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    'بارکۆد: ${product.barcode}${product.sku != null && product.sku!.isNotEmpty ? ' • SKU: ${product.sku}' : ''}',
                                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),"""
content = content.replace(target_middle_mobile, replacement_middle_mobile)

# Replace the right column (desktop)
target_right_desktop = """                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${product.priceN1.toInt()} د.ع',
                                      style: AppTextStyles.price.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    StatusBadge(
                                      label: 'ستۆک: $totalStock',
                                      type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
                                    ),
                                  ],
                                ),"""

replacement_right_desktop = """                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${product.costPrice.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                                    Text('${product.priceN1.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                                    Text('${product.priceN2.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.orange.shade600)),
                                    Text('${product.priceN3.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade600)),
                                    const SizedBox(height: 4),
                                    StatusBadge(
                                      label: 'ستۆک: $totalStock',
                                      type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
                                    ),
                                  ],
                                ),"""
content = content.replace(target_right_desktop, replacement_right_desktop)

# Replace the right column (mobile)
target_right_mobile = """                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${product.priceN1.toInt()} د.ع', style: AppTextStyles.price),
                                const SizedBox(height: 4),
                                StatusBadge(
                                  label: 'ستۆک: $totalStock',
                                  type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
                                ),
                              ],
                            ),"""

replacement_right_mobile = """                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${product.costPrice.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                                Text('${product.priceN1.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                                Text('${product.priceN2.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade600)),
                                Text('${product.priceN3.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade600)),
                                const SizedBox(height: 4),
                                StatusBadge(
                                  label: 'ستۆک: $totalStock',
                                  type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
                                ),
                              ],
                            ),"""
content = content.replace(target_right_mobile, replacement_right_mobile)

with open('lib/features/admin/views/admin_products_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched admin_products_screen for layout and prices")
