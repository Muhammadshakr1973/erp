import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class AdminCustomersScreen extends StatelessWidget {
  const AdminCustomersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لیستی کڕیارەکان', style: AppTextStyles.h2),
        actions: [
          IconButton(icon: const Icon(AppIcons.add), onPressed: () {}),
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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              itemCount: 15,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final bool hasDebt = index % 3 == 0;
                
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
                            Text('کڕیار ${index + 1}', style: AppTextStyles.bodyBold),
                            const SizedBox(height: 4),
                            Text('گەڕەکی بەختیاری • 0750 111 2233', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (hasDebt) ...[
                            Text('قەرزدار', style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
                            Text('150,000 د.ع', style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger)),
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
            ),
          ),
        ],
      ),
    );
  }
}
