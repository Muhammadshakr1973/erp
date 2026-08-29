import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/reports_provider.dart';

class SalesBySalesmanReportScreen extends ConsumerStatefulWidget {
  const SalesBySalesmanReportScreen({super.key});

  @override
  ConsumerState<SalesBySalesmanReportScreen> createState() => _SalesBySalesmanReportScreenState();
}

class _SalesBySalesmanReportScreenState extends ConsumerState<SalesBySalesmanReportScreen> {
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
        if (_startDate != null) 'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
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
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('دیاریکردنی ماوە', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('پاککردنەوە', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _buildStartDatePicker(context)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _buildEndDatePicker(context)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(text: 'جێبەجێکردن', onPressed: _applyFilters),
                      ),
                    ],
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
                  child: Text('هەڵەیەک ڕوویدا: $err', style: const TextStyle(color: AppColors.danger)),
                ),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Summary Cards
                  _buildSummaryCards(data),
                  const SizedBox(height: AppSpacing.md),

                  // Salesmen Performance Table
                  const Text('ئەدای کار و فرۆشتنی مەندوبەکان', style: AppTextStyles.h3),
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

  Widget _buildSummaryCards(data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardWidth = isMobile ? (constraints.maxWidth - AppSpacing.sm) / 2 : (constraints.maxWidth - 3 * AppSpacing.md) / 4;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _buildKpiCard('کۆی فرۆشتن', _formatCurrency(data.totalSalesAmount), AppColors.primary, cardWidth),
            _buildKpiCard('کۆی قازانج', _formatCurrency(data.totalProfitAmount), AppColors.success, cardWidth),
            _buildKpiCard('کۆی کۆمسیۆن', _formatCurrency(data.totalCommission), AppColors.purple, cardWidth),
            _buildKpiCard('کۆی پارەی کۆکراوە', _formatCurrency(data.totalCollectedCash), AppColors.info, cardWidth),
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
            Text(title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(color: color, fontWeight: FontWeight.bold),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesmenTable(List salesmen) {
    if (salesmen.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('هیچ داتایەک نەدۆزرایەوە', style: AppTextStyles.bodyMedium),
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
            return DataRow(cells: [
              DataCell(Text(s.salesmanName, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(s.phone ?? '-')),
              DataCell(Text('${s.commissionRate.toStringAsFixed(1)}%')),
              DataCell(Text('${s.totalOrders}')),
              DataCell(Text('${s.deliveredOrders}')),
              DataCell(Text(_formatCurrency(s.totalSales), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_formatCurrency(s.totalProfit), textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
              DataCell(Text(_formatCurrency(s.estimatedCommission), textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold))),
              DataCell(Text(_formatCurrency(s.paymentsCollected), textDirection: TextDirection.ltr)),
            ]);
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
        child: Text(_startDate != null ? _startDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
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
        child: Text(_endDate != null ? _endDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
      ),
    );
  }
}
