import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/notification_badge_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/delivery_trip_model.dart';
import '../providers/driver_providers.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tripsAsync = ref.watch(driverTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سڵاو، شۆفێر', style: AppTextStyles.h2),
        actions: [
          const NotificationBadgeButton(),
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'کێشەیەک ڕوویدا لە بارکردنی زانیارییەکان',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(err.toString(), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(driverTripsProvider);
                  },
                  child: const Text('دووبارە هەوڵبدەرەوە'),
                ),
              ],
            ),
          ),
        ),
        data: (tripsList) {
          final trips = List<DeliveryTripModel>.from(tripsList)..sort((a, b) {
            final dateA = DateTime.tryParse(a.tripDate);
            final dateB = DateTime.tryParse(b.tripDate);
            if (dateA != null && dateB != null) {
              return dateA.compareTo(dateB);
            }
            return a.tripDate.compareTo(b.tripDate);
          });

          int totalOrdersCount = 0;
          int deliveredOrdersCount = 0;
          int totalCollected = 0;

          final undeliveredOrders = <DeliveryTripOrderModel>[];

          for (final trip in trips) {
            totalOrdersCount += trip.orders.length;
            for (final order in trip.orders) {
              if (order.status == 'DELIVERED') {
                deliveredOrdersCount++;
                totalCollected += order.receivedAmount;
              } else {
                undeliveredOrders.add(order);
              }
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverTripsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 2;
                      double aspectRatio = 1.35;
                      if (constraints.maxWidth >= 1024) {
                        crossAxisCount = 2;
                        aspectRatio = 2.2;
                      } else if (constraints.maxWidth >= 600) {
                        crossAxisCount = 2;
                        aspectRatio = 1.8;
                      }

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        childAspectRatio: aspectRatio,
                        children: [
                          _buildStatCard(
                            context: context,
                            title: 'پسوڵەی گەیەنراو',
                            value: '$deliveredOrdersCount / $totalOrdersCount',
                            icon: AppIcons.orderDelivered,
                            color: AppColors.success,
                          ),
                          _buildStatCard(
                            context: context,
                            title: 'پارەی وەرگیراو',
                            value: Formatters.currency(totalCollected),
                            icon: AppIcons.customerDebt,
                            color: AppColors.primaryAdaptive(context),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (trips.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'هیچ گەشتێک نییە بۆ ئەمڕۆ',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                        ),
                      ),
                    )
                  else ...[
                    Text('پسوڵە نەگەیشتووەکان', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.md),
                    if (undeliveredOrders.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'هیچ پسوڵەیەکی نەگەیشتوو بەردەست نییە',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: undeliveredOrders.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final tripOrder = undeliveredOrders[index];
                          final order = tripOrder.order;
                          final customerName = order?.customerName ?? 'کڕیاری نەناسراو';
                          final routeName = order?.customerRouteName ?? 'بێ ڕاوت';
                          final isFailed = tripOrder.status == 'FAILED';

                          return AppCard(
                            onTap: () {
                              context.push('/trip/${tripOrder.deliveryTripId}');
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isFailed
                                    ? AppColors.danger.withValues(alpha: 0.12)
                                    : theme.colorScheme.primary.withValues(alpha: 0.12),
                                child: Icon(
                                  isFailed ? Icons.error_outline_rounded : Icons.receipt_long_rounded,
                                  color: isFailed ? AppColors.danger : theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                customerName,
                                style: AppTextStyles.bodyBold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    '${order?.orderNumber ?? ''} • $routeName',
                                    style: AppTextStyles.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isFailed && tripOrder.failedReason != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'شکست: ${tripOrder.failedReason}',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${Formatters.currency(order?.totalAmount ?? 0)} د.ع',
                                    style: AppTextStyles.bodyBold,
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isFailed
                                          ? AppColors.danger.withValues(alpha: 0.12)
                                          : AppColors.warning.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isFailed ? 'شکستخواردوو' : 'ماوە',
                                      style: TextStyle(
                                        color: isFailed ? AppColors.danger : AppColors.warning,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Rudaw',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: AppTextStyles.h2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildTripStatusTrailing(BuildContext context, DeliveryTripModel trip) {
    final isCompleted = trip.status.toUpperCase() == 'COMPLETED';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isCompleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'گەیەنراوە',
            style: AppTextStyles.bodyBold.copyWith(
              color: isDark ? AppColors.successDark : AppColors.success,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.check_circle_rounded,
            color: isDark ? AppColors.successDark : AppColors.success,
            size: 16,
          ),
        ],
      );
    }

    final parsed = DateTime.tryParse(trip.tripDate);
    if (parsed == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDate = DateTime(parsed.year, parsed.month, parsed.day);

    final tomorrow = today.add(const Duration(days: 1));
    final dayAfterTomorrow = today.add(const Duration(days: 2));

    String label = '';
    Color color;

    if (tripDate == today) {
      label = 'ئەمڕۆ';
      color = isDark ? AppColors.primaryDark : AppColors.primary;
    } else if (tripDate == tomorrow) {
      label = 'سبەی';
      color = isDark ? AppColors.warningDark : AppColors.warning;
    } else if (tripDate == dayAfterTomorrow) {
      label = 'دووسبەی';
      color = isDark ? AppColors.purpleDark : AppColors.purple;
    } else {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyBold.copyWith(
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }
}
