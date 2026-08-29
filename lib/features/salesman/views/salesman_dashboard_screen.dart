import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_icon_button.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import 'salesman_my_commissions_screen.dart';

class SalesmanDashboardScreen extends ConsumerWidget {
  const SalesmanDashboardScreen({super.key});

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
              'سڵاو، ${user?.name ?? 'مەندوب'}',
              style: AppTextStyles.h2,
            ),
            Text(
              'گەڕەکی ئەمڕۆ: بەختیاری',
              style: AppTextStyles.caption.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.notifications),
            onPressed: () {
              context.push('/notifications');
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync), // Sync icon
            onPressed: () {
              // Trigger Offline Sync
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offline Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'داتاکان بەسەرکەوتوویی سینک کراون (ئۆفلاین ئامادەیە)',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.order, color: AppColors.info),
                        const SizedBox(height: 8),
                        Text('فرۆشتنی ئەمڕۆ', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text('450,000 د.ع', style: AppTextStyles.h2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.customer, color: AppColors.purple),
                        const SizedBox(height: 8),
                        Text('سەردانەکان', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text('12 / 24', style: AppTextStyles.h2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Quick Actions
            Text('کردارە خێراکان', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 2.5,
              children: [
                _buildActionCard(context, 'پسوڵەی نوێ', AppIcons.newOrder, () {
                  context.push('/salesman/create-order');
                }),
                _buildActionCard(context, 'کۆمسیۆنەکانم', Icons.percent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalesmanMyCommissionsScreen()),
                  );
                }),
                _buildActionCard(context, 'وەرگرتنی پارە', AppIcons.customerDebt, () {}),
                _buildActionCard(context, 'داواکاری کاڵا', AppIcons.add, () {}),
                _buildActionCard(context, 'کڕیاری نوێ', AppIcons.customers, () {}),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Recent Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('دوایین پسوڵەکان', style: AppTextStyles.h2),
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
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                return AppCard(
                  onTap: () {
                    context.push('/order/100${index + 1}');
                  },
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: AppIcons.order,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مارکێتی ئەحمەد', style: AppTextStyles.bodyBold),
                            Text('پسوڵەی #100${index + 1}', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('125,000 د.ع', style: AppTextStyles.price),
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: index == 0 ? 'DRAFT' : 'CONFIRMED',
                            type: index == 0 ? StatusBadgeType.warning : StatusBadgeType.success,
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

  Widget _buildActionCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusLg,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: AppRadius.radiusLg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyBold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
