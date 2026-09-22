import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../shared/views/customer_selection_dialog.dart';
import '../../shared/views/new_order_creation_dialog.dart';

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
                NewOrderCreationDialog.show(context);
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

  Widget _buildOrdersList(
    BuildContext context,
    WidgetRef ref, {
    required bool isToday,
  }) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersListProvider),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ErrorState(
                  title: 'هەڵە لە بارکردنی پسوڵەکان',
                  message: Formatters.cleanError(err),
                  retryText: 'دووبارە هەوڵبدەرەوە',
                  onRetry: () => ref.invalidate(ordersListProvider),
                ),
              ),
            ),
          ),
        ),
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
                  const Text(
                    'هیچ پسوڵەیەک نییە',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: () {
                      NewOrderCreationDialog.show(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('دروستکردنی پسوڵە'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: filtered.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = filtered[index];
              final customerName = order.customer != null
                  ? order.customer['name']
                  : 'نەناسراو';

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
                  if (order.status == 'PACKING' || order.status == 'DRAFT') {
                    context.push('/salesman/create-order', extra: order);
                  } else {
                    context.push('/order/${order.id}');
                  }
                },
                onLongPress: () {
                  _showDeleteConfirmationDialog(context, ref, order, customerName);
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
                        children: [
                          Text(customerName, style: AppTextStyles.bodyBold),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'پسوڵەی #${order.orderNumber}',
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
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
    String customerName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'سڕینەوەی پسوڵە',
            style: AppTextStyles.h2,
            textDirection: TextDirection.rtl,
          ),
          content: Text(
            'ئایا دڵنیایت لە سڕینەوەی پسوڵەی #${order.orderNumber} بۆ کڕیار $customerName؟',
            style: AppTextStyles.bodyMedium,
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'پاشگەزبوونەوە',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref.read(orderActionsProvider).deleteOrder(order.id.toString());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('پسوڵەکە بە سەرکەوتوویی سڕایەوە یان خرایە ڕیزی سڕینەوەوە'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('هەڵە ڕوویدا لە سڕینەوە: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'سڕینەوە',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
