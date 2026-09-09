import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/providers/products_provider.dart';
import '../../products/providers/categories_provider.dart';
import '../../products/views/product_form_dialog.dart';
import 'admin_categories_dialog.dart';
import '../../products/views/product_details_dialog.dart';
import '../../products/models/product_model.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ProductModel product,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوەی کاڵا'),
        content: Text('دڵنیایت لە سڕینەوەی "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(productActionsProvider).deleteProduct(product.id);
              Navigator.pop(context);
            },
            child: const Text(
              'بەڵێ',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTierRow({
    required String label,
    required double price,
    required Color dotColor,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        Text(
          Formatters.number(price),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            fontFamily: 'Rudaw',
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontFamily: 'Rudaw',
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کاڵاکان و کۆگا', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'بەڕێوەبردنی جۆرەکان',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AdminCategoriesDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(AppIcons.add),
            tooltip: 'زیادکردنی کاڵا',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ProductFormDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(productsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hintText: 'گەڕان بۆ کاڵا، بارکۆد...',
                    prefixIcon: AppIcons.search,
                    onChanged: (value) {
                      ref.read(productSearchProvider.notifier).search(value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  height: 50, // Matches new input height beautifully
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      24,
                    ), // Matches AppTextField
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(AppIcons.scan),
                    onPressed: () {
                      CameraBarcodeScanner.show(context, (scannedBarcode) {
                        setState(() {
                          _searchController.text = scannedBarcode;
                        });
                        ref
                            .read(productSearchProvider.notifier)
                            .search(scannedBarcode);
                      });
                    },
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ChoiceChip(
                        label: const Text('هەموو جۆرەکان'),
                        selected: selectedCategory == null,
                        onSelected: (_) {
                          ref
                                  .read(selectedCategoryFilterProvider.notifier)
                                  .state =
                              null;
                        },
                      ),
                    ),
                    ...categories.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: selectedCategory == c.id,
                          onSelected: (selected) {
                            ref
                                .read(selectedCategoryFilterProvider.notifier)
                                .state = selected
                                ? c.id
                                : null;
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(productsListProvider),
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'کێشەیەک ڕوویدا لە بارکردنی داتاکان:',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$error',
                          style: AppTextStyles.caption.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          text: 'دووبارە هەوڵبدەرەوە',
                          onPressed: () => ref.invalidate(productsListProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'هیچ کاڵایەک نییە',
                              style: AppTextStyles.h3,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'هیچ کاڵایەک بەو مەرجانە نەدۆزرایەوە.',
                              style: AppTextStyles.caption.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final screenWidth = MediaQuery.of(context).size.width;
                  int crossAxisCount = 1;
                  if (screenWidth >= 1024) {
                    crossAxisCount = 3;
                  } else if (screenWidth >= 600) {
                    crossAxisCount = 2;
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.sm,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      mainAxisExtent: 195,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      int totalStock = 0;
                      for (var stock in product.stocks) {
                        totalStock += (stock['quantity'] as int?) ?? 0;
                      }
                      final bool isLowStock = totalStock < 20;

                      return AppCard(
                        padding: const EdgeInsets.all(12.0),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                ProductDetailsDialog(product: product),
                          );
                        },
                        onLongPress: () =>
                            _showDeleteDialog(context, ref, product),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ستونی یەکەم: وێنە لە سەرەوە (top right)، پاشان (جۆر، کۆمپانیا، SKU) بەشێوەی ستونی
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: (product.imagePath != null &&
                                            product.imagePath!.isNotEmpty)
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: Image.network(
                                              product.imagePath!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Icon(
                                                Icons.inventory_2_outlined,
                                                color: theme
                                                    .colorScheme.primary,
                                                size: 26,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.inventory_2_outlined,
                                            color: theme.colorScheme.primary,
                                            size: 26,
                                          ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'جۆر: ${product.category?['name'] ?? '-'}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'کۆمپانیا: ${product.supplier?['name'] ?? '-'}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SKU: ${product.sku != null && product.sku!.isNotEmpty ? product.sku : '-'}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // ستونی دووەم: ناوی کاڵا، بارکۆد
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: AppTextStyles.bodyBold.copyWith(
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'بارکۆد: ${product.barcode}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (product.unit != null &&
                                      product.unit != 'دانە') ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'یەکە: ${product.unit} = ${product.unitsPerCarton} دانە',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        color: theme
                                            .colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // ستونی سێیەم: تێچوو، N1، N2، N3 وە ستۆک لە خوارەوەی چەپ بەشێوەی badge
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // تێچوو وەک Pill Badge پەمەیی/سوور
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
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
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'تێچوو: ${Formatters.currency(product.costPrice)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: theme.brightness == Brightness.dark
                                                  ? const Color(0xFFFDA4AF)
                                                  : const Color(0xFFE11D48),
                                              fontFamily: 'Rudaw',
                                            ),
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // ڕیزەکانی N1, N2, N3 بە خاڵی ڕەنگاوڕەنگ و ژمارەی تۆخ
                                      _buildPriceTierRow(
                                        label: 'N1',
                                        price: product.priceN1,
                                        dotColor: const Color(0xFF10B981),
                                        theme: theme,
                                      ),
                                      const SizedBox(height: 4),
                                      _buildPriceTierRow(
                                        label: 'N2',
                                        price: product.priceN2,
                                        dotColor: const Color(0xFFF59E0B),
                                        theme: theme,
                                      ),
                                      const SizedBox(height: 4),
                                      _buildPriceTierRow(
                                        label: 'N3',
                                        price: product.priceN3,
                                        dotColor: const Color(0xFFF43F5E),
                                        theme: theme,
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLowStock
                                            ? AppColors.danger
                                                .withValues(alpha: 0.15)
                                            : AppColors.success
                                                .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isLowStock
                                              ? AppColors.danger
                                              : AppColors.success,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'ستۆک: $totalStock',
                                        style: TextStyle(
                                          color: isLowStock
                                              ? AppColors.danger
                                              : AppColors.success,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Rudaw',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
