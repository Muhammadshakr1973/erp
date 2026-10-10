import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/loading_skeleton.dart';
import '../../../core/components/notification_badge_button.dart';
import '../../../core/router/navigation_tabs_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/dashboard_model.dart';
import 'providers/dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('داشبۆردی سەرەکی', style: AppTextStyles.h2),
            Text(
              'بەخێربێیت، ${user?.name ?? 'بەڕێوەبەر'}',
              style: AppTextStyles.caption.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'دەفتەری چاودێری و وردبینی',
            onPressed: () {
              context.push('/admin-audit-logs');
            },
          ),
          const NotificationBadgeButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
        child: dashboardAsync.when(
          loading: () => _buildLoadingState(context),
          error: (err, stack) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ErrorState(
                    title: 'کێشەیەک ڕوویدا لە بارکردنی ئامارەکانی داشبۆرد',
                    message: Formatters.cleanError(err),
                    retryText: 'دووبارە هەوڵبدەرەوە',
                    onRetry: () => ref.invalidate(dashboardProvider),
                  ),
                ),
              ),
            ),
          ),
          data: (dashboard) => _buildDashboardContent(context, ref, dashboard),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingSkeleton(width: 160, height: 24),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth >= 1024) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth >= 650) {
                crossAxisCount = 3;
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.35,
                ),
                itemCount: 6,
                itemBuilder: (context, index) => const AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LoadingSkeleton(width: 40, height: 40),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LoadingSkeleton(width: 80, height: 16),
                          SizedBox(height: 6),
                          LoadingSkeleton(width: 120, height: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const LoadingSkeleton(width: 140, height: 24),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 2.4,
            children: List.generate(
              4,
              (index) => const AppCard(
                child: Row(
                  children: [
                    LoadingSkeleton(width: 36, height: 36),
                    SizedBox(width: AppSpacing.sm),
                    LoadingSkeleton(width: 80, height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    DashboardModel dashboard,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If there is cash remaining with drivers, show an alert banner
          if (dashboard.driversRemainingCash > 0)
            _buildDriverCashAlert(context, dashboard),

          // KPI Section Header
          Text('ئامارە دارایی و گشتییەکان', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.md),

          // Responsive KPI Grid
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              double childAspectRatio = 1.32;
              if (constraints.maxWidth >= 1024) {
                crossAxisCount = 4;
                childAspectRatio = 1.45;
              } else if (constraints.maxWidth >= 650) {
                crossAxisCount = 3;
                childAspectRatio = 1.35;
              }

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: childAspectRatio,
                children: [
                  // 1. فرۆشتنی ئەم مانگە
                  _buildStatCard(
                    context,
                    title: 'فرۆشتنی ئەم مانگە',
                    value: Formatters.currency(dashboard.monthlySales),
                    subtitle:
                        'مانگی پێشوو: ${Formatters.currency(dashboard.lastMonthSales)}',
                    icon: Icons.trending_up,
                    iconColor: AppColors.primary,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 4; // Orders tab
                    },
                  ),

                  // 2. قازانجی ئەم مانگە
                  _buildStatCard(
                    context,
                    title: 'قازانجی ئەم مانگە',
                    value: Formatters.currency(dashboard.monthlyProfit),
                    subtitle:
                        'مانگی پێشوو: ${Formatters.currency(dashboard.lastMonthProfit)}',
                    icon: Icons.monetization_on_outlined,
                    iconColor: AppColors.success,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 3; // Reports tab
                    },
                  ),

                  // 3. قەرزی کڕیارەکان (Receivables)
                  _buildStatCard(
                    context,
                    title: 'قەرزی کڕیارەکان',
                    value: Formatters.currency(dashboard.totalCustomerDebts),
                    subtitle: 'کۆی شایستەکان لەلای کڕیاران',
                    icon: AppIcons.customerDebt,
                    iconColor: AppColors.danger,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 5; // Customers tab
                    },
                  ),

                  // 4. قەرزی کۆمپانیاکان (Payables)
                  _buildStatCard(
                    context,
                    title: 'قەرزی کۆمپانیاکان',
                    value: Formatters.currency(dashboard.totalPayables),
                    subtitle: 'کۆی قەرزی دابینکەران',
                    icon: Icons.business_center_outlined,
                    iconColor: AppColors.warning,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 6; // Purchases / Suppliers
                    },
                  ),

                  // 5. کۆکراوەی ئەم مانگە
                  _buildStatCard(
                    context,
                    title: 'کۆکراوەی ئەم مانگە',
                    value: Formatters.currency(dashboard.monthlyCollected),
                    subtitle: 'کۆی پارەی وەرگیراو لە کڕیاران',
                    icon: Icons.price_check_outlined,
                    iconColor: AppColors.info,
                  ),

                  // 6. ڕادەستکراو بە ئۆفیس
                  _buildStatCard(
                    context,
                    title: 'ڕادەستکراو بە ئۆفیس',
                    value: Formatters.currency(dashboard.deliveredToOffice),
                    subtitle: 'پارەی گەیشتوو بە سندوقی ئۆفیس',
                    icon: Icons.account_balance_outlined,
                    iconColor: AppColors.purple,
                  ),

                  // 7. پارەی ماوە لەلای شۆفێرەکان
                  _buildStatCard(
                    context,
                    title: 'پارەی لای شۆفێرەکان',
                    value: Formatters.currency(dashboard.driversRemainingCash),
                    subtitle: dashboard.lastCollectionAmount > 0
                        ? 'کۆتا وەرگرتن: ${Formatters.currency(dashboard.lastCollectionAmount)}'
                        : 'پارەی کۆکراوەی شۆفێرەکان',
                    icon: Icons.local_shipping_outlined,
                    iconColor: dashboard.driversRemainingCash > 0
                        ? AppColors.warning
                        : AppColors.success,
                    onTap: () {
                      context.push('/admin-driver-collections');
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Quick Actions Section
          Text('کردار و بەشە خێراکان', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.md),

          LayoutBuilder(
            builder: (context, constraints) {
              int actionColumns = 2;
              double actionAspectRatio = 2.4;
              if (constraints.maxWidth >= 1024) {
                actionColumns = 4;
                actionAspectRatio = 2.6;
              } else if (constraints.maxWidth >= 650) {
                actionColumns = 3;
                actionAspectRatio = 2.5;
              }

              return GridView.count(
                crossAxisCount: actionColumns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: actionAspectRatio,
                children: [
                  _buildActionCard(
                    context,
                    title: 'گەشتەکانی گەیاندن',
                    icon: Icons.local_shipping_outlined,
                    iconColor: AppColors.info,
                    onTap: () {
                      context.push('/admin-delivery-trips');
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'حیساباتی شۆفێرەکان',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.warning,
                    onTap: () {
                      context.push('/admin-driver-collections');
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'گەڕانەوەی فرۆشتن',
                    icon: Icons.assignment_return_outlined,
                    iconColor: AppColors.danger,
                    onTap: () {
                      context.push('/sales-returns');
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'دەفتەری چاودێری',
                    icon: Icons.history_edu_outlined,
                    iconColor: AppColors.purple,
                    onTap: () {
                      context.push('/admin-audit-logs');
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'ڕاپۆرتە گشتییەکان',
                    icon: Icons.bar_chart_outlined,
                    iconColor: AppColors.primary,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 3; // Reports
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'بەڕێوەبردنی کڕین',
                    icon: Icons.store_outlined,
                    iconColor: AppColors.info,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 6; // Purchases
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'کڕیارەکان',
                    icon: AppIcons.customers,
                    iconColor: AppColors.success,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 5; // Customers
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'هەموو پسوڵەکان',
                    icon: AppIcons.order,
                    iconColor: AppColors.primary,
                    onTap: () {
                      ref.read(adminTabIndexProvider.notifier).state = 4; // Orders
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildDriverCashAlert(
    BuildContext context,
    DashboardModel dashboard,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'پارەی ماوە لەلای شۆفێرەکان هەیە',
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: 2),
                Text(
                  'کۆی ${Formatters.currency(dashboard.driversRemainingCash)} هێشتا ڕادەستی سندوقی ئۆفیس نەکراوە',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/admin-driver-collections');
            },
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('وەرگرتن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: AppTextStyles.price.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: AppRadius.radiusSm,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.chevron_left,
            size: 20,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
