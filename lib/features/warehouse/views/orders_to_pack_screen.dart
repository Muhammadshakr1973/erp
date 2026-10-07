import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../admin/views/create_delivery_trip_dialog.dart';
import '../../orders/providers/orders_provider.dart';
import '../providers/warehouse_provider.dart';

class OrdersToPackScreen extends ConsumerWidget {
  const OrdersToPackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersToPackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('پسوڵەکانی پاکەتکردن', style: AppTextStyles.h2),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: TextButton.icon(
              onPressed: () {
                ref.invalidate(ordersListProvider);
                ref.invalidate(readyOrdersForDeliveryProvider);
                showDialog(
                  context: context,
                  builder: (_) => const CreateDeliveryTripDialog(),
                );
              },
              icon: const Icon(Icons.local_shipping_outlined, size: 20),
              label: const Text('دروستکردنی گەشت', style: AppTextStyles.bodyBold),
            ),
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
          error: (err, stack) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ErrorState(
                    title: 'کێشەیەک ڕوویدا لە بارکردنی پسوڵەکان',
                    message: Formatters.cleanError(err),
                    retryText: 'دووبارە هەوڵبدەرەوە',
                    onRetry: () => ref.invalidate(ordersToPackProvider),
                  ),
                ),
              ),
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: EmptyState(
                        title: 'هیچ پسوڵەیەک نییە بۆ پاکەتکردن',
                        message: 'هەموو پسوڵە پشتڕاستکراوەکان پاکەتکراون.',
                        icon: AppIcons.orderStatus,
                      ),
                    ),
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
                              'پسوڵەی ${order.customerName}',
                              style: AppTextStyles.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'مەندوب: ${order.salesmanName} • $totalItems دانە • $packedItems/${order.items.length} پاکەتکراو',
                              style: AppTextStyles.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
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
