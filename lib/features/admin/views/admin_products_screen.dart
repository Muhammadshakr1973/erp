import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/providers/products_provider.dart';
import '../../products/providers/categories_provider.dart';
import '../../products/views/product_form_dialog.dart';
import '../../products/models/product_model.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, ProductModel product) {
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
            child: const Text('بەڵێ', style: TextStyle(color: AppColors.danger)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('کاڵاکان و کۆگا', style: AppTextStyles.h2),
        actions: [
          IconButton(
              icon: const Icon(AppIcons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ProductFormDialog(),
                );
              }),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(productsListProvider)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
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
                    borderRadius: BorderRadius.circular(24), // Matches AppTextField
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                  ),
                  child: IconButton(
                    icon: const Icon(AppIcons.scan),
                    onPressed: () {
                      CameraBarcodeScanner.show(context, (scannedBarcode) {
                        setState(() {
                          _searchController.text = scannedBarcode;
                        });
                        ref.read(productSearchProvider.notifier).search(scannedBarcode);
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ChoiceChip(
                        label: const Text('هەموو جۆرەکان'),
                        selected: selectedCategory == null,
                        onSelected: (_) {
                          ref.read(selectedCategoryFilterProvider.notifier).state = null;
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
                            ref.read(selectedCategoryFilterProvider.notifier).state =
                                selected ? c.id : null;
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
                error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا: $error')),
                data: (products) {
                  if (products.isEmpty) {
                    return const Center(child: Text('هیچ کاڵایەک نییە'));
                  }

                  if (isDesktop) {
                    final int crossAxisCount = screenWidth > 1200 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.sm,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: screenWidth > 1200 ? 3.0 : 2.6,
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
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ProductFormDialog(product: product),
                            );
                          },
                          onLongPress: () => _showDeleteDialog(context, ref, product),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  children: [
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
                                          if ((product.unit != null && product.unit != 'دانە') || (product.sku != null && product.sku!.isNotEmpty)) ...[
                                            Text(
                                              [
                                                if (product.unit != null && product.unit != 'دانە') '${product.unit} = ${product.unitsPerCarton} دانە',
                                                if (product.sku != null && product.sku!.isNotEmpty) 'SKU: ${product.sku}',
                                              ].join(' • '),
                                              style: AppTextStyles.caption.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                          ],
                                          Text(
                                            'بارکۆد: ${product.barcode}',
                                            style: AppTextStyles.caption.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('${product.costPrice.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                                        Text('${product.priceN1.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                                        Text('${product.priceN2.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.orange.shade600)),
                                        Text('${product.priceN3.toInt()}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade600)),
                                      ],
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: StatusBadge(
                                  label: 'ستۆک: $totalStock',
                                  type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  // Mobile Layout (Standard list view)
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                    itemCount: products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      int totalStock = 0;
                      for (var stock in product.stocks) {
                        totalStock += (stock['quantity'] as int?) ?? 0;
                      }

                      final bool isLowStock = totalStock < 20;

                      return AppCard(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => ProductFormDialog(product: product),
                          );
                        },
                        onLongPress: () => _showDeleteDialog(context, ref, product),
                        child: Stack(
                          children: [
                            Row(
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
                                      Text(product.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(
                                        'جۆر: ${product.category?['name'] ?? '-'} • سەپڵایەر: ${product.supplier?['name'] ?? '-'}',
                                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      if ((product.unit != null && product.unit != 'دانە') || (product.sku != null && product.sku!.isNotEmpty)) ...[
                                        Text(
                                          [
                                            if (product.unit != null && product.unit != 'دانە') '${product.unit} = ${product.unitsPerCarton} دانە',
                                            if (product.sku != null && product.sku!.isNotEmpty) 'SKU: ${product.sku}',
                                          ].join(' • '),
                                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        'بارکۆد: ${product.barcode}',
                                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${product.costPrice.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                                    Text('${product.priceN1.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                                    Text('${product.priceN2.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade600)),
                                    Text('${product.priceN3.toInt()}', style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade600)),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.md),
                              ],
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: StatusBadge(
                                label: 'ستۆک: $totalStock',
                                type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
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
