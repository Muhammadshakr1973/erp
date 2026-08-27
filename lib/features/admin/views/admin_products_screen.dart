import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      mainAxisExtent: 160,
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
                            builder: (context) => ProductFormDialog(product: product),
                          );
                        },
                        onLongPress: () => _showDeleteDialog(context, ref, product),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: (product.imagePath != null && product.imagePath!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        product.imagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.inventory_2_outlined,
                                          color: theme.colorScheme.primary,
                                          size: 28,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.inventory_2_outlined,
                                      color: theme.colorScheme.primary,
                                      size: 28,
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
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'جۆر: ${product.category?['name'] ?? '-'} • کۆمپانیا: ${product.supplier?['name'] ?? '-'}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'بارکۆد: ${product.barcode}${product.sku != null && product.sku!.isNotEmpty ? ' • SKU: ${product.sku}' : ''}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  if (product.unit != null && product.unit != 'دانە') ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'یەکە: ${product.unit} = ${product.unitsPerCarton} دانە',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'تێچوو: ${product.costPrice.toInt()} د.ع',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isLowStock
                                        ? AppColors.danger.withValues(alpha: 0.1)
                                        : AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${product.priceN1.toInt()} د.ع',
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: isLowStock ? AppColors.danger : AppColors.success,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isLowStock ? AppColors.danger : AppColors.success,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'ستۆک: $totalStock',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Rudaw',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'نرخ٢: ${product.priceN2.toInt()} د.ع • نرخ٣: ${product.priceN3.toInt()} د.ع',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
