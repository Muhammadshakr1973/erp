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

class SalesReturnsListScreen extends ConsumerStatefulWidget {
  const SalesReturnsListScreen({super.key});

  @override
  ConsumerState<SalesReturnsListScreen> createState() =>
      _SalesReturnsListScreenState();
}

class _SalesReturnsListScreenState
    extends ConsumerState<SalesReturnsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returnsAsync = ref.watch(salesReturnsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کاڵا گەڕێندراوەکان', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'نوێکردنەوە',
            onPressed: () => ref.invalidate(salesReturnsListProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(salesReturnsListProvider),
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'گەڕان بەپێی ژمارەی گەڕاندنەوە، کڕیار، یان پسوڵە...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),

            // Content
            Expanded(
              child: returnsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: ErrorState(
                    title: 'هەڵە لە بارکردنی لیستی گەڕاندنەوەکان',
                    message: err.toString().replaceAll('Exception: ', ''),
                    retryText: 'دووبارە هەوڵبدەرەوە',
                    onRetry: () => ref.invalidate(salesReturnsListProvider),
                  ),
                ),
                data: (rawList) {
                  final list = rawList.cast<Map<String, dynamic>>();

                  // Filter logic
                  final filtered = list.where((item) {
                    if (_searchQuery.isEmpty) return true;
                    final returnNo =
                        item['return_number']?.toString().toLowerCase() ?? '';
                    final customerName =
                        item['customer']?['name']?.toString().toLowerCase() ??
                            '';
                    final orderNo =
                        item['order']?['order_number']
                            ?.toString()
                            .toLowerCase() ??
                        item['sales_order_id']?.toString() ??
                        '';
                    return returnNo.contains(_searchQuery) ||
                        customerName.contains(_searchQuery) ||
                        orderNo.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: EmptyState(
                        title: 'هیچ کاڵایەکی گەڕێندراو نییە',
                        message: _searchQuery.isNotEmpty
                            ? 'هیچ ئەنجامێک بۆ ئەم گەڕانە نەدۆزرایەوە'
                            : 'هیچ تۆمارێکی گەڕاندنەوەی کاڵا بوونی نییە',
                        icon: Icons.assignment_return_outlined,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final returnId = item['id'];
                      final returnNumber =
                          item['return_number']?.toString() ?? '#$returnId';
                      final customerName =
                          item['customer']?['name']?.toString() ?? 'نەناسراو';
                      final orderNumber =
                          item['order']?['order_number']?.toString() ??
                          item['sales_order_id']?.toString() ??
                          '';
                      final status =
                          item['status']?.toString().toUpperCase() ??
                          'COMPLETED';
                      final totalAmount = item['total_return_amount'] is num
                          ? item['total_return_amount'] as num
                          : (num.tryParse(
                                  item['total_return_amount']?.toString() ??
                                      '0') ??
                              0);

                      final createdAtStr =
                          item['created_at']?.toString() ?? '';
                      final parsedDate = DateTime.tryParse(createdAtStr);
                      final formattedDate = parsedDate != null
                          ? Formatters.date(parsedDate)
                          : createdAtStr;

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

                      return AppCard(
                        onTap: () {
                          context.push('/sales-return/$returnId');
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row: Return Number + Status
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.assignment_return_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      returnNumber,
                                      style: AppTextStyles.bodyBold,
                                    ),
                                  ],
                                ),
                                StatusBadge(
                                  label: badgeLabel,
                                  type: badgeType,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Divider(height: 12),

                            // Customer & Order
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          customerName,
                                          style: AppTextStyles.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (orderNumber.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.receipt_outlined,
                                        size: 16,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'پسوڵەی #$orderNumber',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),

                            // Date & Amount
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                if (formattedDate.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 14,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedDate,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                Text(
                                  Formatters.currency(totalAmount),
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: AppColors.primary,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}
