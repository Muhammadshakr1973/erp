import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../orders/providers/orders_provider.dart';

class SalesmanOrdersScreen extends ConsumerWidget {
  const SalesmanOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پسوڵەکانی من', style: AppTextStyles.h2),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                context.push('/salesman/create-order');
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(ordersListProvider);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ئەمڕۆ'),
              Tab(text: 'ڕابردوو'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList(context, ref, isToday: true),
            _buildOrdersList(context, ref, isToday: false),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, WidgetRef ref, {required bool isToday}) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersListProvider),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('هەڵە لە بارکردنی پسوڵەکان: $err')),
        data: (orders) {
          final nowString = DateTime.now().toIso8601String().substring(0, 10);
          final filtered = orders.where((o) {
            final isOrderToday = o.createdAt.startsWith(nowString);
            return isToday ? isOrderToday : !isOrderToday;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('هیچ پسوڵەیەک نییە', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/salesman/create-order'),
                    icon: const Icon(Icons.add),
                    label: const Text('دروستکردنی پسوڵە'),
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = filtered[index];
              final customerName = order.customer != null ? order.customer['name'] : 'نەناسراو';

              String statusLabel = 'داڕشتن (Draft)';
              StatusBadgeType statusType = StatusBadgeType.warning;

              final normalizedStatus = order.status.toUpperCase();
              switch (normalizedStatus) {
                case 'DELIVERED':
                  statusLabel = 'گەیشتووە';
                  statusType = StatusBadgeType.success;
                  break;
                case 'CONFIRMED':
                  statusLabel = 'پشتڕاستکراوەتەوە';
                  statusType = StatusBadgeType.info;
                  break;
                case 'PACKING':
                  statusLabel = 'لە پاکەتکردندایە';
                  statusType = StatusBadgeType.info;
                  break;
                case 'READY':
                  statusLabel = 'ئامادەیە بۆ ناردن';
                  statusType = StatusBadgeType.info;
                  break;
                case 'IN_DELIVERY':
                  statusLabel = 'لە ڕێگەی گەیاندندایە';
                  statusType = StatusBadgeType.warning;
                  break;
                case 'CANCELLED':
                  statusLabel = 'هەڵوەشاوەتەوە';
                  statusType = StatusBadgeType.danger;
                  break;
                case 'DRAFT':
                default:
                  statusLabel = 'داڕشتن (Draft)';
                  statusType = StatusBadgeType.warning;
                  break;
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
                            'پسوڵەی #${order.orderNumber}',
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
        },
      ),
    );
  }
}
