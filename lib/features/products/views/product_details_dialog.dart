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

class ProductDetailsDialog extends ConsumerWidget {
  final ProductModel product;

  const ProductDetailsDialog({super.key, required this.product});

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوەی کاڵا', style: AppTextStyles.h3),
        content: Text(
          'دڵنیایت لە سڕینەوەی "${product.name}"؟',
          style: const TextStyle(fontFamily: 'Rudaw'),
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
              style: TextStyle(color: AppColors.danger, fontFamily: 'Rudaw'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر', style: TextStyle(fontFamily: 'Rudaw')),
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

    int totalStock = 0;
    for (var stock in product.stocks) {
      totalStock += (stock['quantity'] as int?) ?? 0;
    }
    final bool isLowStock = totalStock < 20;

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
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                    _buildDetailRow(
                      context,
                      'بارکۆد:',
                      product.barcode.isEmpty ? 'بێ بارکۆد' : product.barcode,
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
                            fontFamily: 'Rudaw',
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
                              fontFamily: 'Rudaw',
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

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
            fontFamily: 'Rudaw',
          ),
        ),
        Text(value, style: const TextStyle(fontFamily: 'Rudaw')),
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
                fontFamily: 'Rudaw',
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
            fontFamily: 'Rudaw',
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
            fontFamily: 'Rudaw',
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
              fontFamily: 'Rudaw',
            ),
          ),
        ),
      ],
    );
  }
}
