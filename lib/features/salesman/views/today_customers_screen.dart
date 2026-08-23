import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/providers/customer_provider.dart';

class TodayCustomersScreen extends ConsumerWidget {
  const TodayCustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کڕیارەکان', style: AppTextStyles.h2),
        actions: [
          IconButton(icon: const Icon(AppIcons.filter), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppTextField(
              hintText: 'گەڕان بۆ کڕیار...',
              prefixIcon: AppIcons.search,
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('هەڵەیەک ڕوویدا: $error', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger)),
              ),
              data: (customers) {
                if (customers.isEmpty) {
                  return const Center(child: Text('هیچ کڕیارێک نەدۆزرایەوە.'));
                }
                
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                  itemCount: customers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final bool isVisited = false; // Add real logic here later
                    
                    return AppCard(
                      onTap: () {
                        context.push('/customer/${customer.id}');
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isVisited 
                                ? AppColors.success.withOpacity(0.1) 
                                : theme.colorScheme.primaryContainer,
                            child: Icon(
                              AppIcons.customer,
                              color: isVisited ? AppColors.success : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer.name, style: AppTextStyles.bodyBold),
                                const SizedBox(height: 4),
                                Text(customer.phone ?? 'بێ ژمارە', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(
                                label: isVisited ? 'سەردانکراوە' : 'چاوەڕێ',
                                type: isVisited ? StatusBadgeType.success : StatusBadgeType.neutral,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'قەرز: ${customer.balance.toInt()} د.ع', 
                                style: AppTextStyles.caption.copyWith(
                                  color: customer.balance > 0 ? AppColors.danger : AppColors.success,
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
