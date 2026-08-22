import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سڵاو، ${user?.name ?? 'خاوەندارێت'}',
              style: AppTextStyles.h2,
            ),
            Text(
              'داشبۆردی سەرەکی',
              style: AppTextStyles.caption.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Stats row 1
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    title: 'فرۆشتنی ئەمڕۆ',
                    value: '1,250,000',
                    currency: 'د.ع',
                    icon: AppIcons.order,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    title: 'قەرزی بازاڕ',
                    value: '4,500,000',
                    currency: 'د.ع',
                    icon: AppIcons.customerDebt,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Top Stats row 2
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    title: 'گەشتەکانی ئەمڕۆ',
                    value: '4',
                    icon: AppIcons.orderStatus,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    title: 'کاڵای کەمبوو',
                    value: '12',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Recent Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('دوایین پسوڵەکانی فرۆشتن', style: AppTextStyles.h2),
                TextButton(
                  onPressed: () {},
                  child: const Text('هەمووی'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final statuses = [StatusBadgeType.success, StatusBadgeType.info, StatusBadgeType.warning, StatusBadgeType.danger];
                final labels = ['گەیشتووە', 'لە ڕێگایە', 'ئامادەکردن', 'گەڕاوە'];
                
                return AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: AppRadius.radiusMd,
                        ),
                        child: Icon(AppIcons.order, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مارکێتی سەفین ${index + 1}', style: AppTextStyles.bodyBold),
                            Text('مەندوب: ئەحمەد • پێش 10 خولەک', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('145,000 د.ع', style: AppTextStyles.price),
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: labels[index % labels.length],
                            type: statuses[index % statuses.length],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    String? currency,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Icon(Icons.arrow_upward, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTextStyles.h2),
              if (currency != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(currency, style: AppTextStyles.caption),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
