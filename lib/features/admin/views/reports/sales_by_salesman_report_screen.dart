import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/error_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/reports_provider.dart';

class SalesBySalesmanReportScreen extends ConsumerStatefulWidget {
  const SalesBySalesmanReportScreen({super.key});

  @override
  ConsumerState<SalesBySalesmanReportScreen> createState() =>
      _SalesBySalesmanReportScreenState();
}

class _SalesBySalesmanReportScreenState
    extends ConsumerState<SalesBySalesmanReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFilterExpanded = false;

  Map<String, dynamic> _filters = {};
  int? _activeSalesmanTooltipId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _activeSalesmanTooltipId = null;
      _filters = {
        if (_startDate != null)
          'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null)
          'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
      _activeSalesmanTooltipId = null;
      _filters = {
        'start_date': _startDate!.toIso8601String().split('T').first,
        'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(salesBySalesmanReportProvider(_filters));

    return Scaffold(
      appBar: AppBar(
        title: const Text('فرۆشتن بەپێی مەندوب', style: AppTextStyles.h2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'فلتەرکردنی ڕاپۆرت',
                              style: AppTextStyles.h3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _clearFilters,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'پاککردنەوە',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _isFilterExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_isFilterExpanded) ...[
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isFilterExpanded = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: AppColors.borderLight.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_startDate?.toIso8601String().split('T').first ?? ''}  بۆ  ${_endDate?.toIso8601String().split('T').first ?? ''}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'دەستکاریکردن',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          return Column(
                            children: [
                              _buildStartDatePicker(context),
                              const SizedBox(height: AppSpacing.sm),
                              _buildEndDatePicker(context),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: _buildStartDatePicker(context)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: _buildEndDatePicker(context)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: 'جێبەجێکردنی فلتەر',
                        icon: Icons.check,
                        onPressed: () {
                          _applyFilters();
                          setState(() {
                            _isFilterExpanded = false;
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Report Results
            reportAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: ErrorState(
                  title: 'هەڵەیەک ڕوویدا',
                  message: Formatters.cleanError(err),
                  retryText: 'دووبارە هەوڵبدەرەوە',
                  onRetry: () => ref.invalidate(salesBySalesmanReportProvider(_filters)),
                ),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Summary Cards
                  _buildSummaryCards(data),
                  const SizedBox(height: AppSpacing.md),

                  // Salesmen Profit Bar Chart
                  _buildSalesmanProfitChart(context, data.salesmen),
                  const SizedBox(height: AppSpacing.md),

                  // Salesmen Performance Table
                  const Text(
                    'ئەدای کار و فرۆشتنی مەندوبەکان',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildSalesmenTable(data.salesmen),
                ],
              ),
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
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.textSecondaryLight, size: 48),
                const SizedBox(height: 8),
                Text(
                  'هیچ مەندوبێک قازانجی لە ٠ زیاتر نییە بۆ ئەم ماوەیە',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ),
      );
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
            
            // Interactive Tooltip Info Box (matches screenshot tooltip look)
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              activeSalesman.salesmanName,
                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _activeSalesmanTooltipId = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                          mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
              );
            }(),
            
            // The Bar Chart Row
            SizedBox(
              height: 240,
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
                                          // Animated height for the bar
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
                                          // Label
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

  Widget _buildSummaryCards(dynamic data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final spacing = isMobile ? AppSpacing.sm : AppSpacing.md;
        final cardWidth = isMobile
            ? (constraints.maxWidth - spacing) / 2
            : (constraints.maxWidth - 3 * spacing) / 4;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _buildKpiCard(
              'کۆی فرۆشتن',
              _formatCurrency(data.totalSalesAmount),
              AppColors.primary,
              cardWidth,
            ),
            _buildKpiCard(
              'کۆی قازانج',
              _formatCurrency(data.totalProfitAmount),
              AppColors.success,
              cardWidth,
            ),
            _buildKpiCard(
              'کۆی کۆمسیۆن',
              _formatCurrency(data.totalCommission),
              AppColors.purple,
              cardWidth,
            ),
            _buildKpiCard(
              'کۆی پارەی کۆکراوە',
              _formatCurrency(data.totalCollectedCash),
              AppColors.info,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, double width) {
    final adaptiveColor = AppColors.getAdaptiveColor(context, color);
    return SizedBox(
      width: width,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: AppTextStyles.h3.copyWith(
                  color: adaptiveColor,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesmenTable(List<dynamic> salesmen) {
    if (salesmen.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'هیچ داتایەک نەدۆزرایەوە',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: AppTextStyles.bodyBold,
          dataTextStyle: AppTextStyles.bodyMedium,
          columns: const [
            DataColumn(label: Text('ناوی مەندوب')),
            DataColumn(label: Text('تەلەفۆن')),
            DataColumn(label: Text('ڕێژەی کۆمسیۆن')),
            DataColumn(label: Text('کۆی پسوڵەکان')),
            DataColumn(label: Text('پسوڵەی گەیەندراو')),
            DataColumn(label: Text('کۆی فرۆشتن')),
            DataColumn(label: Text('کۆی قازانج')),
            DataColumn(label: Text('کۆمسیۆنی خەمڵێنراو')),
            DataColumn(label: Text('پارەی وەرگیراو')),
          ],
          rows: salesmen.map((s) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    s.salesmanName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(s.phone ?? '-')),
                DataCell(Text('${s.commissionRate.toStringAsFixed(1)}%')),
                DataCell(Text('${s.totalOrders}')),
                DataCell(Text('${s.deliveredOrders}')),
                DataCell(
                  Text(
                    _formatCurrency(s.totalSales),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(s.totalProfit),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(s.estimatedCommission),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(s.paymentsCollected),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStartDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, true),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'لە بەرواری',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          _startDate != null
              ? _startDate!.toIso8601String().split('T').first
              : 'دیارینەکراوە',
        ),
      ),
    );
  }

  Widget _buildEndDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, false),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'تا بەرواری',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          _endDate != null
              ? _endDate!.toIso8601String().split('T').first
              : 'دیارینەکراوە',
        ),
      ),
    );
  }
}
