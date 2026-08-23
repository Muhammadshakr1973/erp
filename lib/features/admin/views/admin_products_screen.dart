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

class _AdminState extends ConsumerState<AdminProductsScreen> {} // dummy for type safety if needed, but standard is:

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
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر'),
          ),
          TextButton(
            onPressed: () {
              ref.read(productActionsProvider).deleteProduct(product.id);
              Navigator.pop(context);
            },
            child: const Text('بەڵێ', style: TextStyle(color: AppColors.danger)),
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
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.6)),
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
            error: (_, __) => const SizedBox.shrink(),
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
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withOpacity(0.5),
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
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Column(
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
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.danger, size: 22),
                                  onPressed: () => _showDeleteDialog(context, ref, product),
                                ),
                              ],
                            ),
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
                        child: Row(
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
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${product.priceN1.toInt()} د.ع', style: AppTextStyles.price),
                                const SizedBox(height: 4),
                                StatusBadge(
                                  label: 'ستۆک: $totalStock',
                                  type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.danger),
                              onPressed: () => _showDeleteDialog(context, ref, product),
                            )
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
