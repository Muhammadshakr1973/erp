import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/router/navigation_tabs_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/products_provider.dart';
import '../providers/customer_cart_provider.dart';
import '../widgets/customer_profile_menu_button.dart';

class CustomerInvoiceScreen extends ConsumerWidget {
  final VoidCallback onLogout;

  const CustomerInvoiceScreen({super.key, required this.onLogout});

  Future<void> _confirmRemoveItem(
    BuildContext context,
    WidgetRef ref, {
    required int productId,
    required String itemName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    const Expanded(
                      child: Text('سڕینەوەی کاڵا', style: AppTextStyles.h3),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'داخستن',
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'دڵنیایت لە سڕینەوەی "$itemName" لە پسوڵەکە؟',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(
                    'بەڵێ، بسڕەوە',
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
      ),
    );

    if (confirmed == true) {
      ref.read(customerCartProvider.notifier).removeProduct(productId);
    }
  }

  Future<void> _handleCompleteOrder(BuildContext context, WidgetRef ref) async {
    try {
      final orderNum = await ref
          .read(customerCartProvider.notifier)
          .completeOrder();
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'پسوڵەی #$orderNum بە سەرکەوتوویی نێردرا بۆ کۆگا',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: Formatters.cleanError(e),
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authUser = ref.watch(authProvider.select((s) => s.user));
    final customer = authUser?.customer;
    final cartState = ref.watch(customerCartProvider);
    final cartNotifier = ref.read(customerCartProvider.notifier);

    final productsList =
        ref.watch(productsListProvider).asData?.value ?? const <ProductModel>[];
    final productMap = {for (final p in productsList) p.id: p};

    final draftOrder = cartState.activeDraftOrder;
    final Map<int, OrderItemModel> draftItemMap = {
      if (draftOrder != null)
        for (final item in draftOrder.items) item.productId: item,
    };

    final activeEntries =
        cartState.items.entries.where((e) => e.value > 0).toList();

    final bool useServerTotals =
        draftOrder != null && !cartState.hasPendingChanges && !cartState.isSyncing;

    final double subtotal = useServerTotals
        ? draftOrder.subtotal
        : cartNotifier.computeSubtotal(productMap);
    final double permDiscountPercent = useServerTotals
        ? draftOrder.permanentDiscountPercent
        : (customer?.permanentDiscount ?? 0.0);
    final double permDiscountAmount = useServerTotals
        ? draftOrder.permanentDiscountAmount
        : cartNotifier.computePermanentDiscountAmount(subtotal);
    final double grandTotal = useServerTotals
        ? draftOrder.totalAmount
        : (subtotal - permDiscountAmount).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF13171F)
          : const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER BAR
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
                  CustomerProfileMenuButton(onLogout: onLogout),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'پسوڵە',
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (draftOrder != null && draftOrder.orderNumber.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${draftOrder.orderNumber}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  if (cartState.isSyncing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),

            // 2. ERROR BANNER IF ANY
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

            // 3. ITEMS LIST OR EMPTY / COMPLETED STATE
            Expanded(
              child: activeEntries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (cartState.lastCompletedOrderNumber != null &&
                                cartState
                                    .lastCompletedOrderNumber!
                                    .isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 64,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Text(
                                'پسوڵە بە سەرکەوتوویی نێردرا بۆ کۆگا',
                                style: AppTextStyles.h3,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ژمارەی پسوڵە: #${cartState.lastCompletedOrderNumber}',
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppButton(
                                text: 'گەڕانەوە بۆ فرۆشتن بە وێنە',
                                icon: Icons.storefront_outlined,
                                onPressed: () {
                                  ref
                                          .read(
                                            customerPortalTabIndexProvider
                                                .notifier,
                                          )
                                          .state =
                                      0;
                                },
                              ),
                            ] else ...[
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 68,
                                color: theme.colorScheme.outlineVariant,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Text(
                                'هیچ کاڵایەک لە پسوڵەدا نییە',
                                style: AppTextStyles.h3,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'لە پەڕەی فرۆشتن بە وێنە کاڵاکان هەڵبژێرە بۆ دروستبوونی پسوڵە',
                                style: AppTextStyles.caption,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppButton(
                                text: 'فرۆشتن بە وێنە',
                                icon: Icons.storefront_outlined,
                                onPressed: () {
                                  ref
                                          .read(
                                            customerPortalTabIndexProvider
                                                .notifier,
                                          )
                                          .state =
                                      0;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: activeEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = activeEntries[index];
                        final productId = entry.key;
                        final qty = entry.value;
                        final product = productMap[productId];
                        final draftItem = draftItemMap[productId];

                        final String itemName =
                            product?.name ??
                            draftItem?.productName ??
                            'کاڵا #$productId';
                        final String? imagePath =
                            product?.imagePath ?? draftItem?.productImagePath;
                        final double unitPrice = product != null
                            ? cartNotifier.getProductPrice(product)
                            : (draftItem?.unitPrice ?? 0.0);
                        final double lineTotal = unitPrice * qty;

                        final double maxAvailable = product != null
                            ? cartNotifier.getAvailableStock(product)
                            : cartNotifier.getSavedQuantityInDraft(productId);
                        final bool canIncrement =
                            product != null && (maxAvailable - qty) > 1e-6;

                        return GestureDetector(
                          onLongPress: () => _confirmRemoveItem(
                            context,
                            ref,
                            productId: productId,
                            itemName: itemName,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF242C38)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF333E4F)
                                    : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: isDark
                                        ? const Color(0xFF1B212B)
                                        : Colors.grey.shade100,
                                    child:
                                        (imagePath != null &&
                                            imagePath.trim().isNotEmpty)
                                        ? Image.network(
                                            imagePath,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Icon(
                                              Icons.inventory_2_outlined,
                                              color: Colors.grey.shade400,
                                            ),
                                          )
                                        : Icon(
                                            Icons.inventory_2_outlined,
                                            color: Colors.grey.shade400,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: AppTextStyles.bodyBold,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'نرخ: ${Formatters.currency(unitPrice)}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'کۆ: ${Formatters.currency(lineTotal)}',
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'بۆ سڕینەوە پەنجەی لەسەر ڕابگرە',
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 10,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.ltr,
                                  children: [
                                    SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFE53935,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => cartNotifier
                                            .decrementProduct(productId),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 38,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        Formatters.cleanNumberString(qty),
                                        style: AppTextStyles.bodyBold.copyWith(
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: canIncrement
                                              ? const Color(0xFF10B981)
                                              : (isDark
                                                    ? const Color(0xFF2E3846)
                                                    : Colors.grey.shade300),
                                          foregroundColor: canIncrement
                                              ? Colors.white
                                              : (isDark
                                                    ? Colors.white38
                                                    : Colors.grey.shade500),
                                          padding: EdgeInsets.zero,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: canIncrement
                                            ? () {
                                                final warn = cartNotifier
                                                    .incrementProduct(product);
                                                if (warn != null &&
                                                    context.mounted) {
                                                  AppSnackbar.show(
                                                    context,
                                                    message: warn,
                                                    type: SnackbarType.warning,
                                                  );
                                                }
                                              }
                                            : null,
                                        child: const Icon(Icons.add, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 4. BOTTOM SUMMARY & COMPLETE ORDER BUTTON
            if (activeEntries.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E242E) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF2E3846)
                          : theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (permDiscountAmount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'کۆی گشتی کاڵاکان',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            Formatters.currency(subtotal),
                            style: AppTextStyles.bodyBold,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'داشکاندنی هەمیشەیی (${Formatters.cleanNumberString(permDiscountPercent)}%)',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            '-${Formatters.currency(permDiscountAmount)}',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.success,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('کۆی پسوڵە', style: AppTextStyles.h2),
                        Text(
                          Formatters.currency(grandTotal),
                          style: AppTextStyles.priceLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      text: 'تەواوکردنی پسوڵە',
                      icon: Icons.check_circle_outline_rounded,
                      width: double.infinity,
                      isLoading: cartState.isCompleting,
                      onPressed: cartState.isCompleting
                          ? null
                          : () => _handleCompleteOrder(context, ref),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
