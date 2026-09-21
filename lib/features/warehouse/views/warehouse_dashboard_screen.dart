import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/loading_skeleton.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/warehouse_order_model.dart';
import '../models/warehouse_stock_model.dart';
import '../providers/warehouse_provider.dart';
import 'warehouse_main_screen.dart';

class WarehouseDashboardScreen extends ConsumerWidget {
  const WarehouseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(warehouseDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: dashboardAsync.when(
          data: (data) => Text(data.warehouseName, style: AppTextStyles.h2),
          loading: () => const Text('داشبۆردی کۆگا', style: AppTextStyles.h2),
          error: (err, stack) => const Text('کۆگا', style: AppTextStyles.h2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'نوێکردنەوە',
            onPressed: () {
              ref.invalidate(warehouseDashboardProvider);
              ref.invalidate(ordersToPackProvider);
              ref.invalidate(warehouseStocksProvider);
            },
          ),
          IconButton(
            icon: const Icon(AppIcons.notifications),
            tooltip: 'ئاگادارییەکان',
            onPressed: () {
              context.push('/notifications');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(warehouseDashboardProvider);
          ref.invalidate(ordersToPackProvider);
          ref.invalidate(warehouseStocksProvider);
          await ref.read(warehouseDashboardProvider.future);
        },
        child: dashboardAsync.when(
          loading: () => _buildLoadingState(context),
          error: (err, stack) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ErrorState(
                    title: 'کێشەیەک ڕوویدا لە بارکردنی ئامارەکانی کۆگا',
                    message: Formatters.cleanError(err),
                    retryText: 'دووبارە هەوڵبدەرەوە',
                    onRetry: () => ref.invalidate(warehouseDashboardProvider),
                  ),
                ),
              ),
            ),
          ),
          data: (data) => _buildDashboardContent(context, ref, data),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth >= 1024) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth >= 600) {
                crossAxisCount = 3;
              }

              final childAspectRatio = constraints.maxWidth >= 1024
                  ? 1.4
                  : (constraints.maxWidth >= 600 ? 1.25 : 1.08);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: childAspectRatio,
                children: List.generate(
                  3,
                  (index) => const AppCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LoadingSkeleton(width: 32, height: 32),
                        SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingSkeleton(width: 80, height: 14),
                            SizedBox(height: 4),
                            LoadingSkeleton(width: 50, height: 22),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const LoadingSkeleton(width: 160, height: 24),
          const SizedBox(height: AppSpacing.md),
          const LoadingSkeleton(width: double.infinity, height: 100),
          const SizedBox(height: AppSpacing.sm),
          const LoadingSkeleton(width: double.infinity, height: 100),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    WarehouseDashboardData data,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth >= 1024) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth >= 600) {
                crossAxisCount = 3;
              }

              final childAspectRatio = constraints.maxWidth >= 1024
                  ? 1.4
                  : (constraints.maxWidth >= 600 ? 1.25 : 1.08);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildInteractiveStatCard(
                    title: 'چاوەڕوانی پاکەتکردن',
                    value: data.pendingPackingCount.toString(),
                    subtitle: 'داواکاری بۆ ئامادەکردن',
                    icon: AppIcons.orderStatus,
                    color: AppColors.warning,
                    onTap: () {
                      ref.read(warehouseTabIndexProvider.notifier).state = 1;
                    },
                  ),
                  _buildInteractiveStatCard(
                    title: 'ئامادەکراوی ئەمڕۆ',
                    value: data.readyTodayCount.toString(),
                    subtitle: 'پسوڵەی تەواوکراو',
                    icon: AppIcons.orderDelivered,
                    color: AppColors.success,
                    onTap: null,
                  ),
                  _buildInteractiveStatCard(
                    title: 'کاڵای کەمبوو',
                    value: data.lowStockCount.toString(),
                    subtitle: 'لەژێر ئاستی کەمینە',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    onTap: () {
                      ref.read(warehouseLowStockFilterProvider.notifier).state =
                          true;
                      ref.read(warehouseTabIndexProvider.notifier).state = 2;
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildQuickActionsRow(context, ref, data),
          const SizedBox(height: AppSpacing.lg),
          _buildPendingOrdersSection(context, ref, data.recentOrders),
          if (data.lowStockItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildLowStockSection(context, ref, data.lowStockItems),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildInteractiveStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textSecondaryLight,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.h2,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(
    BuildContext context,
    WidgetRef ref,
    WarehouseDashboardData data,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        final packingText = isCompact
            ? 'پاکەتکردن (${data.pendingPackingCount})'
            : 'پاکەتکردنی پسوڵەکان (${data.pendingPackingCount})';

        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: packingText,
                icon: AppIcons.orderStatus,
                onPressed: () {
                  ref.read(warehouseTabIndexProvider.notifier).state = 1;
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                text: 'پشکنینی ستۆک',
                icon: Icons.inventory_2_outlined,
                type: AppButtonType.outline,
                onPressed: () {
                  ref.read(warehouseLowStockFilterProvider.notifier).state = false;
                  ref.read(warehouseTabIndexProvider.notifier).state = 2;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingOrdersSection(
    BuildContext context,
    WidgetRef ref,
    List<WarehouseOrderModel> orders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('پسوڵەکانی چاوەڕوانی پاکەتکردن', style: AppTextStyles.h3),
            if (orders.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  ref.read(warehouseTabIndexProvider.notifier).state = 1;
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('بینینی هەمووی'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (orders.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 40,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'هیچ پسوڵەیەک لە چاوەڕوانیدا نییە',
                      style: AppTextStyles.bodyBold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'هەموو پسوڵەکان پاکەت کراون و ئامادەن.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = orders[index];
              return AppCard(
                onTap: () {
                  context.push('/pack-order/${order.id}');
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'پسوڵەی #${order.orderNumber}',
                                style: AppTextStyles.bodyBold,
                              ),
                              StatusBadge(
                                label: order.status == 'PACKING'
                                    ? 'لە پاکەتکردندایە'
                                    : 'پشتڕاستکراوە',
                                type: order.status == 'PACKING'
                                    ? StatusBadgeType.warning
                                    : StatusBadgeType.info,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.customerName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ژمارەی کاڵا: ${order.items.length} دانە • بەروار: ${order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : order.createdAt}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onPressed: () {
                        context.push('/pack-order/${order.id}');
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLowStockSection(
    BuildContext context,
    WidgetRef ref,
    List<WarehouseStockModel> lowStockItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                SizedBox(width: AppSpacing.xs),
                Text('ئاگاداری کاڵا کەمبووەکان', style: AppTextStyles.h3),
              ],
            ),
            TextButton(
              onPressed: () {
                ref.read(warehouseLowStockFilterProvider.notifier).state = true;
                ref.read(warehouseTabIndexProvider.notifier).state = 2;
              },
              child: const Text('بینینی لە ستۆک'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lowStockItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) {
            final stock = lowStockItems[index];
            return AppCard(
              onTap: () {
                ref.read(warehouseLowStockFilterProvider.notifier).state = true;
                ref.read(warehouseTabIndexProvider.notifier).state = 2;
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.productName,
                          style: AppTextStyles.bodyBold,
                        ),
                        if (stock.barcode.isNotEmpty)
                          Text(
                            'باڕکۆد: ${stock.barcode}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'مەوجوود: ${stock.quantity}',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                      Text(
                        'ئاستی کەمینە: ${stock.minStockLevel}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
