import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/customer_provider.dart';
import '../providers/user_provider.dart';
import '../providers/reports_provider.dart';

class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  int? _selectedCustomerId;
  int? _selectedSalesmanId;
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic> _filters = {};

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
      _filters = {
        if (_selectedCustomerId != null)
          'customer_id': _selectedCustomerId.toString(),
        if (_selectedSalesmanId != null)
          'salesman_id': _selectedSalesmanId.toString(),
        if (_startDate != null)
          'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null)
          'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCustomerId = null;
      _selectedSalesmanId = null;
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
      _filters = {
        'start_date': _startDate!.toIso8601String().split('T').first,
        'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  String _formatCurrency(num amount) {
    return '${Formatters.currency(amount)}';
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
    final reportAsync = ref.watch(profitReportProvider(_filters));
    final customersAsync = ref.watch(customerListProvider);
    final salesmenAsync = ref.watch(salesmenListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتی قازانج', style: AppTextStyles.h2),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('فلتەرکردنی ڕاپۆرت', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text(
                          'پاککردنەوە',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 700;
                      if (isMobile) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildStartDatePicker(context)),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: _buildEndDatePicker(context)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _buildSalesmanDropdown(salesmenAsync),
                            const SizedBox(height: AppSpacing.sm),
                            _buildCustomerDropdown(customersAsync),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: 'جێبەجێکردنی فلتەر',
                                onPressed: _applyFilters,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: _buildStartDatePicker(context)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: _buildEndDatePicker(context)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _buildSalesmanDropdown(salesmenAsync),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _buildCustomerDropdown(customersAsync),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              text: 'جێبەجێکردن',
                              onPressed: _applyFilters,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'هەڵەیەک ڕوویدا: $err',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Summary Cards
                  _buildSummaryCards(data.summary),
                  const SizedBox(height: AppSpacing.md),

                  // Top Profitable Products
                  const Text('پڕقازانجترین کاڵاکان', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  _buildProductsTable(data.topProducts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(dynamic summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardWidth = isMobile
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : (constraints.maxWidth - 3 * AppSpacing.md) / 4;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _buildKpiCard(
              'کۆی داهاتی فرۆشتن',
              _formatCurrency(summary.totalRevenue),
              AppColors.primary,
              cardWidth,
            ),
            _buildKpiCard(
              'کۆی تێچووی کاڵا',
              _formatCurrency(summary.totalCost),
              AppColors.warning,
              cardWidth,
            ),
            _buildKpiCard(
              'کۆی قازانجی پاکت',
              _formatCurrency(summary.totalProfit),
              AppColors.success,
              cardWidth,
            ),
            _buildKpiCard(
              'ڕێژەی قازانج',
              '${summary.profitMarginPercent.toStringAsFixed(1)}%',
              AppColors.purple,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, double width) {
    return SizedBox(
      width: width,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTable(List<dynamic> products) {
    if (products.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'هیچ کاڵایەک نەدۆزرایەوە بەپێی ئەم فلتەرە',
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
            DataColumn(label: Text('ناوی کاڵا')),
            DataColumn(label: Text('کۆد / SKU')),
            DataColumn(label: Text('پۆل')),
            DataColumn(label: Text('دانەی فرۆشراو')),
            DataColumn(label: Text('کۆی داهات')),
            DataColumn(label: Text('کۆی تێچوو')),
            DataColumn(label: Text('قازانج')),
            DataColumn(label: Text('ڕێژە')),
          ],
          rows: products.map((p) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    p.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(p.sku)),
                DataCell(Text(p.categoryName)),
                DataCell(Text('${p.unitsSold}')),
                DataCell(
                  Text(
                    _formatCurrency(p.totalRevenue),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(p.totalCost),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(p.totalProfit),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${p.marginPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

  Widget _buildSalesmanDropdown(AsyncValue salesmenAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedSalesmanId,
      decoration: const InputDecoration(
        labelText: 'مەندوب',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('گشت مەندوبەکان')),
        ...salesmenAsync.when(
          data: (list) => list
              .map<DropdownMenuItem<int?>>(
                (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
              )
              .toList(),
          loading: () => [],
          error: (_, _) => [],
        ),
      ],
      onChanged: (val) => setState(() => _selectedSalesmanId = val),
    );
  }

  Widget _buildCustomerDropdown(AsyncValue customersAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedCustomerId,
      decoration: const InputDecoration(
        labelText: 'کڕیار',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('گشت کڕیارەکان')),
        ...customersAsync.when(
          data: (list) => list
              .map<DropdownMenuItem<int?>>(
                (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
              )
              .toList(),
          loading: () => [],
          error: (_, _) => [],
        ),
      ],
      onChanged: (val) => setState(() => _selectedCustomerId = val),
    );
  }
}
