import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/models/order_model.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('هەموو پسوڵەکان', style: AppTextStyles.h2),
          actions: [
            IconButton(icon: const Icon(AppIcons.filter), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.refresh),
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
        body: TabBarView(
          children: [
            _buildOrdersList(context, ref, 'هەمووی'),
            _buildOrdersList(context, ref, 'لە گەیاندن'),
            _buildOrdersList(context, ref, 'گەیشتووە'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, WidgetRef ref, String filter) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersListProvider),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا: $error')),
        data: (orders) {
          // Filter logic
          List<OrderModel> filteredOrders = orders;
          if (filter == 'لە گەیاندن') {
            filteredOrders = orders
                .where(
                  (o) => o.status == 'in_delivery' || o.status == 'confirmed',
                )
                .toList();
          } else if (filter == 'گەیشتووە') {
            filteredOrders = orders
                .where((o) => o.status == 'delivered')
                .toList();
          }

          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('هیچ پسوڵەیەک نییە', style: AppTextStyles.h3),
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

                  if (order.status == 'delivered') {
                    statusLabel = 'گەیشتووە';
                    statusType = StatusBadgeType.success;
                  } else if (order.status == 'in_delivery') {
                    statusLabel = 'لە ڕێگایە';
                    statusType = StatusBadgeType.info;
                  } else if (order.status == 'cancelled' ||
                      order.status == 'returned') {
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
                                  Text(
                                    'پسوڵەی #${order.orderNumber} • مەندوب: $salesmanName',
                                    style: AppTextStyles.caption,
                                  ),
                                  if (order.pendingSync) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.sync, size: 12, color: Colors.orange),
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
                              '${Formatters.currency(order.totalAmount)}',
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
