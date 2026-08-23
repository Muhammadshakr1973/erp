import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ئاگادارکردنەوەکان', style: AppTextStyles.h2),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('هەمووی بخوێنەوە'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        itemCount: 10,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final isUnread = index < 3;
          final isWarning = index == 2;

          return AppCard(
            onTap: () {},
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isWarning ? AppColors.warning.withOpacity(0.1) : theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isWarning ? Icons.warning_amber_rounded : AppIcons.notifications,
                    color: isWarning ? AppColors.warning : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isWarning ? 'ستۆکی کاڵا کەم بووە' : 'پسوڵەی نوێ دروست بوو',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isWarning
                            ? 'ستۆکی "شامپۆی سەر" کەم بووە. تەنها 5 دانە ماوە.'
                            : 'پسوڵەی ژمارە #100$index بۆ مارکێتی ئەحمەد ئامادەی گەیاندنە.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(isUnread ? 0.9 : 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'پێش 2 کاتژمێر',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
