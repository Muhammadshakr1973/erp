import sys

with open('lib/features/admin/views/admin_products_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix desktop card layout
target_desktop = """                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    image: const DecorationImage(
                                      image: NetworkImage('https://via.placeholder.com/150'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
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
                                      Text(
                                        'بارکۆد: ${product.barcode}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'کارتۆن: ${product.unitsPerCarton} دانە',
                                        style: AppTextStyles.caption.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),"""

replacement_desktop = """                              children: [
                                if (product.imagePath != null && product.imagePath!.isNotEmpty) ...[
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        product.imagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: Icon(Icons.image_not_supported, color: theme.colorScheme.onSurfaceVariant, size: 24),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                ],
                                Expanded(
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
                                      if (product.barcode != null && product.barcode!.isNotEmpty) ...[
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
                                          '${product.unit ?? 'کارتۆن'}: ${product.unitsPerCarton} دانە',
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),"""
content = content.replace(target_desktop, replacement_desktop)

# Fix mobile card layout
target_mobile = """                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                                image: const DecorationImage(
                                  image: NetworkImage('https://via.placeholder.com/150'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: AppTextStyles.bodyBold),
                                  const SizedBox(height: 4),
                                  Text(
                                    'کارتۆن: ${product.unitsPerCarton} دانە • بارکۆد: ${product.barcode}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),"""

replacement_mobile = """                        child: Row(
                          children: [
                            if (product.imagePath != null && product.imagePath!.isNotEmpty) ...[
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product.imagePath!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: Icon(Icons.image_not_supported, color: theme.colorScheme.onSurfaceVariant, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: AppTextStyles.bodyBold),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product.unit == null || product.unit != 'دانە' ? '${product.unit ?? 'کارتۆن'}: ${product.unitsPerCarton} دانە • ' : ''}بارکۆد: ${product.barcode}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),"""
content = content.replace(target_mobile, replacement_mobile)

with open('lib/features/admin/views/admin_products_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched admin products screen")
