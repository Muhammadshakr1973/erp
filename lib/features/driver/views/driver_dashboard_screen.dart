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
        data: (trips) {
          int totalTrips = trips.length;
          int totalOrdersCount = 0;
          int deliveredOrdersCount = 0;
          int totalCollected = 0;

          for (final trip in trips) {
            totalOrdersCount += trip.orders.length;
            for (final order in trip.orders) {
              if (order.status == 'DELIVERED') {
                deliveredOrdersCount++;
                totalCollected += order.receivedAmount;
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
                      int crossAxisCount = 3;
                      double aspectRatio = 0.95;
                      if (constraints.maxWidth >= 1024) {
                        crossAxisCount = 3;
                        aspectRatio = 1.5;
                      } else if (constraints.maxWidth >= 600) {
                        crossAxisCount = 3;
                        aspectRatio = 1.3;
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
                            title: 'گەشتەکانی ئەمڕۆ',
                            value: '$totalTrips',
                            icon: AppIcons.orderStatus,
                            color: AppColors.info,
                          ),
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
                            color: AppColors.primary,
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
                    Text('گەشتەکان', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.md),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: trips.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        final isCompleted = trip.status.toUpperCase() == 'COMPLETED';

                        return Stack(
                          children: [
                            AppCard(
                              onTap: () {
                                context.push('/trip/${trip.id}');
                              },
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: const Icon(AppIcons.orderDelivered,
                                      color: AppColors.primary),
                                ),
                                title: Text(
                                  'گەشتی ژمارە ${trip.tripNumber}',
                                  style: AppTextStyles.bodyBold,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${trip.orders.length} پسوڵە • ${Formatters.kurdishDayAndDate(trip.tripDate)}',
                                  style: AppTextStyles.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (isCompleted)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
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
                  color: AppColors.textSecondaryLight,
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
}
