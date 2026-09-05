import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../shared/providers/customer_provider.dart';
import 'admin_order_filter_dialog.dart';
import 'providers/user_provider.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filterState = ref.watch(adminOrderFilterProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('هەموو پسوڵەکان', style: AppTextStyles.h2),
          actions: [
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: 'گەشتەکانی گەیاندن',
              onPressed: () {
                context.push('/admin-delivery-trips');
              },
            ),
            IconButton(
              tooltip: 'فلتەرکردنی پسوڵەکان',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    AppIcons.filter,
                    color: filterState.hasActiveFilters
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  if (filterState.hasActiveFilters)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${filterState.activeFilterCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                AdminOrderFilterDialog.show(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'نوێکردنەوە',
              onPressed: () {
                ref.invalidate(ordersListProvider);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'هەمووی'),
              Tab(text: 'لە گەیاندن'),
              Tab(text: 'گەیشتووە'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: Column(
          children: [
            _buildActiveFiltersBar(context, ref, filterState),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOrdersList(context, ref, 'هەمووی', filterState),
                  _buildOrdersList(context, ref, 'لە گەیاندن', filterState),
                  _buildOrdersList(context, ref, 'گەیشتووە', filterState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBar(
    BuildContext context,
    WidgetRef ref,
    AdminOrderFilterState filterState,
  ) {
    if (!filterState.hasActiveFilters) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final customersAsync = ref.watch(customerListProvider);
    final salesmenAsync = ref.watch(salesmenListProvider);

    String? customerName;
    if (filterState.customerId != null) {
      final matches = customersAsync.valueOrNull
          ?.where((c) => c.id == filterState.customerId)
          .toList();
      customerName = (matches != null && matches.isNotEmpty)
          ? matches.first.name
          : 'کڕیار #${filterState.customerId}';
    }

    String? salesmanName;
    if (filterState.salesmanId != null) {
      final matches = salesmenAsync.valueOrNull
          ?.where((s) => s.id == filterState.salesmanId)
          .toList();
      salesmanName = (matches != null && matches.isNotEmpty)
          ? matches.first.name
          : 'مەندوب #${filterState.salesmanId}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(
              AppIcons.filter,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'فلتەرەکان:',
              style: AppTextStyles.captionBold,
            ),
            const SizedBox(width: AppSpacing.xs),
            if (filterState.searchQuery.trim().isNotEmpty) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  'گەڕان: ${filterState.searchQuery}',
                  style: AppTextStyles.caption,
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(adminOrderFilterProvider.notifier).state =
                      filterState.copyWith(clearSearch: true);
                },
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (salesmanName != null) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  'مەندوب: $salesmanName',
                  style: AppTextStyles.caption,
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(adminOrderFilterProvider.notifier).state =
                      filterState.copyWith(clearSalesman: true);
                },
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (customerName != null) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  'کڕیار: $customerName',
                  style: AppTextStyles.caption,
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(adminOrderFilterProvider.notifier).state =
                      filterState.copyWith(clearCustomer: true);
                },
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (filterState.startDate != null || filterState.endDate != null) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  'بەروار: ${filterState.startDate != null ? Formatters.date(filterState.startDate!) : '...'} تا ${filterState.endDate != null ? Formatters.date(filterState.endDate!) : '...'}',
                  style: AppTextStyles.caption,
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(adminOrderFilterProvider.notifier).state =
                      filterState.copyWith(clearDates: true);
                },
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            TextButton(
              onPressed: () {
                ref.read(adminOrderFilterProvider.notifier).state =
                    const AdminOrderFilterState();
              },
              child: const Text(
                'سڕینەوەی هەمووی',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    WidgetRef ref,
    String tabFilter,
    AdminOrderFilterState filterState,
  ) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersListProvider),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا: $error')),
        data: (orders) {
          final filteredOrders = applyAdminOrderFilters(
            orders: orders,
            tabFilter: tabFilter,
            filterState: filterState,
          );

          if (filteredOrders.isEmpty) {
            final hasFilters = filterState.hasActiveFilters;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasFilters
                        ? Icons.filter_alt_off_outlined
                        : Icons.receipt_long_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    hasFilters
                        ? 'هیچ پسوڵەیەک بەپێی ئەم فلتەرانە نەدۆزرایەوە'
                        : 'هیچ پسوڵەیەک نییە',
                    style: AppTextStyles.h3,
                  ),
                  if (hasFilters) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('سڕینەوەی فلتەرەکان'),
                      onPressed: () {
                        ref.read(adminOrderFilterProvider.notifier).state =
                            const AdminOrderFilterState();
                      },
                    ),
                  ],
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 1;
              if (constraints.maxWidth >= 1024) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth >= 600) {
                crossAxisCount = 2;
              }

              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 90,
                ),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  final customerName = order.customer != null
                      ? order.customer['name']
                      : 'نەناسراو';
                  final salesmanName = order.salesman != null
                      ? order.salesman['name']
                      : 'نەناسراو';

                  String statusLabel = 'ئامادەکردن';
                  StatusBadgeType statusType = StatusBadgeType.warning;

                  if (order.status == 'DELIVERED') {
                    statusLabel = 'گەیشتووە';
                    statusType = StatusBadgeType.success;
                  } else if (order.status == 'IN_DELIVERY') {
                    statusLabel = 'لە ڕێگایە';
                    statusType = StatusBadgeType.info;
                  } else if (order.status == 'CANCELLED' ||
                      order.status == 'RETURNED') {
                    statusLabel = 'گەڕاوە';
                    statusType = StatusBadgeType.danger;
                  }

                  return AppCard(
                    onTap: () {
                      context.push('/order/${order.id}');
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
                              AppIcons.order,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(customerName, style: AppTextStyles.bodyBold),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'پسوڵەی #${order.orderNumber} • مەندوب: $salesmanName',
                                      style: AppTextStyles.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (order.pendingSync) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.sync,
                                      size: 12,
                                      color: Colors.orange,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              Formatters.currency(order.totalAmount),
                              style: AppTextStyles.price,
                            ),
                            const SizedBox(height: 4),
                            StatusBadge(label: statusLabel, type: statusType),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
