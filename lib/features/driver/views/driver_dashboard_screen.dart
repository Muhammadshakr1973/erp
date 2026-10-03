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
import 'trip_route_map_widget.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  int _selectedTripIndex = 0;

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

          if (_selectedTripIndex >= trips.length) {
            _selectedTripIndex = 0;
          }

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
                    // Trip Routing Section Title
                    Text('ڕێڕەوی گەیاندنی گەشتەکان', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.md),

                    // Horizontal Selector if there are multiple trips
                    if (trips.length > 1) ...[
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: trips.length,
                          separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final trip = trips[index];
                            final isSelected = index == _selectedTripIndex;
                            final activeColor = theme.colorScheme.primary;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTripIndex = index;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 160,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? activeColor.withOpacity(0.12)
                                      : (theme.brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? activeColor : theme.colorScheme.outlineVariant,
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'گەشتی ژمارە ${trip.tripNumber}',
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: isSelected ? activeColor : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${trip.orders.length} پسوڵە',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ] else ...[
                      // Quick link card for single trip details
                      InkWell(
                        onTap: () {
                          context.push('/trip/${trips.first.id}');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AppCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.local_shipping_rounded, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'بینینی پسوڵەکانی گەشتی ژمارە ${trips.first.tripNumber}',
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'کلیک بکە بۆ تۆمارکردنی باری پسوڵەکان یان ناردنیان',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // The beautiful map widget showing the delivery route
                    TripRouteMapWidget(trip: trips[_selectedTripIndex]),

                    const SizedBox(height: AppSpacing.md),

                    // Navigation button to show list of all orders/invoices for the selected trip
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          context.push('/trip/${trips[_selectedTripIndex].id}');
                        },
                        icon: const Icon(Icons.list_alt_rounded),
                        label: Text(
                          'بینینی پسوڵەکانی گەشتی ژمارە ${trips[_selectedTripIndex].tripNumber}',
                          style: const TextStyle(
                            fontFamily: 'Rudaw',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
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
}
