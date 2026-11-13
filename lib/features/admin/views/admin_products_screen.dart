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
import '../../products/models/product_model.dart';
import '../../products/models/category_model.dart';
import '../../products/views/barcode_generator_dialog.dart';

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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('سڕینەوەی کاڵا'),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
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
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            fontFamily: 'KJino',
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontFamily: 'KJino',
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 6.5,
          height: 6.5,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(
    BuildContext context,
    ThemeData theme,
    int? selectedCategory,
    List<CategoryModel> categories,
    List<ProductModel> allProducts,
  ) {
    final int countNoCategory =
        allProducts.where((p) => p.categoryId == null).length;

    final bool hasValidSelection = selectedCategory == null ||
        selectedCategory == -1 ||
        categories.any((c) => c.id == selectedCategory);
    final int? effectiveValue = hasValidSelection ? selectedCategory : null;
    final bool isFiltered = effectiveValue != null;

    DropdownMenuItem<int?> buildCatItem(
      int? val,
      String label,
      int count,
    ) {
      final isSelected = effectiveValue == val;
      return DropdownMenuItem<int?>(
        value: val,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontFamily: 'KJino',
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                    fontFamily: 'KJino',
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final List<String> closedLabels = [
      'هەموو جۆرەکان',
      'بێ جۆر',
      ...categories.map((c) => c.name),
    ];

    return Container(
      height: 38,
      color: isFiltered
          ? theme.colorScheme.primary.withValues(alpha: 0.14)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: effectiveValue,
          isExpanded: true,
          isDense: true,
          dropdownColor: theme.colorScheme.surface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isFiltered
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          selectedItemBuilder: (context) => closedLabels
              .map(
                (label) => Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                      color: isFiltered
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontFamily: 'KJino',
                    ),
                  ),
                ),
              )
              .toList(),
          items: [
            buildCatItem(null, 'هەموو جۆرەکان', 0),
            buildCatItem(-1, 'بێ جۆر', countNoCategory),
            ...categories.map((c) {
              final catCount =
                  allProducts.where((p) => p.categoryId == c.id).length;
              return buildCatItem(c.id, c.name, catCount);
            }),
          ],
          onChanged: (val) {
            ref.read(selectedCategoryFilterProvider.notifier).state = val;
          },
        ),
      ),
    );
  }

  Widget _buildStatusFilterDropdown(
    BuildContext context,
    ThemeData theme,
    String selectedStatusFilter,
    List<ProductModel> allProducts,
  ) {
    final isFiltered = selectedStatusFilter != 'all';

    final int countNoImage = allProducts
        .where((p) => p.imagePath == null || p.imagePath!.trim().isEmpty)
        .length;

    final int countMissingPrice = allProducts
        .where((p) =>
            p.costPrice <= 0 ||
            p.priceN1 <= 0 ||
            p.priceN2 <= 0 ||
            p.priceN3 <= 0)
        .length;

    final int countNoSupplier =
        allProducts.where((p) => p.supplierId == null).length;

    final int countNoBarcode =
        allProducts.where((p) => p.barcode.trim().isEmpty).length;

    final int countNoUnit = allProducts
        .where((p) => p.unit == null || p.unit!.trim().isEmpty)
        .length;

    DropdownMenuItem<String> buildMenuItem(
      String value,
      String label,
      IconData defaultIcon,
      int count,
    ) {
      final isSelected = selectedStatusFilter == value;
      return DropdownMenuItem<String>(
        value: value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Icon(
              defaultIcon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontFamily: 'KJino',
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                    fontFamily: 'KJino',
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    const List<String> statusLabels = [
      'هەموو کاڵاکان',
      'بێ وێنە',
      'نرخەکان',
      'بێ کۆمپانیا',
      'بێ بارکۆد',
      'بێ یەکە',
    ];

    return Container(
      height: 38,
      color: isFiltered
          ? theme.colorScheme.primary.withValues(alpha: 0.14)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedStatusFilter,
          isExpanded: true,
          isDense: true,
          dropdownColor: theme.colorScheme.surface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isFiltered
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          selectedItemBuilder: (context) => statusLabels
              .map(
                (label) => Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                      color: isFiltered
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontFamily: 'KJino',
                    ),
                  ),
                ),
              )
              .toList(),
          items: [
            buildMenuItem(
              'all',
              'هەموو کاڵاکان',
              Icons.inventory_2_outlined,
              0,
            ),
            buildMenuItem(
              'no_image',
              'بێ وێنە',
              Icons.image_not_supported_outlined,
              countNoImage,
            ),
            buildMenuItem(
              'missing_price',
              'نرخەکان',
              Icons.monetization_on_outlined,
              countMissingPrice,
            ),
            buildMenuItem(
              'no_supplier',
              'بێ کۆمپانیا',
              Icons.business_outlined,
              countNoSupplier,
            ),
            buildMenuItem(
              'no_barcode',
              'بێ بارکۆد',
              Icons.qr_code_scanner_outlined,
              countNoBarcode,
            ),
            buildMenuItem(
              'no_unit',
              'بێ یەکە',
              Icons.straighten_outlined,
              countNoUnit,
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              ref.read(productStatusFilterProvider.notifier).state = val;
            }
          },
        ),
      ),
    );
  }

  Widget _buildStockFilterButton(
    BuildContext context,
    ThemeData theme,
    StockQuantityFilter stockFilter,
  ) {
    final bool isFiltered = stockFilter.isActive;
    String closedLabel = 'بڕی ستۆک';
    if (isFiltered) {
      final numStr = Formatters.cleanNumberString(stockFilter.threshold);
      closedLabel = stockFilter.mode == StockFilterMode.lessThan
          ? 'کەمتر لە $numStr'
          : 'زیاتر لە $numStr';
    }

    return InkWell(
      onTap: () => _showStockFilterDialog(
        context,
        isFiltered ? stockFilter.mode : StockFilterMode.lessThan,
      ),
      child: Container(
        height: 38,
        color: isFiltered
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  closedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                    color: isFiltered
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontFamily: 'KJino',
                  ),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isFiltered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showStockFilterDialog(BuildContext context, StockFilterMode initialMode) {
    final currentFilter = ref.read(productStockFilterProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StockFilterInputDialog(
        initialMode: initialMode,
        initialThreshold: currentFilter.threshold,
        isFiltered: currentFilter.isActive,
        onApply: (mode, threshold) {
          ref.read(productStockFilterProvider.notifier).state =
              StockQuantityFilter(mode: mode, threshold: threshold);
        },
        onClear: () {
          ref.read(productStockFilterProvider.notifier).state =
              const StockQuantityFilter();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(filteredProductsProvider);
    final allProducts = ref.watch(productsListProvider).valueOrNull ?? [];
    final categoriesAsync = ref.watch(categoriesListProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final statusFilter = ref.watch(productStatusFilterProvider);
    final stockFilter = ref.watch(productStockFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کاڵاکان و کۆگا', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.barcode_reader),
            tooltip: 'دروستکردنی بارکۆد',
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const BarcodeGeneratorDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'بەڕێوەبردنی جۆرەکان',
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
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
                barrierDismissible: false,
                builder: (context) => const ProductFormDialog(),
              );
            },
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
                      CameraBarcodeScanner.show(
                        context,
                        (scannedBarcode) {
                          setState(() {
                            _searchController.text = scannedBarcode;
                          });
                          ref
                              .read(productSearchProvider.notifier)
                              .search(scannedBarcode);
                        },
                        closeOnScan: true,
                      );
                    },
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (selectedCategory != null ||
                          statusFilter != 'all' ||
                          stockFilter.isActive)
                      ? theme.colorScheme.primary.withValues(alpha: 0.7)
                      : theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Row(
                  children: [
                    // 1. Dropdown for Category filter
                    Expanded(
                      child: categoriesAsync.when(
                        data: (categories) => _buildCategoryDropdown(
                          context,
                          theme,
                          selectedCategory,
                          categories,
                          allProducts,
                        ),
                        loading: () => _buildCategoryDropdown(
                          context,
                          theme,
                          selectedCategory,
                          [],
                          allProducts,
                        ),
                        error: (_, _) => _buildCategoryDropdown(
                          context,
                          theme,
                          selectedCategory,
                          [],
                          allProducts,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                    // 2. Dropdown for Status filters
                    Expanded(
                      child: _buildStatusFilterDropdown(
                        context,
                        theme,
                        statusFilter,
                        allProducts,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                    // 3. Button for Stock quantity filter (opens input dialog directly)
                    Expanded(
                      child: _buildStockFilterButton(
                        context,
                        theme,
                        stockFilter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

                  final allProducts = ref.watch(productsListProvider).valueOrNull ?? [];

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.sm,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      mainAxisExtent: 130,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final List<ProductModel> childVariants = product.isParent
                          ? allProducts.where((p) => p.parentId == product.id).toList()
                          : const [];
                      final double totalStock = product.isParent
                          ? childVariants.fold<double>(0.0, (s, c) => s + c.totalStock)
                          : product.totalStock;
                      final double minStock = product.isParent
                          ? childVariants.fold<double>(0.0, (s, c) => s + c.minStockLevel)
                          : product.minStockLevel;
                      final bool isLowStock = product.isParent
                          ? (childVariants.isNotEmpty && childVariants.any((c) => c.isLowStock))
                          : product.isLowStock;

                      return AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 9.0,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) =>
                                ProductFormDialog(product: product),
                          );
                        },
                        onLongPress: () =>
                            _showDeleteDialog(context, ref, product),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ستونی یەکەم: وێنە لە سەرەوە (top right)، پاشان (جۆر، کۆمپانیا، SKU) بەشێوەی ستونی
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: (product.imagePath != null &&
                                            product.imagePath!.isNotEmpty)
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(
                                              product.imagePath!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Icon(
                                                Icons.inventory_2_outlined,
                                                color: theme
                                                    .colorScheme.primary,
                                                size: 24,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.inventory_2_outlined,
                                            color: theme.colorScheme.primary,
                                            size: 24,
                                          ),
                                  ),
                                  const SizedBox(height: 4),
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
                            // ستونی دووەم: ناوی کاڵا، بارکۆد، یەکە، ستۆک
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    product.name,
                                    style: AppTextStyles.bodyBold.copyWith(
                                      fontSize: 14,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (product.isParent)
                                    Text(
                                      '${childVariants.length} جۆر: ${childVariants.take(3).map((v) => v.displayVariantLabel).join('، ')}${childVariants.length > 3 ? '...' : ''}',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  else
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
                                    const SizedBox(height: 2),
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
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2.5,
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
                                      minStock > 0
                                          ? 'ستۆک: $totalStock (کەمترین: $minStock)'
                                          : 'ستۆک: $totalStock',
                                      style: TextStyle(
                                        color: isLowStock
                                            ? AppColors.danger
                                            : AppColors.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'KJino',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // ستونی سێیەم: تێچوو، N1، N2، N3
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // تێچوو وەک Pill Badge پەمەیی/سوور
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
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
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: theme.brightness == Brightness.dark
                                              ? const Color(0xFFFDA4AF)
                                              : const Color(0xFFE11D48),
                                          fontFamily: 'KJino',
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  // ڕیزەکانی N1, N2, N3 بە خاڵی ڕەنگاوڕەنگ و ژمارەی تۆخ
                                  _buildPriceTierRow(
                                    label: 'N1',
                                    price: product.priceN1,
                                    dotColor: const Color(0xFF10B981),
                                    theme: theme,
                                  ),
                                  const SizedBox(height: 2.5),
                                  _buildPriceTierRow(
                                    label: 'N2',
                                    price: product.priceN2,
                                    dotColor: const Color(0xFFF59E0B),
                                    theme: theme,
                                  ),
                                  const SizedBox(height: 2.5),
                                  _buildPriceTierRow(
                                    label: 'N3',
                                    price: product.priceN3,
                                    dotColor: const Color(0xFFF43F5E),
                                    theme: theme,
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

class _StockFilterInputDialog extends StatefulWidget {
  final StockFilterMode initialMode;
  final double? initialThreshold;
  final bool isFiltered;
  final void Function(StockFilterMode mode, double threshold) onApply;
  final VoidCallback onClear;

  const _StockFilterInputDialog({
    required this.initialMode,
    this.initialThreshold,
    this.isFiltered = false,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_StockFilterInputDialog> createState() =>
      _StockFilterInputDialogState();
}

class _StockFilterInputDialogState extends State<_StockFilterInputDialog> {
  late StockFilterMode _mode;
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == StockFilterMode.all
        ? StockFilterMode.lessThan
        : widget.initialMode;
    _controller = TextEditingController(
      text: widget.initialThreshold != null
          ? Formatters.cleanNumberString(widget.initialThreshold)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalizeDigits(String input) {
    const easternArabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input.trim();
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(easternArabic[i], '$i');
      result = result.replaceAll(persian[i], '$i');
    }
    return result;
  }

  void _submit() {
    final normalized = _normalizeDigits(_controller.text);
    if (normalized.isEmpty && widget.isFiltered) {
      widget.onClear();
      Navigator.pop(context);
      return;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      setState(() {
        _errorText = 'تکایە ژمارەیەکی دروست بنووسە';
      });
      return;
    }
    widget.onApply(_mode, parsed);
    Navigator.pop(context);
  }

  Widget _buildModeOption(
    ThemeData theme,
    StockFilterMode mode,
    String label,
    IconData icon,
  ) {
    final isSelected = _mode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontFamily: 'KJino',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text('فلتەری بڕی ستۆک', style: AppTextStyles.h3),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildModeOption(
                theme,
                StockFilterMode.lessThan,
                'کەمتر لە',
                Icons.trending_down_rounded,
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildModeOption(
                theme,
                StockFilterMode.greaterThan,
                'زیاتر لە',
                Icons.trending_up_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _controller,
            labelText: _mode == StockFilterMode.lessThan
                ? 'ستۆک کەمتر بێت لە'
                : 'ستۆک زیاتر بێت لە',
            hintText: 'بۆ نموونە: 10',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: _errorText,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
          if (widget.isFiltered) ...[
            const SizedBox(height: AppSpacing.md),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                widget.onClear();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 9,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.filter_alt_off_outlined,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'هەموو ستۆکەکان (لابردنی فلتەر)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                        fontFamily: 'KJino',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          text: 'جێبەجێکردن',
          onPressed: _submit,
        ),
      ],
    );
  }
}
