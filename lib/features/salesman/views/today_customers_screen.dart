import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class TodayCustomersScreen extends StatelessWidget {
  const TodayCustomersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کڕیارەکانی ئەمڕۆ', style: AppTextStyles.h2),
        actions: [
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
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              itemCount: 10,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final bool isVisited = index < 3;
                
                return AppCard(
                  onTap: () {
                    // Navigate to Customer Details
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
                            Text('مارکێتی سەفین ${index + 1}', style: AppTextStyles.bodyBold),
                            const SizedBox(height: 4),
                            Text('0750 123 4567', style: AppTextStyles.caption),
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
                          Text('قەرز: 50,000', style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
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
