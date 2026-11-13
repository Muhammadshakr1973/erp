import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/product_model.dart';
import 'product_form_dialog.dart';
import '../providers/products_provider.dart';
import 'barcode_generator_dialog.dart';

class ProductDetailsDialog extends ConsumerWidget {
  final ProductModel product;

  const ProductDetailsDialog({super.key, required this.product});

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('سڕینەوەی کاڵا', style: AppTextStyles.h3),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Text(
          'دڵنیایت لە سڕینەوەی "${product.name}"؟',
          style: const TextStyle(fontFamily: 'KJino'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(productActionsProvider).deleteProduct(product.id);
              Navigator.pop(context); // Close confirm
              Navigator.pop(context); // Close details
            },
            child: const Text(
              'بەڵێ سڕینەوە',
              style: TextStyle(color: AppColors.danger, fontFamily: 'KJino'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final allProducts = ref.watch(productsListProvider).valueOrNull ?? [];
    final List<ProductModel> childVariants = product.isParent
        ? (allProducts.where((p) => p.parentId == product.id).toList()
          ..sort((a, b) => a.id.compareTo(b.id)))
        : const [];

    final double totalStock = product.isParent
        ? childVariants.fold<double>(0.0, (s, c) => s + c.totalStock)
        : product.totalStock;
    final double minStockLevel = product.isParent
        ? childVariants.fold<double>(0.0, (s, c) => s + c.minStockLevel)
        : product.minStockLevel;
    final bool isLowStock = product.isParent
        ? childVariants.any((c) => c.isLowStock)
        : product.isLowStock;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: isMobile ? double.infinity : 650,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('زانیارییەکانی کاڵا', style: AppTextStyles.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Product Main Info (Image, Name, SKU, Barcode)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child:
                      (product.imagePath != null &&
                          product.imagePath!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            product.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.inventory_2_outlined,
                              color: theme.colorScheme.primary,
                              size: 40,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: theme.colorScheme.primary,
                          size: 40,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'جۆر: ${product.category?['name'] ?? 'دیاری نەکراو'}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'کۆمپانیا: ${product.supplier?['name'] ?? 'دیاری نەکراو'}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Codes and Unit Conversion Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'بارکۆد:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'KJino',
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.barcode.isEmpty ? 'بێ بارکۆد' : product.barcode,
                              style: const TextStyle(fontFamily: 'KJino'),
                            ),
                            if (product.barcode.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.barcode_reader, size: 20, color: AppColors.primary),
                                tooltip: 'کردارەکانی بارکۆد',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => BarcodeGeneratorDialog(product: product),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(context, 'SKU:', product.sku ?? 'بێ SKU'),
                    const Divider(height: 16),
                    _buildDetailRow(
                      context,
                      'یەکە و کارتۆن:',
                      '${product.unit ?? "دانە"} (کارتۆنێک = ${product.unitsPerCarton} دانە)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Pricing Tiers (The GARDI Price rules)
            Text(
              'نرخەکان و ستۆک',
              style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تێچوو (کۆست):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'KJino',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFFE11D48).withValues(alpha: 0.15)
                                : const Color(0xFFFFECEF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFFE11D48).withValues(alpha: 0.35)
                                  : const Color(0xFFFFD1D8),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            Formatters.currency(product.costPrice),
                            style: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFFFDA4AF)
                                  : const Color(0xFFE11D48),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'KJino',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildDetailRowWithColor(
                      context,
                      'نرخی کڕیاری گەورە (N1):',
                      Formatters.currency(product.priceN1),
                      const Color(0xFF10B981),
                      dotColor: const Color(0xFF10B981),
                    ),
                    const Divider(height: 16),
                    _buildDetailRowWithColor(
                      context,
                      'نرخی کڕیاری ناوەند (N2):',
                      Formatters.currency(product.priceN2),
                      const Color(0xFFF59E0B),
                      dotColor: const Color(0xFFF59E0B),
                    ),
                    const Divider(height: 16),
                    _buildDetailRowWithColor(
                      context,
                      'نرخی تاکفرۆش/ئاسایی (N3):',
                      Formatters.currency(product.priceN3),
                      const Color(0xFFF43F5E),
                      dotColor: const Color(0xFFF43F5E),
                    ),
                    const Divider(height: 16),
                    _buildDetailRowWithBadge(
                      context,
                      'بڕی ستۆک:',
                      '$totalStock دانە',
                      isLowStock ? AppColors.danger : AppColors.success,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      context,
                      'کەمترین بڕ (ئاستی ئاگاداری):',
                      '$minStockLevel دانە',
                    ),
                    if (isLowStock) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                minStockLevel > 0
                                    ? 'ئاگاداری: ئەم کاڵایە گەیشتووەتە کەمترین بڕی ستۆک ($minStockLevel دانە) یان کەمترە!'
                                    : 'ئاگاداری: ئەم کاڵایە ستۆکی نەماوە!',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'KJino',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (product.isParent) ...[
              Text(
                'جۆرەکان / ڕەنگەکان (${childVariants.length})',
                style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: childVariants.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('هیچ جۆرێک نییە', textAlign: TextAlign.center),
                        )
                      : Column(
                          children: childVariants.map((v) {
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      v.displayVariantLabel,
                                      style: AppTextStyles.bodyBold,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!v.useParentPrice) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'نرخی تایبەت',
                                        style: TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                'ستۆک: ${Formatters.cleanNumberString(v.totalStock)} • N1: ${Formatters.currency(v.priceN1)}${v.barcode.isNotEmpty ? " • ${v.barcode}" : ""}',
                                style: AppTextStyles.caption,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'دەستکاریکردنی جۆر',
                                onPressed: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => ProductFormDialog(product: v),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            const SizedBox(height: AppSpacing.sm),

            // Actions footer
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'دەستکاریکردن',
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            ProductFormDialog(product: product),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _showDeleteDialog(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'KJino',
          ),
        ),
        Text(value, style: const TextStyle(fontFamily: 'KJino')),
      ],
    );
  }

  Widget _buildDetailRowWithColor(
    BuildContext context,
    String label,
    String value,
    Color color, {
    Color? dotColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'KJino',
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: 'KJino',
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRowWithBadge(
    BuildContext context,
    String label,
    String value,
    Color badgeColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'KJino',
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'KJino',
            ),
          ),
        ),
      ],
    );
  }
}
