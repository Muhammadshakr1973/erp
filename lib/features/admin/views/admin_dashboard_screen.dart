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
import '../../orders/providers/orders_provider.dart';
import '../models/dashboard_model.dart';
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

            // Dashboard Chart
            dashboardAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
              data: (dashboard) => _buildDashboardChart(context, dashboard),
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
                          const Expanded(child: Text('بازاڕ و کۆمپانیا', style: AppTextStyles.bodyBold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      // Navigate to customers tab as quick management
                      ref.read(dashboardProvider); // just dummy touch
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
                          Icon(Icons.group_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(child: Text('کڕیارەکان', style: AppTextStyles.bodyBold)),
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
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ref.watch(ordersListProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا لە هێنانی پسوڵەکان')),
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('هیچ پسوڵەیەک نییە'),
                    ),
                  );
                }
                final recentOrders = orders.take(4).toList();
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentOrders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final order = recentOrders[index];
                    final customerName = order.customer != null ? (order.customer['name'] ?? 'کڕیار') : 'کڕیار';
                    final salesmanName = order.salesman != null ? (order.salesman['name'] ?? 'مەندوب') : 'مەندوب';
                    
                    StatusBadgeType badgeType;
                    String statusText;
                    switch (order.status.toLowerCase()) {
                      case 'delivered':
                        badgeType = StatusBadgeType.success;
                        statusText = 'گەیشتووە';
                        break;
                      case 'in_delivery':
                        badgeType = StatusBadgeType.info;
                        statusText = 'لە ڕێگایە';
                        break;
                      case 'ready':
                      case 'packing':
                        badgeType = StatusBadgeType.warning;
                        statusText = 'ئامادەکردن';
                        break;
                      case 'cancelled':
                        badgeType = StatusBadgeType.danger;
                        statusText = 'گەڕاوە';
                        break;
                      default:
                        badgeType = StatusBadgeType.purple;
                        statusText = order.status;
                    }

                    return InkWell(
                      onTap: () {
                        context.push('/order/${order.id}');
                      },
                      child: AppCard(
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
                                  Text(customerName, style: AppTextStyles.bodyBold),
                                  Text('مەندوب: $salesmanName • ${order.orderNumber}', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${order.totalAmount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع', style: AppTextStyles.price),
                                const SizedBox(height: 4),
                                StatusBadge(
                                  label: statusText,
                                  type: badgeType,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

  Widget _buildDashboardChart(BuildContext context, DashboardModel data) {
    final theme = Theme.of(context);
    final totalActivity = data.monthlySales + data.totalReceivables;
    final salesRatio = totalActivity > 0 ? (data.monthlySales / totalActivity) : 0.0;
    final debtRatio = totalActivity > 0 ? (data.totalReceivables / totalActivity) : 0.0;
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('شیکاری دارایی و ڕێژەی فرۆشتن بەرامبەر قەرز', style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'ئەم چارتە نیشاندەری ڕێژەی فرۆشتنی مانگانەیە لەگەڵ کۆی قەرزە دەرەکییەکان',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Stacked Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    if (salesRatio > 0)
                      Expanded(
                        flex: (salesRatio * 100).toInt(),
                        child: Container(
                          color: AppColors.primary,
                        ),
                      ),
                    if (debtRatio > 0)
                      Expanded(
                        flex: (debtRatio * 100).toInt(),
                        child: Container(
                          color: AppColors.danger,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('فرۆشتنی مانگ (${(salesRatio * 100).toStringAsFixed(1)}%)', style: AppTextStyles.caption),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('قەرزی کڕیار (${(debtRatio * 100).toStringAsFixed(1)}%)', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            // Profit Margin Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ڕێژەی قازانجی گشتی فرۆشتن:', style: AppTextStyles.caption),
                Text(
                  '${data.monthlySales > 0 ? ((data.monthlyProfit / data.monthlySales) * 100).toStringAsFixed(1) : "0"}%',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: data.monthlySales > 0 ? (data.monthlyProfit / data.monthlySales) : 0.0,
              backgroundColor: theme.colorScheme.surfaceContainer,
              color: AppColors.success,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
