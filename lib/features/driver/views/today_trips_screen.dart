import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
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
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'هیچ گەشتێکی چالاک بۆ تۆ بەردەست نییە.',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
                final isCompleted = trip.status.toUpperCase() == 'COMPLETED';

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
          );
        },
      ),
    );
  }
}
