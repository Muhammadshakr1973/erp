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
import '../../../core/components/status_badge.dart';
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
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final trip = undeliveredTrips[index];
                        return AppCard(
                          onTap: () {
                            context.push('/trip/${trip.id}');
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'گەشتی ژمارە ${trip.tripNumber}',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  _buildStatusBadge(trip.status),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    Formatters.kurdishDayAndDate(trip.tripDate),
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.list_alt_rounded,
                                        size: 16,
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        '${trip.orders.length} پسوڵە',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.monetization_on_rounded,
                                        size: 16,
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        Formatters.currency(trip.totalAmountCollected),
                                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildStatusBadge(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'DRAFT':
        return const StatusBadge(label: 'ڕەشنووس', type: StatusBadgeType.neutral);
      case 'PLANNED':
        return const StatusBadge(label: 'ڕێکراو (ئامادە)', type: StatusBadgeType.info);
      case 'IN_PROGRESS':
        return const StatusBadge(label: 'لە ڕێگادایە', type: StatusBadgeType.warning);
      case 'COMPLETED':
        return const StatusBadge(label: 'تەواوبوو', type: StatusBadgeType.success);
      case 'CANCELLED':
        return const StatusBadge(label: 'هەڵوەشایەوە', type: StatusBadgeType.danger);
      default:
        return StatusBadge(label: status, type: StatusBadgeType.neutral);
    }
  }
}
