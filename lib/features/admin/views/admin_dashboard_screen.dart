import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../shared/providers/route_provider.dart';
import '../../shared/models/route_model.dart';
import '../../shared/models/report_models.dart';
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
  int? _activeCustomerChartTooltipId;
  final GlobalKey _todayPlanKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardProvider);
    final salesmenReportAsync = ref.watch(salesBySalesmanReportProvider(const {}));
    final routesAsync = ref.watch(routeListProvider);

    // Local function to compute today's assignments
    List<_TodayAssignment> getTodayAssignments(List<RouteModel> routes) {
      final now = DateTime.now();
      final englishDays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final todayDayName = englishDays[now.weekday - 1];
      final todayDateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final englishToKurdishMap = {
        'Saturday': 'شەممە',
        'Sunday': 'یەکشەممە',
        'Monday': 'دووشەممە',
        'Tuesday': 'سێشەممە',
        'Wednesday': 'چوارشەممە',
        'Thursday': 'پێنجشەممە',
        'Friday': 'هەینی',
      };
      final todayKurdishName = englishToKurdishMap[todayDayName] ?? '';

      final list = <_TodayAssignment>[];
      for (final route in routes) {
        for (final salesman in route.salesmen) {
          final isTodayDate = salesman.workDate != null &&
              salesman.workDate!.trim() == todayDateStr;
          final isTodayDay = salesman.dayOfWeek != null &&
              (salesman.dayOfWeek == todayDayName ||
                  salesman.dayOfWeek == todayKurdishName);

          if (isTodayDate || isTodayDay) {
            list.add(_TodayAssignment(
              salesmanName: salesman.name,
              salesmanPhone: salesman.phone,
              routeName: route.name,
              routeColor: route.color,
              customersCount: route.customersCount,
            ));
          }
        }
      }
      return list;
    }

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
          ref.invalidate(routeListProvider);
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
                    if (constraints.maxWidth >= 1200) {
                      crossAxisCount = 4;
                    } else if (constraints.maxWidth >= 900) {
                      crossAxisCount = 4;
                    } else if (constraints.maxWidth >= 600) {
                      crossAxisCount = 2;
                    }

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.1,
                      children: [
                        _buildStatCard(
                          context: context,
                          title: 'فرۆشتنی ئەم مانگە',
                          value: dashboard.monthlySales.toInt().toString(),
                          currency: 'د.ع',
                          icon: AppIcons.order,
                          color: theme.colorScheme.primary,
                          subText: 'مانگی پێشوو: ${Formatters.currency(dashboard.lastMonthSales)}',
                        ),
                        _buildStatCard(
                          context: context,
                          title: 'قازانجی مانگ',
                          value: dashboard.monthlyProfit.toInt().toString(),
                          currency: 'د.ع',
                          icon: Icons.trending_up,
                          color: theme.brightness == Brightness.dark ? AppColors.successDark : AppColors.success,
                          subText: 'مانگی پێشوو: ${Formatters.currency(dashboard.lastMonthProfit)}',
                        ),
                        _buildStatCard(
                          context: context,
                          title: 'کۆی قەرزی بازاڕ',
                          value: dashboard.totalReceivables.toInt().toString(),
                          currency: 'د.ع',
                          icon: AppIcons.customerDebt,
                          color: theme.brightness == Brightness.dark ? AppColors.dangerDark : AppColors.danger,
                          subText: 'کۆی قەرزی کڕیار: ${Formatters.currency(dashboard.totalCustomerDebts)}',
                        ),
                        _buildStatCard(
                          context: context,
                          title: 'پارەی لای شۆفێر',
                          value: dashboard.driversRemainingCash.toInt().toString(),
                          currency: 'د.ع',
                          icon: Icons.monetization_on_outlined,
                          color: theme.brightness == Brightness.dark ? AppColors.infoDark : AppColors.info,
                          subText: dashboard.lastCollectionDriver != null
                              ? 'کۆتا ڕادەستکردن (${dashboard.lastCollectionDriver}): ${Formatters.currency(dashboard.lastCollectionAmount)}'
                              : 'کۆتا ڕادەستکردن: ${Formatters.currency(dashboard.lastCollectionAmount)}',
                          onTap: () {
                            context.push('/admin-driver-collections');
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // Today's Salesmen Plan Section
              routesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Container(
                  key: _todayPlanKey,
                  child: Center(
                    child: Text(
                      'هەڵەیەک لە بارکردنی پلانی مەندوبەکاندا هەیە: ${Formatters.cleanError(error)}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                    ),
                  ),
                ),
                data: (routes) {
                  final assignments = getTodayAssignments(routes);
                  return _buildTodaySalesmenPlanList(context, assignments);
                },
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // Salesmen Profit Bar Chart & New Customers Bar Chart
              salesmenReportAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const SizedBox.shrink(),
                data: (reportData) => Column(
                  children: [
                    _buildSalesmanProfitChart(context, reportData.salesmen),
                    _buildSalesmanNewCustomersChart(context, reportData.salesmen),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
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
    String? subText,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusMd,
      child: AppCard(
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
                  child: Icon(
                    onTap != null ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 16,
                  ),
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
            if (subText != null) ...[
              const SizedBox(height: 6),
              Text(
                subText,
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalesmanProfitChart(BuildContext context, List<SalesmanPerformanceItem> salesmen) {
    final theme = Theme.of(context);
    
    // Filter salesmen with profit > 0 in either this month or last month
    final chartSalesmen = salesmen.where((s) => s.totalProfit > 0 || s.lastMonthProfit > 0).toList();
    
    if (chartSalesmen.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                const Text('قازانجی پسوڵەی مەندوبەکان: زانیاری نییە', style: AppTextStyles.bodyBold),
              ],
            ),
          ),
        ),
      );
    }
    
    // Find maximum profit across both this month and last month
    num maxProfit = 0;
    for (final s in chartSalesmen) {
      if (s.totalProfit > maxProfit) maxProfit = s.totalProfit;
      if (s.lastMonthProfit > maxProfit) maxProfit = s.lastMonthProfit;
    }
    
    final double yMax = maxProfit == 0 
        ? 100000 
        : ((maxProfit / 20000).ceil() * 20000).toDouble();
        
    final yInterval = yMax / 4;
    final yLabels = List.generate(5, (index) => yMax - (index * yInterval));

    final thisMonthColor = theme.brightness == Brightness.dark ? AppColors.successDark : AppColors.success;
    final lastMonthColor = theme.colorScheme.primary;
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'قازانجی پسوڵەی مەندوبەکان',
                      style: AppTextStyles.bodyBold,
                    ),
                  ],
                ),
                Text(
                  'دیناری عێراقی',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
              
              // Legend
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: thisMonthColor, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('ئەم مانگە', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: lastMonthColor, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('مانگی ڕابردوو', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Interactive Tooltip Info Box
              if (_activeSalesmanTooltipId != null) () {
                SalesmanPerformanceItem? activeSalesman;
                for (final s in chartSalesmen) {
                  if (s.salesmanId == _activeSalesmanTooltipId) {
                    activeSalesman = s;
                    break;
                  }
                }
                if (activeSalesman == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
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
                        style: AppTextStyles.bodyBold.copyWith(color: theme.colorScheme.primary),
                      ),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: thisMonthColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'ئەم مانگە: ${Formatters.currency(activeSalesman.totalProfit)}',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: lastMonthColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'مانگی ڕابردوو: ${Formatters.currency(activeSalesman.lastMonthProfit)}',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }(),
            
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
                                  children: chartSalesmen.map((s) {
                                    final double thisMonthPct = (s.totalProfit / yMax).clamp(0.01, 1.0);
                                    final double lastMonthPct = (s.lastMonthProfit / yMax).clamp(0.01, 1.0);
                                    final isSelected = s.salesmanId == _activeSalesmanTooltipId;
                                    
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
                                        margin: const EdgeInsets.symmetric(horizontal: 10.0),
                                        width: 60,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  // This Month Bar
                                                  Expanded(
                                                    child: FractionallySizedBox(
                                                      heightFactor: thisMonthPct,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: thisMonthColor,
                                                          borderRadius: const BorderRadius.only(
                                                            topLeft: Radius.circular(4),
                                                            topRight: Radius.circular(4),
                                                          ),
                                                          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // Last Month Bar
                                                  Expanded(
                                                    child: FractionallySizedBox(
                                                      heightFactor: lastMonthPct,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: lastMonthColor,
                                                          borderRadius: const BorderRadius.only(
                                                            topLeft: Radius.circular(4),
                                                            topRight: Radius.circular(4),
                                                          ),
                                                          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
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

  Widget _buildSalesmanNewCustomersChart(BuildContext context, List<SalesmanPerformanceItem> salesmen) {
    final theme = Theme.of(context);
    
    // Filter salesmen with new customers > 0 in either this month or last month
    final chartSalesmen = salesmen.where((s) => s.newCustomersThisMonth > 0 || s.newCustomersLastMonth > 0).toList();
    
    if (chartSalesmen.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                const Text('کڕیارە نوێیەکانی مەندوبەکان: هیچ کڕیارێکی نوێ ڕانەگەیەندراوە', style: AppTextStyles.bodyBold),
              ],
            ),
          ),
        ),
      );
    }
    
    // Find maximum customers across both this month and last month
    num maxCust = 0;
    for (final s in chartSalesmen) {
      if (s.newCustomersThisMonth > maxCust) maxCust = s.newCustomersThisMonth;
      if (s.newCustomersLastMonth > maxCust) maxCust = s.newCustomersLastMonth;
    }
    
    final double yMax = maxCust == 0 
        ? 10 
        : ((maxCust / 5).ceil() * 5).toDouble();
        
    final yInterval = yMax / 4;
    final yLabels = List.generate(5, (index) => (yMax - (index * yInterval)).round());

    final thisMonthColor = theme.brightness == Brightness.dark ? AppColors.infoDark : AppColors.info;
    final lastMonthColor = theme.brightness == Brightness.dark ? AppColors.purpleDark : AppColors.purple;
    
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'کڕیارە نوێیەکانی مەندوبەکان',
                        style: AppTextStyles.bodyBold,
                      ),
                    ],
                  ),
                  Text(
                    'ژمارەی کڕیار',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Legend
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: thisMonthColor, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('ئەم مانگە', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: lastMonthColor, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('مانگی ڕابردوو', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Interactive Tooltip Info Box
              if (_activeCustomerChartTooltipId != null) () {
                SalesmanPerformanceItem? activeSalesman;
                for (final s in chartSalesmen) {
                  if (s.salesmanId == _activeCustomerChartTooltipId) {
                    activeSalesman = s;
                    break;
                  }
                }
                if (activeSalesman == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
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
                        style: AppTextStyles.bodyBold.copyWith(color: theme.colorScheme.primary),
                      ),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: thisMonthColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'ئەم مانگە: ${activeSalesman.newCustomersThisMonth} کڕیار',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: lastMonthColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'مانگی ڕابردوو: ${activeSalesman.newCustomersLastMonth} کڕیار',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }(),
              
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
                          width: 40,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              val.toString(),
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
                    
                    // Grid and Bars Viewport
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: IntrinsicWidth(
                          child: Stack(
                            children: [
                              // Gridlines
                              Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(5, (index) {
                                  return Expanded(
                                    child: Container(
                                      width: (chartSalesmen.length * 84.0 + 32.0).clamp(200.0, 1000.0),
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
                              
                              // Grouped Bars Row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: chartSalesmen.map((s) {
                                    final double thisMonthPct = (s.newCustomersThisMonth / yMax).clamp(0.01, 1.0);
                                    final double lastMonthPct = (s.newCustomersLastMonth / yMax).clamp(0.01, 1.0);
                                    final isSelected = s.salesmanId == _activeCustomerChartTooltipId;
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (_activeCustomerChartTooltipId == s.salesmanId) {
                                            _activeCustomerChartTooltipId = null;
                                          } else {
                                            _activeCustomerChartTooltipId = s.salesmanId;
                                          }
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 10.0),
                                        width: 60,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  // This Month Bar
                                                  Expanded(
                                                    child: FractionallySizedBox(
                                                      heightFactor: thisMonthPct,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: thisMonthColor,
                                                          borderRadius: const BorderRadius.only(
                                                            topLeft: Radius.circular(4),
                                                            topRight: Radius.circular(4),
                                                          ),
                                                          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // Last Month Bar
                                                  Expanded(
                                                    child: FractionallySizedBox(
                                                      heightFactor: lastMonthPct,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: lastMonthColor,
                                                          borderRadius: const BorderRadius.only(
                                                            topLeft: Radius.circular(4),
                                                            topRight: Radius.circular(4),
                                                          ),
                                                          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
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
      ),
    );
  }

  Widget _buildTodaySalesmenPlanList(BuildContext context, List<_TodayAssignment> assignments) {
    final theme = Theme.of(context);
    return Container(
      key: _todayPlanKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_outlined, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'پلانی ئەمڕۆی مەندوب',
                    style: AppTextStyles.h2,
                  ),
                ],
              ),
              if (assignments.isNotEmpty)
                Text(
                  '${assignments.length} ڕێڕەوی چالاک',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (assignments.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 36,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'هیچ مەندوبێک بۆ ئەمڕۆ ڕانەسپیراوە',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assignments.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                
                Color? routeColor;
                if (assignment.routeColor != null && assignment.routeColor!.isNotEmpty) {
                  try {
                    final hexStr = assignment.routeColor!.replaceAll('#', '');
                    routeColor = Color(int.parse('FF$hexStr', radix: 16));
                  } catch (_) {
                    routeColor = theme.colorScheme.primary;
                  }
                } else {
                  routeColor = theme.colorScheme.primary;
                }

                return AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 36,
                        decoration: BoxDecoration(
                          color: routeColor,
                          borderRadius: AppRadius.radiusSm,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.salesmanName,
                              style: AppTextStyles.bodyBold,
                            ),
                            const SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Text(
                                    'ڕێڕەو: ${assignment.routeName}',
                                    style: AppTextStyles.caption,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '·',
                                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'کڕیاران: ${assignment.customersCount}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontFamily: 'Rudaw',
                                    ),
                                  ),
                                  if (assignment.salesmanPhone != null && assignment.salesmanPhone!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '·',
                                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      assignment.salesmanPhone!,
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (assignment.salesmanPhone != null && assignment.salesmanPhone!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone_outlined, size: 20),
                          color: theme.colorScheme.primary,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: assignment.salesmanPhone!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ژمارەی تەلەفۆن کۆپیکرا: ${assignment.salesmanPhone}'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TodayAssignment {
  final String salesmanName;
  final String? salesmanPhone;
  final String routeName;
  final String? routeColor;
  final int customersCount;

  _TodayAssignment({
    required this.salesmanName,
    this.salesmanPhone,
    required this.routeName,
    this.routeColor,
    required this.customersCount,
  });
}
