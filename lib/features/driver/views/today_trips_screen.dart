import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/delivery_trip_model.dart';
import '../providers/driver_providers.dart';

class _MonthFilterOption {
  final String key;
  final String label;

  const _MonthFilterOption({
    required this.key,
    required this.label,
  });
}

class TodayTripsScreen extends ConsumerStatefulWidget {
  const TodayTripsScreen({super.key});

  @override
  ConsumerState<TodayTripsScreen> createState() => _TodayTripsScreenState();
}

class _TodayTripsScreenState extends ConsumerState<TodayTripsScreen> {
  // 0 = نەگەیشتووەکان (Undelivered / Not completed)
  // 1 = گەیشتووەکان (Delivered / Completed)
  int _selectedSection = 0;

  // فلتەری مانگ بۆ گەشتە تەواوبووەکان (بای دیفاوڵت مانگی ئێستا)
  late String _selectedMonthKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  List<_MonthFilterOption> _buildMonthOptions(List<DeliveryTripModel> completedTrips) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final Set<String> seenKeys = {};
    final List<_MonthFilterOption> options = [];

    // 1. ئەم مانگەی ئێستا
    final currentKey = '$currentYear-${currentMonth.toString().padLeft(2, '0')}';
    options.add(_MonthFilterOption(
      key: currentKey,
      label: 'ئەم مانگە ($currentMonth)',
    ));
    seenKeys.add(currentKey);

    // 2. مانگەکانی پێشووی ئەمساڵ تا مانگی ١
    for (int m = currentMonth - 1; m >= 1; m--) {
      final key = '$currentYear-${m.toString().padLeft(2, '0')}';
      options.add(_MonthFilterOption(
        key: key,
        label: 'مانگی $m',
      ));
      seenKeys.add(key);
    }

    // 3. ئەگەر گەشتی تەواوکراو لە ساڵانی تر یان مانگەکانی تر هەبێت
    final List<DateTime> extraMonths = [];
    for (final trip in completedTrips) {
      final dt = DateTime.tryParse(trip.tripDate);
      if (dt != null) {
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          extraMonths.add(DateTime(dt.year, dt.month));
        }
      }
    }
    extraMonths.sort((a, b) => b.compareTo(a));
    for (final dt in extraMonths) {
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      options.add(_MonthFilterOption(
        key: key,
        label: dt.year == currentYear ? 'مانگی ${dt.month}' : 'مانگی ${dt.month} (${dt.year})',
      ));
    }

    // 4. بژاردەی هەموو مانگەکان
    options.add(const _MonthFilterOption(
      key: 'ALL',
      label: 'هەموو',
    ));

    return options;
  }

  Widget _buildMonthFilterBar(
    BuildContext context,
    ThemeData theme,
    List<DeliveryTripModel> completedTrips,
  ) {
    final options = _buildMonthOptions(completedTrips);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.key == _selectedMonthKey;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedMonthKey = option.key;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  option.label,
                  style: AppTextStyles.caption.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripsAsync = ref.watch(driverTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('گەشتەکان', style: AppTextStyles.h2),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xs,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 0,
                    icon: Icon(Icons.local_shipping_outlined, size: 22),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: Icon(Icons.check_circle_outline_rounded, size: 22),
                  ),
                ],
                selected: <int>{_selectedSection},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _selectedSection = newSelection.first;
                  });
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: theme.colorScheme.primary,
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: tripsAsync.when(
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
              data: (tripsList) {
                final trips = List<DeliveryTripModel>.from(tripsList)..sort((a, b) {
                  final dateA = DateTime.tryParse(a.tripDate);
                  final dateB = DateTime.tryParse(b.tripDate);
                  if (dateA != null && dateB != null) {
                    return dateA.compareTo(dateB);
                  }
                  return a.tripDate.compareTo(b.tripDate);
                });

                final completedTrips = trips.where((t) => t.status.toUpperCase() == 'COMPLETED').toList();

                final filteredTrips = trips.where((trip) {
                  final isCompleted = trip.status.toUpperCase() == 'COMPLETED';
                  if (_selectedSection == 0) {
                    return !isCompleted;
                  }

                  if (!isCompleted) return false;
                  if (_selectedMonthKey == 'ALL') return true;

                  final dt = DateTime.tryParse(trip.tripDate);
                  if (dt == null) return false;
                  final tripKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
                  return tripKey == _selectedMonthKey;
                }).toList();

                return Column(
                  children: [
                    if (_selectedSection == 1) ...[
                      _buildMonthFilterBar(context, theme, completedTrips),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Expanded(
                      child: filteredTrips.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedSection == 1
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.local_shipping_outlined,
                                      size: 56,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      _selectedSection == 1
                                          ? (_selectedMonthKey == 'ALL'
                                              ? 'هیچ گەشتێکی گەیشتوو بۆ تۆ بەردەست نییە.'
                                              : 'هیچ گەشتێکی گەیشتوو لەم مانگەدا نییە.')
                                          : 'هیچ گەشتێکی نەگەیشتوو بۆ تۆ بەردەست نییە.',
                                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => ref.invalidate(driverTripsProvider),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                                itemCount: filteredTrips.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final trip = filteredTrips[index];
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
                                      color: Colors.black.withValues(alpha: 0.1),
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
                ),
              ),
            ],
          );
        },
            ),
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
