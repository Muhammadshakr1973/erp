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
import 'providers/dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardProvider);

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
            onPressed: () {
              context.push('/notifications');
            },
          ),
          IconButton(
            icon: const Icon(AppIcons.profile),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Stats Grid
              dashboardAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا: $error')),
                data: (dashboard) => LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 2;
                    if (constraints.maxWidth >= 1024) {
                      crossAxisCount = 4;
                    } else if (constraints.maxWidth >= 600) {
                      crossAxisCount = 3;
                    }

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.2,
                      children: [
                        _buildStatCard(
                          context: context,
                          title: 'فرۆشتنی ئەم مانگە',
                          value: dashboard.monthlySales.toInt().toString(),
                          currency: 'د.ع',
                          icon: AppIcons.order,
                          color: AppColors.primary,
                        ),
                        _buildStatCard(
                          context: context,
                          title: 'قازانجی مانگ',
                          value: dashboard.monthlyProfit.toInt().toString(),
                          currency: 'د.ع',
                          icon: Icons.trending_up,
                          color: AppColors.success,
                        ),
                        _buildStatCard(
                          context: context,
                          title: 'کۆی قەرزی بازاڕ',
                          value: dashboard.totalReceivables.toInt().toString(),
                          currency: 'د.ع',
                          icon: AppIcons.customerDebt,
                          color: AppColors.danger,
                        ),
                        _buildStatCard(
                          context: context,
                          title: 'پارەی وەرگیراو',
                          value: dashboard.monthlyCollected.toInt().toString(),
                          currency: 'د.ع',
                          icon: Icons.monetization_on_outlined,
                          color: AppColors.info,
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.sectionGap),

            Text('کارگێڕی خێرا', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      context.push('/admin-purchases');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(child: Text('بازاڕ و سەپاڵیەر', style: AppTextStyles.bodyBold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.group_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(child: Text('بەکارهێنەران', style: AppTextStyles.bodyBold)),
                        ],
                      ),
                    ),
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
                  color: color.withValues(alpha: 0.1),
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
