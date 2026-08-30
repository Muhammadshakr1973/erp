import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  Future<void> _handleCancelOrder(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هەڵوەشاندنەوەی پسوڵە'),
        content: const Text(
          'ئایا دڵنیایت لە هەڵوەشاندنەوەی ئەم پسوڵەیە؟ بڕە حجزکراوەکانی کۆگا ئازاد دەکرێن.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('نەخێر'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بەڵێ، هەڵیوەشێنەرەوە'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref
            .read(orderActionsProvider)
            .updateOrderStatus(orderId, OrderModel.statusCancelled);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پسوڵەکە بە سەرکەوتوویی هەڵوەشێندرایەوە'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('هەڵە'),
              content: Text(e.toString().replaceAll('Exception: ', '')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('باشە'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(singleOrderProvider(orderId));
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.desktopMin;

    return Scaffold(
      appBar: AppBar(
        title: Text('پسوڵەی #$orderId', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(singleOrderProvider(orderId)),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('هەڵەیەک ڕوویدا لە بارکردنی زانیاری پسوڵە'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.invalidate(singleOrderProvider(orderId)),
                child: const Text('دووبارە هەوڵبدەرەوە'),
              ),
            ],
          ),
        ),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('هیچ پسوڵەیەک نەدۆزرایەوە'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildMainContent(context, order),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 1,
                        child: _buildSidePanel(context, ref, order),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildMainContent(context, order),
                      const SizedBox(height: AppSpacing.md),
                      _buildSidePanel(context, ref, order),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('کاڵاکان', style: AppTextStyles.h3),
                  Text(
                    '${order.items.length} کاڵا',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (order.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('هیچ کاڵایەک لەم پسوڵەیەدا نییە')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.isPacked
                              ? AppColors.success.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            item.isPacked
                                ? Icons.check_circle
                                : Icons.inventory_2_outlined,
                            size: 20,
                            color: item.isPacked
                                ? AppColors.success
                                : Colors.grey,
                          ),
                        ),
                      ),
                      title: Text(
                        item.productName,
                        style: AppTextStyles.bodyBold,
                      ),
                      subtitle: Text(
                        '${item.quantity.toInt()} دانە x ${Formatters.currency(item.unitPrice)}',
                        style: AppTextStyles.caption,
                      ),
                      trailing: Text(
                        Formatters.currency(item.subtotal),
                        style: AppTextStyles.price,
                      ),
                    );
                  },
                ),
              const Divider(thickness: 2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆی بڕ', style: AppTextStyles.bodyMedium),
                    Text(
                      Formatters.currency(order.subtotal),
                      style: AppTextStyles.bodyBold,
                    ),
                  ],
                ),
              ),
              if (order.discountAmount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'داشکاندن (${order.discountPercent}%)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                      Text(
                        '- ${Formatters.currency(order.discountAmount)}',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆی گشتی', style: AppTextStyles.bodyLarge),
                    Text(
                      Formatters.currency(order.totalAmount),
                      style: AppTextStyles.priceLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تێبینی', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.sm),
                Text(order.notes!, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
  ) {
    final customerName =
        order.customer != null ? order.customer['name'] ?? '-' : '-';
    final salesmanName =
        order.salesman != null ? order.salesman['name'] ?? '-' : '-';
    final warehouseName =
        order.warehouse != null ? order.warehouse['name'] ?? '-' : '-';

    StatusBadgeType statusType = StatusBadgeType.warning;
    switch (order.status) {
      case OrderModel.statusDelivered:
        statusType = StatusBadgeType.success;
        break;
      case OrderModel.statusConfirmed:
      case OrderModel.statusPacking:
      case OrderModel.statusReady:
        statusType = StatusBadgeType.info;
        break;
      case OrderModel.statusInDelivery:
        statusType = StatusBadgeType.warning;
        break;
      case OrderModel.statusCancelled:
        statusType = StatusBadgeType.danger;
        break;
      case OrderModel.statusDraft:
      default:
        statusType = StatusBadgeType.warning;
        break;
    }

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('زانیاری پسوڵە', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildInfoRow('کڕیار', customerName),
              _buildInfoRow('مەندوب', salesmanName),
              _buildInfoRow('کۆگا', warehouseName),
              _buildInfoRow(
                'بەروار',
                order.createdAt.split('T').first,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('دۆخی ئێستا', style: AppTextStyles.bodyMedium),
                  StatusBadge(label: order.localizedStatus, type: statusType),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('کورتەی دارایی', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildInfoRow(
                'کۆی گشتی',
                Formatters.currency(order.totalAmount),
              ),
              _buildInfoRow(
                'داشکاندن',
                Formatters.currency(order.discountAmount),
              ),
            ],
          ),
        ),
        if (order.canCancel) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'هەڵوەشاندنەوەی پسوڵە (Cancel)',
            type: AppButtonType.danger,
            onPressed: () => _handleCancelOrder(context, ref),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
          ),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}
