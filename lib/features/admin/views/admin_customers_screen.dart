import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/providers/customer_provider.dart';

class AdminCustomersScreen extends ConsumerWidget {
  const AdminCustomersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لیستی کڕیارەکان', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.add), 
            onPressed: () {
              // TODO: Add customer screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: () {
              ref.invalidate(customerListProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppTextField(
              hintText: 'گەڕان بۆ کڕیار، گەڕەک...',
              prefixIcon: AppIcons.search,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(customerListProvider),
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا: $error')),
                data: (customers) {
                  if (customers.isEmpty) {
                    return const Center(child: Text('هیچ کڕیارێک نییە'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                    itemCount: customers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final bool hasDebt = customer.currentBalance > 0;
                      
                      return AppCard(
                        onTap: () {},
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(
                                AppIcons.customer,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name, style: AppTextStyles.bodyBold),
                                  const SizedBox(height: 4),
                                  Text('${customer.neighborhood} • ${customer.phone}', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (hasDebt) ...[
                                  Text('قەرزدار', style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
                                  Text('${customer.currentBalance.toInt()} د.ع', style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger)),
                                ] else ...[
                                  Text('پاکە', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                                  Text('0 د.ع', style: AppTextStyles.bodyBold.copyWith(color: AppColors.success)),
                                ]
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              ),
            ),
          ),
        ],
      ),
    );
  }
}
