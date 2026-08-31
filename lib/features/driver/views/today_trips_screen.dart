import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/driver_providers.dart';

class TodayTripsScreen extends ConsumerWidget {
  const TodayTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tripsAsync = ref.watch(driverTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('گەشتەکانی ئەمڕۆ', style: AppTextStyles.h2),
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'هەڵەیەک ڕوویدا لە بارکردنی گەشتەکان',
                style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: () => ref.invalidate(driverTripsProvider),
                child: const Text('دووبارە هەوڵبدەرەوە'),
              ),
            ],
          ),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Text(
                'هیچ گەشتێکی چالاک بۆ تۆ بەردەست نییە.',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(driverTripsProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: trips.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final trip = trips[index];
                return AppCard(
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
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${trip.orders.length} پسوڵە • ${trip.tripDate}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: _getStatusLabel(trip.status),
                        type: _getStatusBadgeType(trip.status),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'تەواوبوو';
      case 'in_progress':
        return 'لە گەیاندن';
      default:
        return 'پلان بۆ داڕێژراو';
    }
  }

  StatusBadgeType _getStatusBadgeType(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return StatusBadgeType.success;
      case 'in_progress':
        return StatusBadgeType.warning;
      default:
        return StatusBadgeType.info;
    }
  }
}
