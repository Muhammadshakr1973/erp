import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/providers/customer_provider.dart';

class TodayCustomersScreen extends ConsumerStatefulWidget {
  const TodayCustomersScreen({super.key});

  @override
  ConsumerState<TodayCustomersScreen> createState() =>
      _TodayCustomersScreenState();
}

class _TodayCustomersScreenState extends ConsumerState<TodayCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کڕیارەکان', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.scan),
            tooltip: 'سکانی QR',
            onPressed: () {
              CameraBarcodeScanner.show(context, (barcode) {
                // If the barcode is in format CUST-123
                if (barcode.startsWith('CUST-')) {
                  final customerId = barcode.split('-')[1];
                  context.push('/customer/$customerId');
                } else {
                  setState(() {
                    _searchQuery = barcode;
                    _searchController.text = barcode;
                  });
                }
              });
            },
          ),
          IconButton(icon: const Icon(AppIcons.filter), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppTextField(
              hintText: 'گەڕان بۆ کڕیار...',
              prefixIcon: AppIcons.search,
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'هەڵەیەک ڕوویدا: $error',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
              data: (customers) {
                var filtered = customers
                    .where(
                      (c) => c.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('هیچ کڕیارێک نەدۆزرایەوە.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    final bool isVisited = false; // Add real logic here later

                    return AppCard(
                      onTap: () {
                        context.push('/customer/${customer.id}');
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isVisited
                                ? AppColors.success.withValues(alpha: 0.1)
                                : theme.colorScheme.primaryContainer,
                            child: Icon(
                              AppIcons.customer,
                              color: isVisited
                                  ? AppColors.success
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: AppTextStyles.bodyBold,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  customer.phone ?? 'بێ ژمارە',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(
                                label: isVisited ? 'سەردانکراوە' : 'چاوەڕێ',
                                type: isVisited
                                    ? StatusBadgeType.success
                                    : StatusBadgeType.neutral,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'قەرز: ${Formatters.currency(customer.balance)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: customer.balance > 0
                                      ? AppColors.danger
                                      : AppColors.success,
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
    );
  }
}
