import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../driver/models/delivery_trip_model.dart';
import '../../driver/providers/driver_providers.dart';
import 'create_delivery_trip_dialog.dart';

class AdminDeliveryTripsScreen extends ConsumerWidget {
  const AdminDeliveryTripsScreen({super.key});

  void _openCreateTripDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateDeliveryTripDialog(),
    );
  }

  StatusBadgeType _getStatusBadgeType(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'DELIVERED':
        return StatusBadgeType.success;
      case 'IN_PROGRESS':
        return StatusBadgeType.info;
      case 'PLANNED':
        return StatusBadgeType.warning;
      case 'CANCELLED':
      case 'FAILED':
        return StatusBadgeType.danger;
      default:
        return StatusBadgeType.neutral;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PLANNED':
        return 'پلاندانراو';
      case 'IN_PROGRESS':
        return 'لە جێبەجێکردندایە';
      case 'COMPLETED':
        return 'تەواوکراو';
      case 'CANCELLED':
        return 'هەڵوەشاوەتەوە';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tripsAsync = ref.watch(driverTripsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('گەشتەکانی گەیاندن', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'نوێکردنەوە',
            onPressed: () => ref.invalidate(driverTripsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'ناردنی گەشتی نوێ',
            onPressed: () => _openCreateTripDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateTripDialog(context),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('ناردنی گەشتی نوێ'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(driverTripsProvider),
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'کێشەیەک لە بارکردنی لیستی گەشتەکان ڕوویدا',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(err.toString(), style: AppTextStyles.caption, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(driverTripsProvider),
                    child: const Text('دووبارە هەوڵبدەرەوە'),
                  ),
                ],
              ),
            ),
          ),
          data: (trips) {
            if (trips.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 64, color: theme.disabledColor),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'هیچ گەشتێکی گەیاندن نییە',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'دەتوانیت گەشتی نوێ دروستبکەیت بۆ ناردنی پسوڵە ئامادەکراوەکان بۆ شۆفێرەکان.',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        text: 'ناردنی یەکەم گەشت',
                        onPressed: () => _openCreateTripDialog(context),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final trip = trips[index];
                final driverDisplayName = trip.driverName ??
                    trip.driver?.name ??
                    'شۆفێر #${trip.driverId}';

                return InkWell(
                  onTap: () {
                    context.push('/trip/${trip.id}');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Trip number + Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_shipping, size: 20, color: AppColors.primary),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        trip.tripNumber.isNotEmpty ? trip.tripNumber : 'گەشت #${trip.id}',
                                        style: AppTextStyles.bodyBold,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              StatusBadge(
                                label: _getStatusLabel(trip.status),
                                type: _getStatusBadgeType(trip.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Middle row: Driver & Date
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        driverDisplayName, 
                                        style: AppTextStyles.bodyMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (trip.tripDate.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(trip.tripDate, style: AppTextStyles.caption),
                                  ],
                                ),
                            ],
                          ),
                          const Divider(height: AppSpacing.md),

                          // Bottom row: Orders count & Collected amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${trip.totalOrders} پسوڵە',
                                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'کۆکراوە: ${Formatters.currency(trip.totalAmountCollected)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
