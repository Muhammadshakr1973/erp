import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/warehouse_provider.dart';

class OrdersToPackScreen extends ConsumerWidget {
  const OrdersToPackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersToPackProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('پسوڵەکانی پاکەتکردن', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(ordersToPackProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersToPackProvider);
          await ref.read(ordersToPackProvider.future);
        },
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'کێشەیەک ڕوویدا لە بارکردنی پسوڵەکان',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    err.toString().replaceAll('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(ordersToPackProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('دووبارە هەوڵبدەرەوە'),
                  ),
                ],
              ),
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.orderStatus,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'هیچ پسوڵەیەک نییە بۆ پاکەتکردن',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'هەموو پسوڵە پشتڕاستکراوەکان پاکەتکراون.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: orders.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final order = orders[index];
                final int totalItems = order.items.fold(
                  0,
                  (sum, item) => sum + item.quantity,
                );
                final int packedItems = order.items
                    .where((e) => e.isPacked)
                    .length;

                final StatusBadgeType badgeType = order.status == 'PACKING'
                    ? StatusBadgeType.warning
                    : StatusBadgeType.info;

                final String badgeLabel = order.status == 'PACKING'
                    ? 'لە پاکەتکردندایە'
                    : 'پشتڕاستکراوە';

                return AppCard(
                  onTap: () {
                    context.push('/pack-order/${order.id}');
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            AppIcons.orderStatus,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'پسوڵەی #${order.orderNumber}',
                              style: AppTextStyles.bodyBold,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'کڕیار: ${order.customerName} • $totalItems دانە • $packedItems/${order.items.length} پاکەتکراو',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: badgeLabel, type: badgeType),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
