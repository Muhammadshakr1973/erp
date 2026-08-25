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
              }
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
            filteredOrders = orders.where((o) => o.status == 'in_delivery' || o.status == 'confirmed').toList();
          } else if (filter == 'گەیشتووە') {
            filteredOrders = orders.where((o) => o.status == 'delivered').toList();
          }

          if (filteredOrders.isEmpty) {
            return const Center(child: Text('هیچ پسوڵەیەک نییە'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: filteredOrders.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final customerName = order.customer != null ? order.customer['name'] : 'نەناسراو';
              final salesmanName = order.salesman != null ? order.salesman['name'] : 'نەناسراو';
              
              String statusLabel = 'ئامادەکردن';
              StatusBadgeType statusType = StatusBadgeType.warning;
              
              if (order.status == 'delivered') {
                statusLabel = 'گەیشتووە';
                statusType = StatusBadgeType.success;
              } else if (order.status == 'in_delivery') {
                statusLabel = 'لە ڕێگایە';
                statusType = StatusBadgeType.info;
              } else if (order.status == 'cancelled' || order.status == 'returned') {
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
                        child: Icon(AppIcons.order, color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customerName, style: AppTextStyles.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                            'پسوڵەی #${order.orderNumber} • مەندوب: $salesmanName', 
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${order.totalAmount.toInt()} د.ع', style: AppTextStyles.price),
                        const SizedBox(height: 4),
                        StatusBadge(
                          label: statusLabel,
                          type: statusType,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }
      ),
    );
  }
}
