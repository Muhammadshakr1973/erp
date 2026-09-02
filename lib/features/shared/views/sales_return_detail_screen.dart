import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/providers/orders_provider.dart';

class SalesReturnDetailScreen extends ConsumerWidget {
  final String returnId;

  const SalesReturnDetailScreen({
    super.key,
    required this.returnId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnAsync = ref.watch(singleSalesReturnProvider(returnId));

    return Scaffold(
      appBar: AppBar(
        title: Text('گەڕاندنەوەی #$returnId', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'نوێکردنەوە',
            onPressed: () => ref.invalidate(singleSalesReturnProvider(returnId)),
          ),
        ],
      ),
      body: returnAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: ErrorState(
            title: 'هەڵە لە بارکردنی وردەکاری گەڕاندنەوە',
            message: err.toString().replaceAll('Exception: ', ''),
            retryText: 'دووبارە هەوڵبدەرەوە',
            onRetry: () => ref.invalidate(singleSalesReturnProvider(returnId)),
          ),
        ),
        data: (rawData) {
          if (rawData == null || rawData is! Map) {
            return const Center(
              child: EmptyState(
                title: 'دۆزینەوە سەرکەوتوو نەبوو',
                message: 'هیچ زانیارییەک بۆ ئەم گەڕاندنەوەیە نەدۆزرایەوە',
              ),
            );
          }

          final data = Map<String, dynamic>.from(rawData);
          final returnNumber = data['return_number']?.toString() ?? '#$returnId';
          final orderId = data['sales_order_id'];
          final orderNumber = data['order']?['order_number']?.toString() ??
              (orderId != null ? '#$orderId' : '');
          final customerName = data['customer']?['name']?.toString() ?? 'نەناسراو';
          final customerPhone = data['customer']?['phone']?.toString();
          final generalReason = data['reason']?.toString();
          final status = data['status']?.toString().toUpperCase() ?? 'COMPLETED';
          final totalAmount = data['total_return_amount'] is num
              ? data['total_return_amount'] as num
              : (num.tryParse(data['total_return_amount']?.toString() ?? '0') ?? 0);

          final createdAtStr = data['created_at']?.toString() ?? '';
          final parsedDate = DateTime.tryParse(createdAtStr);
          final formattedDate =
              parsedDate != null ? Formatters.dateTime(parsedDate) : createdAtStr;

          final items = (data['items'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

          StatusBadgeType badgeType = StatusBadgeType.neutral;
          String badgeLabel = status;
          if (status == 'COMPLETED') {
            badgeType = StatusBadgeType.success;
            badgeLabel = 'تەواوکراو';
          } else if (status == 'PENDING') {
            badgeType = StatusBadgeType.warning;
            badgeLabel = 'چاوەڕوانکراو';
          } else if (status == 'CANCELLED') {
            badgeType = StatusBadgeType.danger;
            badgeLabel = 'هەڵوەشاوەتەوە';
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(singleSalesReturnProvider(returnId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overview Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  returnNumber,
                                  style: AppTextStyles.h2,
                                ),
                                if (formattedDate.isNotEmpty)
                                  Text(
                                    formattedDate,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                              ],
                            ),
                            StatusBadge(
                              label: badgeLabel,
                              type: badgeType,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Divider(),
                        const SizedBox(height: AppSpacing.xs),

                        // Customer Info
                        _buildInfoRow(
                          'کڕیار',
                          customerName,
                          icon: Icons.person_outline,
                        ),
                        if (customerPhone != null &&
                            customerPhone.trim().isNotEmpty)
                          _buildInfoRow(
                            'ژمارەی مۆبایل',
                            customerPhone,
                            icon: Icons.phone_outlined,
                          ),

                        // Original Order Info
                        if (orderNumber.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.receipt_outlined,
                                      size: 18,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      'پسوڵەی سەرەکی',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: orderId != null
                                      ? () => context.push('/order/$orderId')
                                      : null,
                                  child: Row(
                                    children: [
                                      Text(
                                        'پسوڵەی #$orderNumber',
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: AppColors.primary,
                                          decoration:
                                              TextDecoration.underline,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.open_in_new,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // General Reason
                        if (generalReason != null &&
                            generalReason.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _buildInfoRow(
                            'هۆکاری گەڕاندنەوە',
                            generalReason,
                            icon: Icons.info_outline,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Items Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'کاڵا گەڕێندراوەکان (${items.length})',
                              style: AppTextStyles.h3,
                            ),
                            const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Divider(),
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text('هیچ کاڵایەک تۆمار نەکراوە'),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final productName =
                                  item['product']?['name']?.toString() ??
                                  item['product_name']?.toString() ??
                                  'کاڵا';
                              final quantity = item['quantity'] ?? 0;
                              final unitPrice = item['unit_price'] is num
                                  ? item['unit_price'] as num
                                  : (num.tryParse(
                                          item['unit_price']?.toString() ??
                                              '0') ??
                                      0);
                              final itemTotal = item['total'] is num
                                  ? item['total'] as num
                                  : (num.tryParse(
                                          item['total']?.toString() ?? '0') ??
                                      0);
                              final itemReason =
                                  item['reason']?.toString();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          productName,
                                          style: AppTextStyles.bodyBold,
                                        ),
                                      ),
                                      Text(
                                        Formatters.currency(itemTotal),
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$quantity دانە × ${Formatters.currency(unitPrice)}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (itemReason != null &&
                                      itemReason.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.textSecondaryLight
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'تێبینی: $itemReason',
                                        style: AppTextStyles.caption,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Financial Summary Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('کورتەی دارایی', style: AppTextStyles.h3),
                        const SizedBox(height: AppSpacing.sm),
                        const Divider(),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'کۆی گشتی بڕی گەڕاوە:',
                              style: AppTextStyles.bodyLarge,
                            ),
                            Text(
                              Formatters.currency(totalAmount),
                              style: AppTextStyles.priceLarge.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyBold,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
