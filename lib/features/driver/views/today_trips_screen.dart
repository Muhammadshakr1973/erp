import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class TodayTripsScreen extends StatelessWidget {
  const TodayTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('گەشتەکانی ئەمڕۆ', style: AppTextStyles.h2)),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        itemCount: 2,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          return AppCard(
            onTap: () {
              context.push('/trip/100${index + 1}');
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
                        'گەشتی ژمارە ${index + 1}',
                        style: AppTextStyles.bodyBold,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '10 پسوڵە • گەڕەکی بەختیاری',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: index == 0 ? 'لە گەیاندن' : 'تەواوبوو',
                  type: index == 0
                      ? StatusBadgeType.warning
                      : StatusBadgeType.success,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
