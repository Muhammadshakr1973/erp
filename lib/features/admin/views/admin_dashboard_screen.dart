import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/notification_badge_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/customer_avatar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/dashboard_model.dart';
import 'providers/dashboard_provider.dart';
import 'providers/reports_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int? _activeSalesmanTooltipId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardProvider);
    final salesmenReportAsync = ref.watch(salesBySalesmanReportProvider(const {}));

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
              style: AppTextStyles.caption.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off),
            tooltip: 'تۆماری کردارەکان (Audit Logs)',
            onPressed: () {
              context.push('/admin-audit-logs');
            },
          ),
          const NotificationBadgeButton(),
          GestureDetector(
            onTap: () {
              context.push('/profile');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: CustomerAvatar(
                imageUrl: user?.imageUrl,
                size: 34,
                borderRadius: 10,
                placeholderIcon: AppIcons.profile,
                backgroundColor: theme.colorScheme.primaryContainer,
                iconColor: theme.colorScheme.primary,
                iconSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(salesBySalesmanReportProvider(const {}));
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
                error: (error, stack) => Center(
                  child: ErrorState(
                    title: 'هەڵەیەک ڕوویدا',
                    message: Formatters.cleanError(error),
                    retryText: 'دووبارە هەوڵبدەرەوە',
                    onRetry: () => ref.invalidate(dashboardProvider),
                  ),
                ),
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

              // Salesmen Profit Bar Chart (real-time data)
              salesmenReportAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const SizedBox.shrink(),
                data: (reportData) => _buildSalesmanProfitChart(context, reportData.salesmen),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // Dashboard Chart
              dashboardAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
                data: (dashboard) => _buildDashboardChart(context, dashboard),
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
              ref
                  .watch(ordersListProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text('هەڵەیەک ڕوویدا لە هێنانی پسوڵەکان'),
                    ),
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
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final order = recentOrders[index];
                          final customerName = order.customer != null
                              ? (order.customer['name'] ?? 'کڕیار')
                              : 'کڕیار';
                          final salesmanName = order.salesman != null
                              ? (order.salesman['name'] ?? 'مەندوب')
                              : 'مەندوب';

                          StatusBadgeType badgeType;
                          String statusText;
                          switch (order.status.toUpperCase()) {
                            case 'DELIVERED':
                              badgeType = StatusBadgeType.success;
                              statusText = 'گەیشتووە';
                              break;
                            case 'IN_DELIVERY':
                              badgeType = StatusBadgeType.info;
                              statusText = 'لە ڕێگایە';
                              break;
                            case 'READY':
                            case 'PACKING':
                              badgeType = StatusBadgeType.warning;
                              statusText = 'ئامادەکردن';
                              break;
                            case 'CANCELLED':
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
                                    child: Icon(
                                      AppIcons.order,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customerName,
                                          style: AppTextStyles.bodyBold,
                                        ),
                                        Text(
                                          'مەندوب: $salesmanName • ${order.orderNumber}',
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${Formatters.currency(order.totalAmount)}',
                                        style: AppTextStyles.price,
                                      ),
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
    final salesRatio = totalActivity > 0
        ? (data.monthlySales / totalActivity)
        : 0.0;
    final debtRatio = totalActivity > 0
        ? (data.totalReceivables / totalActivity)
        : 0.0;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'شیکاری دارایی و ڕێژەی فرۆشتن بەرامبەر قەرز',
              style: AppTextStyles.bodyBold,
            ),
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
                        child: Container(color: AppColors.primary),
                      ),
                    if (debtRatio > 0)
                      Expanded(
                        flex: (debtRatio * 100).toInt(),
                        child: Container(color: AppColors.danger),
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
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'فرۆشتنی مانگ (${(salesRatio * 100).toStringAsFixed(1)}%)',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'قەرزی کڕیار (${(debtRatio * 100).toStringAsFixed(1)}%)',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            // Profit Margin Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ڕێژەی قازانجی گشتی فرۆشتن:',
                  style: AppTextStyles.caption,
                ),
                Text(
                  '${data.monthlySales > 0 ? ((data.monthlyProfit / data.monthlySales) * 100).toStringAsFixed(1) : "0"}%',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: data.monthlySales > 0
                  ? (data.monthlyProfit / data.monthlySales)
                  : 0.0,
              backgroundColor: theme.colorScheme.surfaceContainer,
              color: AppColors.success,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesmanProfitChart(BuildContext context, List<dynamic> salesmen) {
    final theme = Theme.of(context);
    
    // Filter salesmen with profit > 0
    final chartSalesmen = salesmen.where((s) => s.totalProfit > 0).toList();
    
    if (chartSalesmen.isEmpty) {
      return const SizedBox.shrink(); // Hide the chart if no salesman has profit > 0 this month
    }
    
    // Find the maximum profit to scale the chart dynamically
    final maxProfit = chartSalesmen.map((s) => s.totalProfit as num).reduce((a, b) => a > b ? a : b);
    
    // Determine the ceiling for y-axis
    final double yMax = maxProfit == 0 
        ? 100000 
        : ((maxProfit / 20000).ceil() * 20000).toDouble();
        
    final yInterval = yMax / 4;
    final yLabels = List.generate(5, (index) => yMax - (index * yInterval));
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'قازانجی پسوڵەی مەندوبەکان',
                      style: AppTextStyles.bodyBold,
                    ),
                  ],
                ),
                Text(
                  'دیناری عێراقی',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Interactive Tooltip Info Box
            if (_activeSalesmanTooltipId != null) () {
              dynamic activeSalesman = chartSalesmen.first;
              for (final s in chartSalesmen) {
                if (s.salesmanId == _activeSalesmanTooltipId) {
                  activeSalesman = s;
                  break;
                }
              }
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      activeSalesman.salesmanName,
                      style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'قازانج: ${Formatters.currency(activeSalesman.totalProfit)}',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'پسوڵەکان: ${activeSalesman.deliveredOrders}',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }() ?? const SizedBox.shrink(),
            
            // The Bar Chart Row
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Y-Axis Labels Column
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yLabels.map((val) {
                      return SizedBox(
                        width: 70,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            Formatters.number(val),
                            textAlign: TextAlign.end,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Grid and Bars Viewport (wrapped in horizontal scroll in case of many salesmen)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: IntrinsicWidth(
                        child: Stack(
                          children: [
                            // 1. Gridlines
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(5, (index) {
                                return Expanded(
                                  child: Container(
                                    width: (chartSalesmen.length * 72.0 + 32.0).clamp(200.0, 1000.0),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.withValues(alpha: 0.15),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            
                            // 2. Bars Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: chartSalesmen.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final s = entry.value;
                                  
                                  // Height percentage based on profit
                                  final double profitPct = s.totalProfit / yMax;
                                  
                                  // Ensure height is clamped properly
                                  final double heightPctClamped = profitPct.clamp(0.01, 1.0);
                                  
                                  final isSelected = s.salesmanId == _activeSalesmanTooltipId;
                                  final barColor = index % 2 == 0 ? AppColors.primary : AppColors.success;
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_activeSalesmanTooltipId == s.salesmanId) {
                                          _activeSalesmanTooltipId = null;
                                        } else {
                                          _activeSalesmanTooltipId = s.salesmanId;
                                        }
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                                      width: 48,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: FractionallySizedBox(
                                                heightFactor: heightPctClamped,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        barColor,
                                                        barColor.withValues(alpha: 0.8),
                                                      ],
                                                      begin: Alignment.topCenter,
                                                      end: Alignment.bottomCenter,
                                                    ),
                                                    borderRadius: const BorderRadius.only(
                                                      topLeft: Radius.circular(6),
                                                      topRight: Radius.circular(6),
                                                    ),
                                                    border: isSelected
                                                        ? Border.all(color: Colors.white, width: 2)
                                                        : null,
                                                    boxShadow: [
                                                      if (isSelected)
                                                        BoxShadow(
                                                          color: barColor.withValues(alpha: 0.5),
                                                          blurRadius: 8,
                                                          spreadRadius: 2,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            s.salesmanName,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption.copyWith(
                                              fontSize: 10,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? theme.colorScheme.primary : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
