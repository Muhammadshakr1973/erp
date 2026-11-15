import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_snackbar.dart';
import '../../../core/components/gardi_logo.dart';
import '../../../core/router/navigation_tabs_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/models/category_model.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/categories_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../products/views/variant_selector_dialog.dart';
import '../providers/customer_cart_provider.dart';

class CustomerCatalogScreen extends ConsumerStatefulWidget {
  final VoidCallback onLogout;

  const CustomerCatalogScreen({super.key, required this.onLogout});

  @override
  ConsumerState<CustomerCatalogScreen> createState() =>
      _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends ConsumerState<CustomerCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(int categoryId, int index, bool isDark) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFFEF4444),
      Color(0xFF6366F1),
      Color(0xFF84CC16),
      Color(0xFFD97706),
      Color(0xFF14B8A6),
      Color(0xFFA855F7),
    ];
    final colorIndex = (categoryId * 3 + index) % colors.length;
    return colors[colorIndex];
  }

  Future<void> _openVariantSelector(
    ProductModel parentProduct,
    List<ProductModel> variants,
  ) async {
    if (variants.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'هیچ جۆرێکی چالاک بۆ ئەم کاڵایە بەردەست نییە',
        type: SnackbarType.warning,
      );
      return;
    }

    final cartNotifier = ref.read(customerCartProvider.notifier);
    final cartState = ref.read(customerCartProvider);

    final initialQuantities = <int, double>{
      for (final v in variants) v.id: cartState.items[v.id] ?? 0.0,
    };

    final updated = await VariantSelectorDialog.show(
      context,
      parentProduct: parentProduct,
      variants: variants,
      initialQuantities: initialQuantities,
      getPrice: cartNotifier.getProductPrice,
      getAvailableStock: cartNotifier.getAvailableStock,
      enforceStockLimit: true,
      initialQuery: _searchQuery,
    );

    if (updated == null || !mounted) return;
    cartNotifier.applyVariantQuantities(variants, updated);
  }

  Future<void> _editQuantityDirectly(ProductModel product) async {
    final cartNotifier = ref.read(customerCartProvider.notifier);
    final cartState = ref.read(customerCartProvider);
    final totalAvailable = cartNotifier.getAvailableStock(product);

    if (totalAvailable <= 0) {
      AppSnackbar.show(
        context,
        message: 'ئەم کاڵایە لە ستۆک بەردەست نییە',
        type: SnackbarType.warning,
      );
      return;
    }

    final currentQty = cartState.items[product.id] ?? 0.0;
    final controller = TextEditingController(
      text: currentQty > 0 ? Formatters.cleanNumberString(currentQty) : '',
    );

    final newQty = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'دیاریکردنی بڕی ${product.name}',
                          style: AppTextStyles.h3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'داخستن',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'ستۆکی بەردەست: ${Formatters.cleanNumberString(totalAvailable)} دانە',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'بڕ (دانە)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final parsed = double.tryParse(controller.text.trim());
                      if (parsed != null && parsed >= 0) {
                        if (parsed > totalAvailable) {
                          AppSnackbar.show(
                            ctx,
                            message:
                                'تەنها ${Formatters.cleanNumberString(totalAvailable)} دانە لە ستۆک بەردەستە',
                            type: SnackbarType.warning,
                          );
                          return;
                        }
                        Navigator.pop(ctx, parsed);
                      } else {
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text(
                      'جێبەجێکردن',
                      style: TextStyle(
                        fontFamily: 'KJino',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (newQty != null && mounted) {
      cartNotifier.setQuantity(product.id, newQty);
    }
  }

  void _showProductImageFullScreen(
    BuildContext context,
    ProductModel product,
  ) {
    final imagePath = product.imagePath?.trim();
    if (imagePath == null || imagePath.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          child: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, _, _) => const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 72,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'وێنەکە بارنەبوو',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontFamily: 'KJino',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: 'داخستن',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 44,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authUser = ref.watch(authProvider.select((s) => s.user));
    final customer = authUser?.customer;
    final allowedIds = (customer?.allowedCategoryIds ?? const <int>[]).toSet();

    final productsAsync = ref.watch(productsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final cartState = ref.watch(customerCartProvider);
    final cartNotifier = ref.read(customerCartProvider.notifier);

    final allProducts = productsAsync.asData?.value ?? const <ProductModel>[];
    final categories =
        categoriesAsync.asData?.value ?? const <CategoryModel>[];
    final categoryMap = {for (final c in categories) c.id: c.name};

    // Active child variants keyed by parentId
    final Map<int, List<ProductModel>> variantsByParent = {};
    for (final p in allProducts) {
      if (p.isActive && p.parentId != null) {
        variantsByParent.putIfAbsent(p.parentId!, () => []).add(p);
      }
    }
    for (final list in variantsByParent.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    // Only active, top-level products belonging to customer's allowed categories
    final displayableProducts = allProducts.where((p) {
      if (!p.isActive || p.isVariant) return false;
      if (p.categoryId == null || !allowedIds.contains(p.categoryId)) {
        return false;
      }

      final children = p.isParent
          ? (variantsByParent[p.id] ?? const <ProductModel>[])
          : const <ProductModel>[];
      if (p.isParent && children.isEmpty) return false;

      if (_searchQuery.isNotEmpty) {
        bool matchesItem(ProductModel item) {
          return item.name.toLowerCase().contains(_searchQuery) ||
              (item.variantName != null &&
                  item.variantName!.toLowerCase().contains(_searchQuery)) ||
              item.barcode.toLowerCase().contains(_searchQuery) ||
              (item.sku ?? '').toLowerCase().contains(_searchQuery);
        }

        return matchesItem(p) || children.any(matchesItem);
      }
      return true;
    }).toList();

    // Group strictly by allowed category ID
    final Map<int, List<ProductModel>> groupedByCat = {};
    for (final p in displayableProducts) {
      final catId = p.categoryId;
      if (catId != null && allowedIds.contains(catId)) {
        groupedByCat.putIfAbsent(catId, () => []).add(p);
      }
    }

    for (final list in groupedByCat.values) {
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    final sortedCatKeys = groupedByCat.keys.toList()
      ..sort((a, b) {
        final nameA = categoryMap[a] ?? '';
        final nameB = categoryMap[b] ?? '';
        return nameA.compareTo(nameB);
      });

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF13171F)
          : const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP HEADER BAR (No order dropdown, no price tier selector)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242E) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF2E3846)
                        : theme.dividerColor.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const GardiLogo(height: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'فرۆشتن بە وێنە',
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (customer != null)
                          Text(
                            customer.name,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (cartState.isSyncing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  InkWell(
                    onTap: () {
                      ref.read(customerPortalTabIndexProvider.notifier).state =
                          1;
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cartState.distinctItemCount > 0
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : (isDark
                                  ? const Color(0xFF2A3442)
                                  : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cartState.distinctItemCount > 0
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : (isDark
                                    ? const Color(0xFF3A4659)
                                    : Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: cartState.distinctItemCount > 0
                                ? AppColors.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'پسوڵە (${cartState.distinctItemCount})',
                            style: TextStyle(
                              fontFamily: 'KJino',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cartState.distinctItemCount > 0
                                  ? AppColors.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.danger,
                    ),
                    tooltip: 'چوونەدەرەوە',
                    onPressed: widget.onLogout,
                  ),
                ],
              ),
            ),

            // 2. SEARCH BAR ONLY (NO category filters!)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              color: isDark ? const Color(0xFF19202B) : Colors.grey.shade50,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'گەڕان بە ناوی کاڵا یان بارکۆد...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF242C38) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF3A4659)
                          : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF3A4659)
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),

            // 3. SYNC ERROR BANNER IF ANY
            if (cartState.error != null)
              Container(
                width: double.infinity,
                color: AppColors.danger.withValues(alpha: 0.14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cartState.error!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => cartNotifier.flushSync(),
                      child: const Text('دووبارە هەوڵبدەرەوە'),
                    ),
                  ],
                ),
              ),

            // 4. PRODUCT CATALOG GRID GROUPED BY ALLOWED CATEGORIES
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(productsListProvider.notifier)
                      .refreshProductsSilently();
                  ref.invalidate(categoriesListProvider);
                },
                child: productsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'هەڵە لە هێنانی کاڵاکان: $err',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref
                                .read(productsListProvider.notifier)
                                .fetchProducts(),
                            child: const Text('دووبارە هەوڵبدەرەوە'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (_) {
                    if (allowedIds.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 64,
                                color: AppColors.warning,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'هیچ کاتیگۆرییەک بۆ هەژمارەکەت دیاری نەکراوە',
                                style: AppTextStyles.h3,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (displayableProducts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: theme.colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'هیچ کاڵایەک نەدۆزرایەوە',
                              style: AppTextStyles.h3,
                            ),
                            if (_searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: () => _searchController.clear(),
                                child: const Text('سڕینەوەی گەڕان'),
                              ),
                          ],
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth < 600
                            ? 2
                            : constraints.maxWidth < 950
                            ? 3
                            : 4;

                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: sortedCatKeys.length,
                          itemBuilder: (context, catIndex) {
                            final catId = sortedCatKeys[catIndex];
                            final productsInGroup = groupedByCat[catId]!;
                            final catName = categoryMap[catId] ?? 'کاتیگۆری';
                            final frameColor = _getCategoryColor(
                              catId,
                              catIndex,
                              isDark,
                            );

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: frameColor.withValues(
                                  alpha: isDark ? 0.08 : 0.04,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: frameColor.withValues(
                                    alpha: isDark ? 0.85 : 0.75,
                                  ),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: frameColor.withValues(
                                      alpha: isDark ? 0.18 : 0.1,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: frameColor.withValues(
                                          alpha: isDark ? 0.24 : 0.14,
                                        ),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: frameColor.withValues(
                                              alpha: isDark ? 0.45 : 0.35,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: frameColor.withValues(
                                                alpha: 0.2,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.category_rounded,
                                              size: 18,
                                              color: frameColor,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              catName,
                                              style: TextStyle(
                                                fontFamily: 'KJino',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: frameColor,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${productsInGroup.length} کاڵا',
                                              style: const TextStyle(
                                                fontFamily: 'KJino',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: crossAxisCount,
                                              childAspectRatio: 0.68,
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10,
                                            ),
                                        itemCount: productsInGroup.length,
                                        itemBuilder: (context, index) {
                                          final product =
                                              productsInGroup[index];
                                          final variants = product.isParent
                                              ? (variantsByParent[product.id] ??
                                                    const <ProductModel>[])
                                              : const <ProductModel>[];
                                          final qtyInCart = product.isParent
                                              ? variants.fold<double>(
                                                  0,
                                                  (sum, v) =>
                                                      sum +
                                                      (cartState.items[v.id] ??
                                                          0.0),
                                                )
                                              : (cartState.items[product.id] ??
                                                    0.0);

                                          return _buildProductCard(
                                            context,
                                            key: ValueKey(product.id),
                                            product: product,
                                            variants: variants,
                                            quantity: qtyInCart,
                                            cartNotifier: cartNotifier,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context, {
    required Key key,
    required ProductModel product,
    required List<ProductModel> variants,
    required double quantity,
    required CustomerCartNotifier cartNotifier,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isParentCard = product.isParent && variants.isNotEmpty;

    double unitPrice = cartNotifier.getProductPrice(product);
    double? minVariantPrice;
    double? maxVariantPrice;
    if (isParentCard) {
      final prices = variants.map(cartNotifier.getProductPrice).toList()
        ..sort();
      minVariantPrice = prices.first;
      maxVariantPrice = prices.last;
      unitPrice = minVariantPrice;
    }

    final double totalAvailable = isParentCard
        ? variants.fold<double>(
            0.0,
            (s, v) => s + cartNotifier.getAvailableStock(v),
          )
        : cartNotifier.getAvailableStock(product);

    final double remainingStock = isParentCard
        ? variants.fold<double>(
            0.0,
            (s, v) => s + cartNotifier.getRemainingStock(v),
          )
        : cartNotifier.getRemainingStock(product);

    final bool isOutOfStock = totalAvailable <= 0;
    final bool isLimitReached = remainingStock <= 0;
    final bool canIncrement = remainingStock > 0;
    final bool canDecrement = quantity > 0;
    final bool isInCart = quantity > 0;
    final bool isStockDepleted = isOutOfStock || isLimitReached;

    final Color borderColor = isStockDepleted
        ? (isDark ? const Color(0xFFFE3F30) : const Color(0xFFE53935))
        : (isInCart
              ? (isDark ? const Color(0xFF00E676) : const Color(0xFF10B981))
              : (isDark ? const Color(0xFF333E4F) : Colors.grey.shade300));

    final double borderWidth = (isStockDepleted || isInCart) ? 2.2 : 1.0;

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242C38) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (product.imagePath != null &&
                          product.imagePath!.trim().isNotEmpty)
                      ? MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                _showProductImageFullScreen(context, product),
                            child: Image.network(
                              product.imagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _buildPlaceholderImage(),
                            ),
                          ),
                        )
                      : _buildPlaceholderImage(),
                  if (isInCart)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFF0A9C6E))
                                  .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'لە پسوڵەدایە',
                              style: TextStyle(
                                fontFamily: 'KJino',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isParentCard)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.layers_outlined,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${variants.length} جۆر',
                              style: const TextStyle(
                                fontFamily: 'KJino',
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isOutOfStock || isLimitReached)
                            ? const Color(0xFFB71C1C).withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ستۆک: ${Formatters.cleanNumberString(remainingStock)}',
                        style: const TextStyle(
                          fontFamily: 'KJino',
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: 13,
                    fontFamily: 'KJino',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        (isParentCard &&
                                minVariantPrice != null &&
                                maxVariantPrice != null &&
                                minVariantPrice != maxVariantPrice)
                            ? '${Formatters.currency(minVariantPrice)} - ${Formatters.currency(maxVariantPrice)}'
                            : Formatters.currency(unitPrice),
                        style: TextStyle(
                          fontFamily: 'KJino',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isParentCard &&
                        cartNotifier.hasSpecialPrice(product)) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber.shade700,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'تایبەت',
                          style: TextStyle(
                            fontFamily: 'KJino',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B212B) : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canDecrement
                          ? const Color(0xFFE53935)
                          : (isDark
                                ? const Color(0xFF2E3846)
                                : Colors.grey.shade300),
                      foregroundColor: canDecrement
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.grey.shade500),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: canDecrement
                        ? () => isParentCard
                              ? _openVariantSelector(product, variants)
                              : cartNotifier.decrementProduct(product.id)
                        : null,
                    child: const Icon(Icons.remove, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: isParentCard
                        ? () => _openVariantSelector(product, variants)
                        : (isOutOfStock
                              ? () {
                                  AppSnackbar.show(
                                    context,
                                    message: 'ئەم کاڵایە لە ستۆک بەردەست نییە',
                                    type: SnackbarType.warning,
                                  );
                                }
                              : () => _editQuantityDirectly(product)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E3846) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF435064)
                              : Colors.grey.shade300,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        Formatters.cleanNumberString(quantity),
                        style: TextStyle(
                          fontFamily: 'KJino',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: quantity > 0
                              ? (isDark ? Colors.white : AppColors.primary)
                              : (isDark ? Colors.white54 : Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canIncrement
                          ? const Color(0xFF10B981)
                          : (isDark
                                ? const Color(0xFF2E3846)
                                : Colors.grey.shade300),
                      foregroundColor: canIncrement
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.grey.shade500),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: canIncrement
                        ? () {
                            if (isParentCard) {
                              _openVariantSelector(product, variants);
                            } else {
                              final warn = cartNotifier.incrementProduct(
                                product,
                              );
                              if (warn != null && mounted) {
                                AppSnackbar.show(
                                  context,
                                  message: warn,
                                  type: SnackbarType.warning,
                                );
                              }
                            }
                          }
                        : (isParentCard && quantity > 0
                              ? () => _openVariantSelector(product, variants)
                              : null),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
