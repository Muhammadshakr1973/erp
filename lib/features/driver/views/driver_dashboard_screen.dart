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

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  @override
  Widget build(BuildContext context) {
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

          final undeliveredTrips = trips.where((trip) {
            final s = trip.status.toUpperCase();
            return s != 'COMPLETED' && s != 'CANCELLED';
          }).toList();

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          int totalOrdersCount = 0;
          int deliveredOrdersCount = 0;
          int totalCollected = 0;

          int last7DaysTrips = 0;
          int last7DaysOrders = 0;
          int thisMonthTrips = 0;
          int thisMonthOrders = 0;

          for (final trip in trips) {
            totalOrdersCount += trip.orders.length;
            for (final order in trip.orders) {
              if (order.status == 'DELIVERED') {
                deliveredOrdersCount++;
                totalCollected += order.receivedAmount;
              }
            }

            final tripDateTime = DateTime.tryParse(trip.tripDate);
            if (tripDateTime != null) {
              final tripDateOnly = DateTime(tripDateTime.year, tripDateTime.month, tripDateTime.day);

              // 7 Days Range (today down to 6 days ago)
              final diff = today.difference(tripDateOnly).inDays;
              if (diff >= 0 && diff < 7) {
                if (trip.status == 'COMPLETED') {
                  last7DaysTrips++;
                }
                for (final order in trip.orders) {
                  if (order.status == 'DELIVERED') {
                    last7DaysOrders++;
                  }
                }
              }

              // This Month Range (from 1st of current month to today)
              if (tripDateOnly.year == now.year &&
                  tripDateOnly.month == now.month &&
                  tripDateOnly.day <= now.day) {
                if (trip.status == 'COMPLETED') {
                  thisMonthTrips++;
                }
                for (final order in trip.orders) {
                  if (order.status == 'DELIVERED') {
                    thisMonthOrders++;
                  }
                }
              }
            }
          }

          final isDark = theme.brightness == Brightness.dark;
          final infoColor = isDark ? AppColors.infoDark : AppColors.info;
          final purpleColor = isDark ? AppColors.purpleDark : AppColors.purple;

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
                      double aspectRatio = 1.25;
                      if (constraints.maxWidth >= 1024) {
                        crossAxisCount = 4;
                        aspectRatio = 1.35;
                      } else if (constraints.maxWidth >= 600) {
                        crossAxisCount = 4;
                        aspectRatio = 1.25;
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
                          _buildStatCard(
                            context: context,
                            title: 'گەیاندنی ٧ ڕۆژی ڕابردوو',
                            value: '$last7DaysTrips گەشت / $last7DaysOrders پسوڵە',
                            icon: Icons.history_rounded,
                            color: infoColor,
                          ),
                          _buildStatCard(
                            context: context,
                            title: 'گەیاندنی ئەم مانگە',
                            value: '$thisMonthTrips گەشت / $thisMonthOrders پسوڵە',
                            icon: Icons.calendar_month_rounded,
                            color: purpleColor,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (undeliveredTrips.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'هیچ گەشتێکی نەگەیشتوو (چالاک) نییە',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                        ),
                      ),
                    )
                  else ...[
                    Text('گەشتە نەگەیشتووەکان', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.md),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: undeliveredTrips.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final trip = undeliveredTrips[index];
                        final isCompleted = trip.status.toUpperCase() == 'COMPLETED';
                        final trailingWidget = _buildTripStatusTrailing(context, trip);

                        return Stack(
                          children: [
                            AppCard(
                              onTap: () {
                                context.push('/trip/${trip.id}');
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
                                        AppIcons.orderDelivered,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'گەشتی ژمارە ${trip.tripNumber}',
                                          style: AppTextStyles.bodyBold,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${trip.orders.length} پسوڵە • ${Formatters.kurdishDayAndDate(trip.tripDate)}',
                                          style: AppTextStyles.caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            trip.notes!,
                                            style: AppTextStyles.caption.copyWith(color: Colors.grey),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (trailingWidget != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    trailingWidget,
                                  ],
                                ],
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
                  color: color.withOpacity(0.12),
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
